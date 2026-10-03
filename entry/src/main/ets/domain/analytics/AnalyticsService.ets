import { common } from '@kit.AbilityKit';
import { Analytics } from '../../common/utils/Analytics';
import { DbHelper } from '../../data/db/DbHelper';
import AnalyticsDao, { AnalyticsEventEntity } from '../../data/dao/AnalyticsDao';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 埋点业务服务
 * 
 * 职责：
 *   1. 初始化 Analytics delegate，将埋点持久化到数据库
 *   2. 提供全量埋点数据查询接口
 * 
 * 分层约束：
 *   属于 domain 层，可调用 data/db 与 data/dao。
 */
export class AnalyticsService {
  private analyticsDao = new AnalyticsDao();

  /**
   * 初始化埋点系统
   * 注册 delegate，使得所有 Analytics.logEvent 调用都能入库
   */
  async init(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const store = await DbHelper.getInstance(ctx);
      
      Analytics.setDelegate((eventName, params) => {
        // 异步入库，不阻塞业务主逻辑
        this.analyticsDao.insert(store, eventName, params).then(res => {
          if (!res.ok) {
            LogUtil.e('AnalyticsService', `Failed to store event ${eventName}: ${res.error.message}`);
          }
        });
      });
      
      LogUtil.i('AnalyticsService', 'Analytics system initialized');
    } catch (e) {
      LogUtil.e('AnalyticsService', 'Failed to init analytics: ' + JSON.stringify(e));
    }
  }

  /**
   * 获取所有埋点数据，用于调试或离线分析导出
   */
  async getAllEvents(ctx: common.UIAbilityContext): Promise<AnalyticsEventEntity[]> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const res = await this.analyticsDao.queryAll(store);
      return res.ok ? res.data : [];
    } catch (e) {
      LogUtil.e('AnalyticsService', 'Failed to query all events: ' + JSON.stringify(e));
      return [];
    }
  }
}
