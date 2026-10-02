import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import RevlogDao from '../../data/dao/RevlogDao';
import CardDao from '../../data/dao/CardDao';
import SettingsDao from '../../data/dao/SettingsDao';
import { ReviewQueue, QueueConfig, QueueResult } from '../scheduler/ReviewQueue';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 回归模式信息
 */
export interface ReturnInfo {
  quota: number;
  days: number;
}

/**
 * 回归模式（断卡回来）业务服务
 */
export class ReturnService {
  private static readonly TAG = 'ReturnService';

  /**
   * 检查是否需要进入回归模式引导
   */
  async checkReturnMode(ctx: common.UIAbilityContext): Promise<{ shouldEnter: boolean, lastStudyTs: number }> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const revlogDao = new RevlogDao();
      
      // 获取最后一次复习记录
      const lastRevlogRes = await revlogDao.findGlobalLastValid(store);
      if (!lastRevlogRes.ok || !lastRevlogRes.data) {
        return { shouldEnter: false, lastStudyTs: 0 };
      }
      
      const lastStudyTs = lastRevlogRes.data.reviewedAt;
      const shouldEnter = ReviewQueue.shouldEnterReturnMode(lastStudyTs);
      
      return { shouldEnter, lastStudyTs };
    } catch (e) {
      LogUtil.e(ReturnService.TAG, '检查回归模式失败: ' + JSON.stringify(e));
      return { shouldEnter: false, lastStudyTs: 0 };
    }
  }

  /**
   * 获取回归计划信息
   */
  async getReturnInfo(ctx: common.UIAbilityContext): Promise<ReturnInfo> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const cardDao = new CardDao();
      const settingsDao = new SettingsDao();

      // 1. 获取全局设置
      const settingsResult = await settingsDao.query(store);
      const newLimit = settingsResult.ok ? settingsResult.data.newLimit : 20;

      // 2. 获取总积压量 (due <= 次日零点)
      const tomorrowTs = TimeUtil.startOfTomorrow();
      const backlogRes = await cardDao.countDueInRange(store, 0, tomorrowTs);
      const backlogCount = backlogRes.ok ? backlogRes.data : 0;

      if (backlogCount <= 0) return { quota: 0, days: 0 };

      // 3. 计算计划
      const plan = ReviewQueue.returnPlan(backlogCount, newLimit);
      return {
        quota: plan.length > 0 ? plan[0] : 0,
        days: plan.length
      };
    } catch (e) {
      LogUtil.e(ReturnService.TAG, '获取回归信息失败: ' + JSON.stringify(e));
      return { quota: 0, days: 0 };
    }
  }

  /**
   * 获取回归模式下的复习队列
   */
  async getReturnQueue(ctx: common.UIAbilityContext, quota: number): Promise<QueueResult> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const cardDao = new CardDao();
      const settingsDao = new SettingsDao();

      const settingsResult = await settingsDao.query(store);
      const newLimit = settingsResult.ok ? settingsResult.data.newLimit : 20;

      // 仅获取积压的卡片
      const tomorrowTs = TimeUtil.startOfTomorrow();
      const candidatesResult = await cardDao.queryReviewQueueCandidates(store, tomorrowTs, newLimit + quota);
      
      if (!candidatesResult.ok) {
        return { cards: [], newCount: 0, reviewCount: 0, estimatedMinutes: 0 };
      }

      const config: QueueConfig = {
        newLimit: 0, // 回归第一步只复习，不学新卡
        reviewLimit: null,
        inReturnMode: true,
        returnQuota: quota
      };

      return ReviewQueue.build(candidatesResult.data, config);
    } catch (e) {
      LogUtil.e(ReturnService.TAG, '获取回归队列失败: ' + JSON.stringify(e));
      return { cards: [], newCount: 0, reviewCount: 0, estimatedMinutes: 0 };
    }
  }
}
