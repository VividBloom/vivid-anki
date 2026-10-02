import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 复习日志实体（Revlog Entity）
 * 对应数据库 revlog 表。
 * 
 * 记录每一次评分的快照，用于撤销回滚和 FSRS 参数训练。
 */
export interface RevlogEntity {
  id?: number;
  cardId: number;
  rating: number;
  elapsedDays: number;
  sessionId?: string;
  deviceId?: string;
  stabilityBefore: number;
  difficultyBefore: number;
  intervalBefore?: number;
  repsBefore: number;
  lapsesBefore: number;
  stabilityAfter: number;
  difficultyAfter: number;
  intervalAfter: number;
  durationMs?: number;
  reviewedAt: number;
  isDeleted: number;
  createdAt: number;
}

export default class RevlogDao {
  private static readonly TAG = 'RevlogDao';
  private static readonly TABLE_NAME = 'revlog';

  /**
   * 插入评分记录
   * 要求 *_before 与 *_after 必须成对写入，逻辑在业务层保证，此处做基础校验。
   */
  async insert(store: relationalStore.RdbStore, log: Partial<RevlogEntity>): Promise<Result<number>> {
    try {
      if (log.stabilityBefore === undefined || log.stabilityAfter === undefined ||
          log.difficultyBefore === undefined || log.difficultyAfter === undefined) {
        return Result.failure(ErrorCode.DB_WRITE, '日志快照数据不完整');
      }

      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'card_id': log.cardId,
        'rating': log.rating,
        'elapsed_days': log.elapsedDays,
        'session_id': log.sessionId || null,
        'device_id': log.deviceId || null,
        'stability_before': log.stabilityBefore,
        'difficulty_before': log.difficultyBefore,
        'interval_before': log.intervalBefore ?? null,
        'reps_before': log.repsBefore,
        'lapses_before': log.lapsesBefore,
        'stability_after': log.stabilityAfter,
        'difficulty_after': log.difficultyAfter,
        'interval_after': log.intervalAfter,
        'duration_ms': log.durationMs ?? null,
        'reviewed_at': log.reviewedAt || now,
        'is_deleted': 0,
        'created_at': now
      };
      const rowId = await store.insert(RevlogDao.TABLE_NAME, valueBucket);
      return Result.success(rowId);
    } catch (e) {
      LogUtil.e(RevlogDao.TAG, '插入日志失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '保存评分记录失败');
    }
  }

  /**
   * 撤销走软删除：置 is_deleted=1，绝不物理删除
   */
  async softDelete(store: relationalStore.RdbStore, logId: number): Promise<Result<number>> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'is_deleted': 1
      };
      const predicates = new relationalStore.RdbPredicates(RevlogDao.TABLE_NAME);
      predicates.equalTo('id', logId);
      const rows = await store.update(valueBucket, predicates);
      return Result.success(rows);
    } catch (e) {
      LogUtil.e(RevlogDao.TAG, '软删除日志失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法撤销该评分');
    }
  }

  /**
   * 查找某张卡片最近一条有效日志
   * 按 reviewed_at 倒序查第一条 is_deleted=0 的记录
   * 必须命中 idx_revlog_card (card_id, reviewed_at DESC) WHERE is_deleted = 0
   */
  async findLastValid(store: relationalStore.RdbStore, cardId: number): Promise<Result<RevlogEntity | null>> {
    try {
      const predicates = new relationalStore.RdbPredicates(RevlogDao.TABLE_NAME);
      predicates
        .equalTo('card_id', cardId)
        .equalTo('is_deleted', 0)
        .orderByDesc('reviewed_at')
        .limitAs(1);

      const resultSet = await store.query(predicates);
      const logs = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(logs.length > 0 ? logs[0] : null);
    } catch (e) {
      LogUtil.e(RevlogDao.TAG, '查找最近日志失败: ' + JSON.stringify(e));
      return Result.success(null);
    }
  }

  /**
   * 导出全部有效日志用于参数训练
   */
  async queryForTraining(store: relationalStore.RdbStore): Promise<Result<RevlogEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(RevlogDao.TABLE_NAME);
      predicates.equalTo('is_deleted', 0).orderByAsc('reviewed_at');

      const resultSet = await store.query(predicates);
      const logs = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(logs);
    } catch (e) {
      LogUtil.e(RevlogDao.TAG, '查询训练数据失败: ' + JSON.stringify(e));
      return Result.success([]);
    }
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): RevlogEntity[] {
    const logs: RevlogEntity[] = [];
    while (resultSet.goToNextRow()) {
      logs.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        cardId: resultSet.getLong(resultSet.getColumnIndex('card_id')),
        rating: resultSet.getLong(resultSet.getColumnIndex('rating')),
        elapsedDays: resultSet.getLong(resultSet.getColumnIndex('elapsed_days')),
        sessionId: resultSet.getString(resultSet.getColumnIndex('session_id')),
        deviceId: resultSet.getString(resultSet.getColumnIndex('device_id')),
        stabilityBefore: resultSet.getDouble(resultSet.getColumnIndex('stability_before')),
        difficultyBefore: resultSet.getDouble(resultSet.getColumnIndex('difficulty_before')),
        intervalBefore: resultSet.getDouble(resultSet.getColumnIndex('interval_before')),
        repsBefore: resultSet.getLong(resultSet.getColumnIndex('reps_before')),
        lapsesBefore: resultSet.getLong(resultSet.getColumnIndex('lapses_before')),
        stabilityAfter: resultSet.getDouble(resultSet.getColumnIndex('stability_after')),
        difficultyAfter: resultSet.getDouble(resultSet.getColumnIndex('difficulty_after')),
        intervalAfter: resultSet.getDouble(resultSet.getColumnIndex('interval_after')),
        durationMs: resultSet.getLong(resultSet.getColumnIndex('duration_ms')),
        reviewedAt: resultSet.getLong(resultSet.getColumnIndex('reviewed_at')),
        isDeleted: resultSet.getLong(resultSet.getColumnIndex('is_deleted')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
      });
    }
    return logs;
  }
}
