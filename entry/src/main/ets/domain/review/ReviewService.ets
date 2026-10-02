import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import CardDao, { CardEntity } from '../../data/dao/CardDao';
import SettingsDao from '../../data/dao/SettingsDao';
import RevlogDao from '../../data/dao/RevlogDao';
import DailyStatsDao from '../../data/dao/DailyStatsDao';
import { ReviewQueue, QueueConfig, QueueResult, QueueCard } from '../scheduler/ReviewQueue';
import { FsrsScheduler, MemoryState, Rating } from '../scheduler/FsrsScheduler';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 复习界面所需的要点详情
 */
export interface ReviewCard {
  id: number;
  front: string;
  back: string;
  extra?: string;
  stability: number;
  difficulty: number;
  state: string;
  lastReview?: number;
  reps: number;
  lapses: number;
}

/**
 * 复习业务服务
 * 
 * 职责：
 *   1. 对接数据层获取复习候选集
 *   2. 调用调度层构建今日队列
 *   3. 为 UI 提供汇总数据
 *   4. 处理评分落盘与统计更新
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

  /**
   * 评分落盘（核心操作原子性）
   */
  async rateCard(ctx: common.UIAbilityContext, cardId: number, rating: Rating, durationMs: number): Promise<boolean> {
    const store = await DbHelper.getInstance(ctx);
    const cardDao = new CardDao();
    const revlogDao = new RevlogDao();
    const statsDao = new DailyStatsDao();
    const settingsDao = new SettingsDao();

    return await DbHelper.inTransaction(store, async () => {
      // 1. 获取卡片当前状态
      const cardResult = await cardDao.queryById(store, cardId);
      if (!cardResult.ok || !cardResult.data) {
        throw new Error('找不到要评分的要点');
      }
      const card = cardResult.data;

      // 2. 获取 FSRS 参数并调度
      const settings = await settingsDao.query(store);
      const params = settings.ok && settings.data.fsrsParams ? JSON.parse(settings.data.fsrsParams) : undefined;
      const scheduler = new FsrsScheduler(params);
      
      const nowTs = TimeUtil.now();
      const elapsedDays = card.lastReview ? TimeUtil.elapsedDays(card.lastReview, nowTs) : 0;
      
      const state = new MemoryState(card.stability, card.difficulty);
      const nextInfo = scheduler.next(state, elapsedDays, rating, settings.ok ? settings.data.desiredRetention : 0.9);

      // 3. 更新卡片表
      const isNew = card.state === 'new';
      const updateData: Partial<CardEntity> = {
        state: rating === Rating.Again ? 'learning' : 'review',
        stability: nextInfo.state.stability,
        difficulty: nextInfo.state.difficulty,
        due: TimeUtil.addDays(nowTs, nextInfo.interval),
        lastReview: nowTs,
        reps: card.reps + 1,
        lapses: rating === Rating.Again ? card.lapses + 1 : card.lapses
      };
      await cardDao.update(store, cardId, updateData);

      // 4. 写入复习日志
      await revlogDao.insert(store, {
        cardId: cardId,
        rating: rating,
        stabilityBefore: card.stability,
        difficultyBefore: card.difficulty,
        intervalBefore: elapsedDays,
        stateBefore: card.state,
        stabilityAfter: nextInfo.state.stability,
        difficultyAfter: nextInfo.state.difficulty,
        intervalAfter: nextInfo.interval,
        stateAfter: updateData.state!,
        durationMs: durationMs,
        reviewedAt: nowTs
      });

      // 5. 更新每日统计
      await statsDao.increment(store, {
        reviewCount: 1,
        newCount: isNew ? 1 : 0,
        correctCount: rating >= Rating.Good ? 1 : 0,
        durationMs: durationMs
      });

      return true;
    });
  }

  /**
   * 获取指定 ID 的要点详情（返回 UI 专用 DTO）
   */
  async getCardDetail(ctx: common.UIAbilityContext, cardId: number): Promise<ReviewCard | null> {
    const store = await DbHelper.getInstance(ctx);
    const cardDao = new CardDao();
    const result = await cardDao.queryById(store, cardId);
    
    if (!result.ok || !result.data) {
      return null;
    }

    const c = result.data;
    return {
      id: c.id!,
      front: c.front,
      back: c.back,
      extra: c.extra,
      stability: c.stability,
      difficulty: c.difficulty,
      state: c.state,
      lastReview: c.lastReview,
      reps: c.reps,
      lapses: c.lapses
    };
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
