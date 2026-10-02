import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import CardDao, { CardEntity } from '../../data/dao/CardDao';
import SettingsDao from '../../data/dao/SettingsDao';
import { ReviewQueue, QueueConfig, QueueResult, QueueCard } from '../scheduler/ReviewQueue';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 复习业务服务
 * 
 * 职责：
 *   1. 对接数据层获取复习候选集
 *   2. 调用调度层构建今日队列
 *   3. 为 UI 提供汇总数据
 */
export class ReviewService {
  private static readonly TAG = 'ReviewService';

  /**
   * 获取今日复习摘要（总数与预计耗时）
   */
  async getTodaySummary(ctx: common.UIAbilityContext): Promise<QueueResult> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const cardDao = new CardDao();
      const settingsDao = new SettingsDao();

      // 1. 获取全局设置
      const settingsResult = await settingsDao.query(store);
      const newLimit = settingsResult.ok ? settingsResult.data.newLimit : 20;

      // 2. 获取复习候选集
      const tomorrowTs = TimeUtil.startOfTomorrow();
      const candidatesResult = await cardDao.queryReviewCandidates(store, tomorrowTs, newLimit);
      
      if (!candidatesResult.ok) {
        return this.emptyResult();
      }

      // 3. 转换为队列格式
      const queueCards: QueueCard[] = candidatesResult.data.map((c: CardEntity): QueueCard => {
        return {
          id: c.id!,
          deckId: c.deckId,
          isNew: c.state === 'new',
          stability: c.stability,
          difficulty: c.difficulty,
          lastReview: c.lastReview || 0,
          due: c.due
        };
      });

      // 4. 构建队列
      const config: QueueConfig = {
        newLimit: newLimit,
        reviewLimit: null, // 全量复习
        inReturnMode: false,
        returnQuota: 0
      };

      return ReviewQueue.build(queueCards, config);
    } catch (e) {
      LogUtil.e(ReviewService.TAG, '获取今日摘要失败: ' + JSON.stringify(e));
      return this.emptyResult();
    }
  }

  private emptyResult(): QueueResult {
    return {
      cards: [],
      newCount: 0,
      reviewCount: 0,
      estimatedMinutes: 0
    };
  }
}
