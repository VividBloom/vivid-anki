import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 每日统计实体（DailyStats Entity）
 * 对应数据库 daily_stats 表，主键为日期字符串 yyyy-MM-dd。
 */
export interface DailyStatsEntity {
  date: string;
  reviewCount: number;
  newCount: number;
  correctCount: number;
  durationMs: number;
  goalDone: number;
  aiGeneratedCount: number;
  aiKeptCount: number;
  resumedCount: number;
  undoCount: number;
  sessionCount: number;
  importCount: number;
  createdAt: number;
  updatedAt: number;
}

export default class DailyStatsDao {
  private static readonly TAG = 'DailyStatsDao';
  private static readonly TABLE_NAME = 'daily_stats';

  /**
   * 增加统计值（Upsert 逻辑）
   * 连续写入同一天只产生一行，跨零点写入产生新行。
   */
  async increment(store: relationalStore.RdbStore, stats: Partial<DailyStatsEntity>): Promise<Result<void>> {
    try {
      const today = TimeUtil.todayKey();
      const now = TimeUtil.now();

      // 使用 SQL 直接累加，避免「先查后加」的竞态条件与多轮 IO
      const sql = `
        INSERT INTO ${DailyStatsDao.TABLE_NAME} (
          date, review_count, new_count, correct_count, duration_ms, 
          goal_done, ai_generated_count, ai_kept_count, resumed_count, 
          undo_count, session_count, import_count, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(date) DO UPDATE SET
          review_count = review_count + excluded.review_count,
          new_count = new_count + excluded.new_count,
          correct_count = correct_count + excluded.correct_count,
          duration_ms = duration_ms + excluded.duration_ms,
          goal_done = MAX(goal_done, excluded.goal_done),
          ai_generated_count = ai_generated_count + excluded.ai_generated_count,
          ai_kept_count = ai_kept_count + excluded.ai_kept_count,
          resumed_count = resumed_count + excluded.resumed_count,
          undo_count = undo_count + excluded.undo_count,
          session_count = session_count + excluded.session_count,
          import_count = import_count + excluded.import_count,
          updated_at = excluded.updated_at
      `;

      const args = [
        today,
        stats.reviewCount || 0,
        stats.newCount || 0,
        stats.correctCount || 0,
        stats.durationMs || 0,
        stats.goalDone || 0,
        stats.aiGeneratedCount || 0,
        stats.aiKeptCount || 0,
        stats.resumedCount || 0,
        stats.undoCount || 0,
        stats.sessionCount || 0,
        stats.importCount || 0,
        now, // created_at (仅 insert 时有效)
        now  // updated_at
      ];

      await store.executeSql(sql, args);
      return Result.success(undefined);
    } catch (e) {
      LogUtil.e(DailyStatsDao.TAG, '更新统计失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '统计保存失败');
    }
  }

  /**
   * 查询指定日期的统计
   */
  async queryByDate(store: relationalStore.RdbStore, date: string): Promise<Result<DailyStatsEntity | null>> {
    try {
      const predicates = new relationalStore.RdbPredicates(DailyStatsDao.TABLE_NAME);
      predicates.equalTo('date', date);
      const resultSet = await store.query(predicates);
      const list = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(list.length > 0 ? list[0] : null);
    } catch (e) {
      LogUtil.e(DailyStatsDao.TAG, '查询日期统计失败: ' + JSON.stringify(e));
      return Result.success(null);
    }
  }

  /**
   * 获取最近 N 天的统计数据（用于绘制热力图或图表）
   */
  async queryRecent(store: relationalStore.RdbStore, limit: number): Promise<Result<DailyStatsEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(DailyStatsDao.TABLE_NAME);
      predicates.orderByDesc('date').limitAs(limit);
      const resultSet = await store.query(predicates);
      const list = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(list);
    } catch (e) {
      LogUtil.e(DailyStatsDao.TAG, '查询近期统计失败: ' + JSON.stringify(e));
      return Result.success([]);
    }
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): DailyStatsEntity[] {
    const list: DailyStatsEntity[] = [];
    while (resultSet.goToNextRow()) {
      list.push({
        date: resultSet.getString(resultSet.getColumnIndex('date')),
        reviewCount: resultSet.getLong(resultSet.getColumnIndex('review_count')),
        newCount: resultSet.getLong(resultSet.getColumnIndex('new_count')),
        correctCount: resultSet.getLong(resultSet.getColumnIndex('correct_count')),
        durationMs: resultSet.getLong(resultSet.getColumnIndex('duration_ms')),
        goalDone: resultSet.getLong(resultSet.getColumnIndex('goal_done')),
        aiGeneratedCount: resultSet.getLong(resultSet.getColumnIndex('ai_generated_count')),
        aiKeptCount: resultSet.getLong(resultSet.getColumnIndex('ai_kept_count')),
        resumedCount: resultSet.getLong(resultSet.getColumnIndex('resumed_count')),
        undoCount: resultSet.getLong(resultSet.getColumnIndex('undo_count')),
        sessionCount: resultSet.getLong(resultSet.getColumnIndex('session_count')),
        importCount: resultSet.getLong(resultSet.getColumnIndex('import_count')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
        updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
      });
    }
    return list;
  }
}
