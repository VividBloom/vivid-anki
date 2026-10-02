import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 学习会话实体（Session Entity）
 * 对应数据库 session 表。
 * 
 * 用于追踪用户的学习过程，支持中断恢复与跨端进度同步。
 */
export interface SessionEntity {
  sessionId: string;
  deckId: number | null;
  state: string; // 'active', 'finished', 'abandoned'
  totalPlanned: number;
  completed: number;
  lastCardId: number | null;
  lastPosition: number;
  deviceId: string;
  startedAt: number;
  endedAt: number | null;
  updatedAt: number;
}

export default class SessionDao {
  private static readonly TAG = 'SessionDao';
  private static readonly TABLE_NAME = 'session';
  private static readonly TIMEOUT_MS = 30 * 60 * 1000; // 30 分钟超时

  /**
   * 创建新会话
   */
  async create(store: relationalStore.RdbStore, session: Partial<SessionEntity>): Promise<Result<string>> {
    try {
      if (!session.sessionId || !session.deviceId) {
        return Result.failure(ErrorCode.DB_WRITE, '会话 ID 或设备 ID 缺失');
      }

      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'session_id': session.sessionId,
        'deck_id': session.deckId ?? null,
        'state': 'active',
        'total_planned': session.totalPlanned || 0,
        'completed': 0,
        'last_card_id': null,
        'last_position': 0,
        'device_id': session.deviceId,
        'started_at': now,
        'ended_at': null,
        'updated_at': now
      };

      await store.insert(SessionDao.TABLE_NAME, valueBucket);
      return Result.success(session.sessionId);
    } catch (e) {
      LogUtil.e(SessionDao.TAG, '创建会话失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法开启新的学习会话');
    }
  }

  /**
   * 更新会话进度
   */
  async updateProgress(store: relationalStore.RdbStore, sessionId: string, progress: {
    completed: number,
    lastCardId: number,
    lastPosition: number
  }): Promise<Result<void>> {
    try {
      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'completed': progress.completed,
        'last_card_id': progress.lastCardId,
        'last_position': progress.lastPosition,
        'updated_at': now
      };

      const predicates = new relationalStore.RdbPredicates(SessionDao.TABLE_NAME);
      predicates.equalTo('session_id', sessionId).equalTo('state', 'active');

      await store.update(valueBucket, predicates);
      return Result.success(undefined);
    } catch (e) {
      LogUtil.e(SessionDao.TAG, '更新会话进度失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '进度保存失败');
    }
  }

  /**
   * 完成会话
   */
  async finish(store: relationalStore.RdbStore, sessionId: string): Promise<Result<void>> {
    try {
      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'state': 'finished',
        'ended_at': now,
        'updated_at': now
      };

      const predicates = new relationalStore.RdbPredicates(SessionDao.TABLE_NAME);
      predicates.equalTo('session_id', sessionId);

      await store.update(valueBucket, predicates);
      return Result.success(undefined);
    } catch (e) {
      LogUtil.e(SessionDao.TAG, '完成会话失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法结束当前会话');
    }
  }

  /**
   * 标记会话为已放弃
   */
  async abandon(store: relationalStore.RdbStore, sessionId: string): Promise<Result<void>> {
    try {
      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'state': 'abandoned',
        'ended_at': now,
        'updated_at': now
      };

      const predicates = new relationalStore.RdbPredicates(SessionDao.TABLE_NAME);
      predicates.equalTo('session_id', sessionId);

      await store.update(valueBucket, predicates);
      return Result.success(undefined);
    } catch (e) {
      LogUtil.e(SessionDao.TAG, '放弃会话失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '会话清理失败');
    }
  }

  /**
   * 查找最新的活跃会话（用于启动时的中断检测）
   * 判定规则：state='active' 且 updatedAt 在 30 分钟内
   */
  async findActive(store: relationalStore.RdbStore): Promise<Result<SessionEntity | null>> {
    try {
      const now = TimeUtil.now();
      const threshold = now - SessionDao.TIMEOUT_MS;

      const predicates = new relationalStore.RdbPredicates(SessionDao.TABLE_NAME);
      predicates
        .equalTo('state', 'active')
        .greaterThanOrEqualTo('updated_at', threshold)
        .orderByDesc('updated_at')
        .limitAs(1);

      const resultSet = await store.query(predicates);
      const sessions = this.parseResultSet(resultSet);
      resultSet.close();

      return Result.success(sessions.length > 0 ? sessions[0] : null);
    } catch (e) {
      LogUtil.e(SessionDao.TAG, '查找活跃会话失败: ' + JSON.stringify(e));
      return Result.success(null);
    }
  }

  /**
   * 清理过期未完成的会话（将 active 且超时的设为 abandoned）
   */
  async cleanExpiredSessions(store: relationalStore.RdbStore): Promise<Result<number>> {
    try {
      const now = TimeUtil.now();
      const threshold = now - SessionDao.TIMEOUT_MS;

      const valueBucket: relationalStore.ValuesBucket = {
        'state': 'abandoned',
        'updated_at': now
      };

      const predicates = new relationalStore.RdbPredicates(SessionDao.TABLE_NAME);
      predicates
        .equalTo('state', 'active')
        .lessThan('updated_at', threshold);

      const rows = await store.update(valueBucket, predicates);
      return Result.success(rows);
    } catch (e) {
      LogUtil.e(SessionDao.TAG, '清理过期会话失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '系统清理失败');
    }
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): SessionEntity[] {
    const sessions: SessionEntity[] = [];
    while (resultSet.goToNextRow()) {
      sessions.push({
        sessionId: resultSet.getString(resultSet.getColumnIndex('session_id')),
        deckId: resultSet.getLong(resultSet.getColumnIndex('deck_id')),
        state: resultSet.getString(resultSet.getColumnIndex('state')),
        totalPlanned: resultSet.getLong(resultSet.getColumnIndex('total_planned')),
        completed: resultSet.getLong(resultSet.getColumnIndex('completed')),
        lastCardId: resultSet.getLong(resultSet.getColumnIndex('last_card_id')),
        lastPosition: resultSet.getLong(resultSet.getColumnIndex('last_position')),
        deviceId: resultSet.getString(resultSet.getColumnIndex('device_id')),
        startedAt: resultSet.getLong(resultSet.getColumnIndex('started_at')),
        endedAt: resultSet.getLong(resultSet.getColumnIndex('ended_at')),
        updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
      });
    }
    return sessions;
  }
}
