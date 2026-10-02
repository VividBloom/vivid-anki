/**
 * 复习队列构建
 *
 * 设计原则：纯函数，不碰数据库。输入卡片列表与配置，输出今日队列。
 * 这样可以直接写单元测试，不用起数据库。
 *
 * 三条产品红线在这里落地：
 *   1. 永不显示逾期总数 —— 本类只返回「今天要学的」，不返回积压量
 *   2. 每日新卡上限 —— 防止第一天导入几千张后被淹没
 *   3. 回归模式分批 —— 断卡回来平滑消化，不一次性砸给用户
 */

import { TimeUtil } from '../../common/utils/TimeUtil';
import { QueueCard } from '../../common/types/ReviewTypes';

/** 队列构建配置 */
export interface QueueConfig {
  /** 全局每日新卡上限，默认 20 */
  newLimit: number;
  /** 每日复习总量上限，null 表示不限 */
  reviewLimit: number | null;
  /** 是否处于回归模式 */
  inReturnMode: boolean;
  /** 回归模式的当日配额 */
  returnQuota: number;
}

/** 构建结果 */
export interface QueueResult {
  cards: QueueCard[];
  newCount: number;
  reviewCount: number;
  /** 预计总时长（分钟），按每张 25 秒估 */
  estimatedMinutes: number;
}

/** 单张卡平均作答耗时（毫秒），用于估算时长 */
const MS_PER_CARD = 25 * 1000;

export class ReviewQueue {
  /**
   * 构建今日队列
   *
   * @param allCards 全部未删除卡片（由 DAO 层按 deleted_at IS NULL 过滤后传入）
   * @param config   队列配置
   * @param nowTs    当前时间，便于测试注入
   */
  static build(allCards: QueueCard[], config: QueueConfig,
               nowTs: number = TimeUtil.now()): QueueResult {
    const tomorrow = TimeUtil.startOfTomorrow(nowTs);

    // 1. 到期卡：due <= 次日零点（今天到期的都算，不按当前时刻截断，
    //    否则晚上打开 App 会只剩几张）
    const dueCards = allCards
      .filter((c) => !c.isNew && c.due > 0 && c.due < tomorrow)
      .sort((a, b) => a.due - b.due);

    // 2. 新卡：按创建顺序（数组原序）补到上限
    const newCards = allCards.filter((c) => c.isNew);

    let reviewTake = dueCards;
    if (config.reviewLimit !== null && config.reviewLimit > 0) {
      reviewTake = dueCards.slice(0, config.reviewLimit);
    }

    // 回归模式：整体再受当日配额约束
    if (config.inReturnMode && config.returnQuota > 0) {
      reviewTake = reviewTake.slice(0, config.returnQuota);
    }

    const newTake = newCards.slice(0, Math.max(0, config.newLimit));

    const cards = reviewTake.concat(newTake);
    const totalMs = cards.length * MS_PER_CARD;

    return {
      cards: cards,
      newCount: newTake.length,
      reviewCount: reviewTake.length,
      // 空队列必须是 0 分钟：调用方据此判断该走零复习态还是空态，
      // 返回 1 会让「今天已全部完成」与「还有 1 分钟」混淆。
      estimatedMinutes: cards.length === 0 ? 0 : Math.max(1, Math.round(totalMs / 60000))
    };
  }

  /**
   * 回归模式：断卡若干天后的分批安排（PRD 7.3）
   *
   * 目标是把积压平滑消化，而不是一次性砸给用户。
   * 注意：本方法只算「每天放出多少」，不返回积压总数 ——
   * 积压数字是新手弃坑的头号杀手，任何情况下都不应向用户展示。
   *
   * @param minDays 最少分几天，默认 3。积压大到 minDays 天装不下时自动延长天数，
   *                而不是把剩余量全压到最后一天。
   *
   * 【修复说明】原实现取 min(当日配额, cap) 但第三天不做上限约束，
   * 导致 backlog=1000 / cap=30 时返回 [30, 30, 940] —— 第三天直接爆量，
   * 既谈不上「平滑」，也违反 PRD「永不提欠账」的设计原则。
   */
  static returnPlan(backlogCount: number, normalDaily: number, minDays: number = 3): number[] {
    const cap = Math.round(normalDaily * 1.5);
    if (backlogCount <= 0) {
      return [];
    }
    if (backlogCount <= cap) {
      // 积压不多，一天就能消化完
      return [backlogCount];
    }
    // 天数取「至少 minDays」与「按上限所需天数」的较大者：
    // 宁可多分几天，也绝不单日超量。
    const days = Math.max(minDays, Math.ceil(backlogCount / cap));
    const base = Math.floor(backlogCount / days);
    const remainder = backlogCount % days;
    const plan: number[] = [];
    for (let i = 0; i < days; i++) {
      plan.push(base);
    }
    // 余数摊到前几天，使每天数量最多只差 1
    for (let i = 0; i < remainder; i++) {
      plan[i] += 1;
    }
    return plan;
  }

  /**
   * 判断是否进入回归模式（断卡 ≥3 天）
   */
  static shouldEnterReturnMode(lastStudyTs: number, nowTs: number = TimeUtil.now()): boolean {
    if (lastStudyTs <= 0) {
      return false;
    }
    return TimeUtil.elapsedDays(lastStudyTs, nowTs) >= 3;
  }
}
