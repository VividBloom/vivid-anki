import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import CardDao, { CardEntity } from '../../data/dao/CardDao';
import SettingsDao from '../../data/dao/SettingsDao';
import RevlogDao from '../../data/dao/RevlogDao';
import DailyStatsDao from '../../data/dao/DailyStatsDao';
import SessionDao from '../../data/dao/SessionDao';
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
  cardType: string;
  extra?: string;
  stability: number;
  difficulty: number;
  state: string;
  lastReview?: number;
  reps: number;
  lapses: number;
}

/**
 * 复习完成后的收尾数据
 */
export interface CompletionSummary {
  todayCount: number;
  streakDays: number;
  tomorrowCount: number;
}

/**
 * 首页展示所需的数据汇总
 */
export interface HomeData {
  summary: QueueResult;
  streakDays: number;
  forecast: number[]; // 未来 7 天每日预计复习数
  todayDone: number;  // 今日已完成数
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

      // 2. 获取复习候选集（轻量级查询）
      const tomorrowTs = TimeUtil.startOfTomorrow();
      const candidatesResult = await cardDao.queryReviewQueueCandidates(store, tomorrowTs, newLimit);
      
      if (!candidatesResult.ok) {
        return this.emptyResult();
      }

      // 3. 构建队列
      const config: QueueConfig = {
        newLimit: newLimit,
        reviewLimit: null, // 全量复习
        inReturnMode: false,
        returnQuota: 0
      };

      return ReviewQueue.build(candidatesResult.data, config);
    } catch (e) {
      LogUtil.e(ReviewService.TAG, '获取今日摘要失败: ' + JSON.stringify(e));
      return this.emptyResult();
    }
  }

  /**
   * 评分落盘（核心操作原子性）
   */
  async rateCard(ctx: common.UIAbilityContext, cardId: number, rating: Rating, durationMs: number, sessionInfo?: {
    sessionId: string,
    completed: number,
    lastPosition: number
  }): Promise<boolean> {
    const store = await DbHelper.getInstance(ctx);
    const cardDao = new CardDao();
    const revlogDao = new RevlogDao();
    const statsDao = new DailyStatsDao();
    const settingsDao = new SettingsDao();
    const sessionDao = new SessionDao();

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

      // 6. 更新会话进度（如果提供了会话信息）
      if (sessionInfo) {
        await sessionDao.updateProgress(store, sessionInfo.sessionId, {
          completed: sessionInfo.completed,
          lastCardId: cardId,
          lastPosition: sessionInfo.lastPosition
        });
      }

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
      cardType: c.cardType,
      extra: c.extra,
      stability: c.stability,
      difficulty: c.difficulty,
      state: c.state,
      lastReview: c.lastReview,
      reps: c.reps,
      lapses: c.lapses
    };
  }

  /**
   * 获取用户设置
   */
  async getSettings(ctx: common.UIAbilityContext) {
    const store = await DbHelper.getInstance(ctx);
    const settingsDao = new SettingsDao();
    const result = await settingsDao.query(store);
    return result.ok ? result.data : null;
  }

  /**
   * 获取复习完成后的收尾摘要
   */
  async getCompletionSummary(ctx: common.UIAbilityContext): Promise<CompletionSummary> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const statsDao = new DailyStatsDao();
      const cardDao = new CardDao();

      // 1. 获取今日完成量
      const today = TimeUtil.todayKey();
      const todayStats = await statsDao.queryByDate(store, today);
      const todayCount = todayStats.ok && todayStats.data ? todayStats.data.reviewCount : 0;

      // 2. 计算连续天数 (Streak)
      const recentStats = await statsDao.queryRecent(store, 31); // 查一个月
      let streakDays = 0;
      if (recentStats.ok && recentStats.data.length > 0) {
        const stats = recentStats.data;
        // 按日期排序，从新到旧
        let checkDate = new Date();
        const studyDates = new Set(stats.filter(s => s.reviewCount > 0).map(s => s.date));
        
        // 从今天开始往前数
        while (studyDates.has(TimeUtil.todayKey(checkDate.getTime()))) {
          streakDays++;
          checkDate.setDate(checkDate.getDate() - 1);
        }
      }

      // 3. 明日预告 (次日零点到后天零点)
      const tomorrowStart = TimeUtil.startOfTomorrow();
      const tomorrowEnd = tomorrowStart + 24 * 60 * 60 * 1000;
      const tomorrowCountResult = await cardDao.countDueInRange(store, tomorrowStart, tomorrowEnd);
      const tomorrowCount = tomorrowCountResult.ok ? tomorrowCountResult.data : 0;

      return {
        todayCount,
        streakDays,
        tomorrowCount
      };
    } catch (e) {
      LogUtil.e(ReviewService.TAG, '获取收尾摘要失败: ' + JSON.stringify(e));
      return { todayCount: 0, streakDays: 0, tomorrowCount: 0 };
    }
  }

  /**
   * 获取首页完整数据
   */
  async getHomeData(ctx: common.UIAbilityContext): Promise<HomeData> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const statsDao = new DailyStatsDao();
      const cardDao = new CardDao();

      // 1. 获取今日摘要
      const summary = await this.getTodaySummary(ctx);

      // 2. 获取连续天数与今日已学
      const completion = await this.getCompletionSummary(ctx);

      // 3. 获取未来 7 天预测
      const forecast: number[] = [];
      const oneDayMs = 24 * 60 * 60 * 1000;
      let startTs = TimeUtil.startOfTomorrow();
      
      for (let i = 0; i < 7; i++) {
        const endTs = startTs + oneDayMs;
        const countResult = await cardDao.countDueInRange(store, startTs, endTs);
        forecast.push(countResult.ok ? countResult.data : 0);
        startTs = endTs;
      }

      return {
        summary,
        streakDays: completion.streakDays,
        forecast,
        todayDone: completion.todayCount
      };
    } catch (e) {
      LogUtil.e(ReviewService.TAG, '获取首页数据失败: ' + JSON.stringify(e));
      return {
        summary: this.emptyResult(),
        streakDays: 0,
        forecast: [0, 0, 0, 0, 0, 0, 0],
        todayDone: 0
      };
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
