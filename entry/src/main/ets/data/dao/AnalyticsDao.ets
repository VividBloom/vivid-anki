import { relationalStore } from '@kit.ArkData';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { Result } from '../../common/utils/Result';

/**
 * 埋点事件实体
 */
export interface AnalyticsEventEntity {
  id?: number;
  eventName: string;
  params?: string;
  createdAt: number;
}

/**
 * 埋点事件 DAO
 * 
 * 职责：负责 analytics_event 表的增删改查。
 */
export default class AnalyticsDao {
  private static readonly TABLE_NAME = 'analytics_event';

  /**
   * 插入一条埋点记录
   */
  async insert(store: relationalStore.RdbStore, eventName: string, params?: Record<string, string | number | boolean>): Promise<Result<number>> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'event_name': eventName,
        'params': params ? JSON.stringify(params) : null,
        'created_at': TimeUtil.now()
      };
      const id = await store.insert(AnalyticsDao.TABLE_NAME, valueBucket);
      return Result.success(id);
    } catch (e) {
      return Result.failure(-1, 'Insert analytics event failed: ' + JSON.stringify(e));
    }
  }

  /**
   * 查询全量埋点数据（按时间倒序）
   */
  async queryAll(store: relationalStore.RdbStore): Promise<Result<AnalyticsEventEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(AnalyticsDao.TABLE_NAME);
      predicates.orderByDesc('created_at');
      const resultSet = await store.query(predicates);
      const list: AnalyticsEventEntity[] = [];
      while (resultSet.goToNextRow()) {
        list.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          eventName: resultSet.getString(resultSet.getColumnIndex('event_name')),
          params: resultSet.getString(resultSet.getColumnIndex('params')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
        });
      }
      resultSet.close();
      return Result.success(list);
    } catch (e) {
      return Result.failure(-1, 'Query analytics events failed: ' + JSON.stringify(e));
    }
  }

  /**
   * 清理过期埋点（保留最近 30 天，可选）
   */
  async purge(store: relationalStore.RdbStore, days: number = 30): Promise<Result<number>> {
    try {
      const expireTs = TimeUtil.now() - days * 24 * 60 * 60 * 1000;
      const predicates = new relationalStore.RdbPredicates(AnalyticsDao.TABLE_NAME);
      predicates.lessThan('created_at', expireTs);
      const count = await store.delete(predicates);
      return Result.success(count);
    } catch (e) {
      return Result.failure(-1, 'Purge analytics events failed');
    }
  }
}
