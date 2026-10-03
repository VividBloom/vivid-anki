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

/**
 * 复习队列构建器
 * 
 * 设计原则：
 * 1. 纯函数设计：不直接访问数据库，通过外部注入数据进行计算，便于单元测试。
 * 2. 心理学优化：严格遵守“不显示逾期总数”红线，仅返回当日需完成的任务，降低用户压力。
 * 3. 流量控制：实现每日新卡上限与回归分批算法，防止用户被海量任务淹没。
 */
export class ReviewQueue {
  /**
   * 构建今日待复习队列
   * 
   * @param allCards 全部未删除的卡片列表（已由 DAO 层过滤逻辑删除项）
   * @param config   队列配置项（含新卡上限、复习上限、回归模式参数）
   * @param nowTs    当前时间戳（默认为系统当前时间，支持测试注入）
   * @returns 包含待复习卡片数组、计数统计及预计耗时的结果对象
   */
  static build(allCards: QueueCard[], config: QueueConfig,
               nowTs: number = TimeUtil.now()): QueueResult {
    // 确定时间窗口：今天到期的卡片定义为 due <= 次日零点
    const tomorrow = TimeUtil.startOfTomorrow(nowTs);

    // 逻辑分支 1：筛选到期卡片（老卡）
    // 排序规则：按到期时间升序，确保优先复习最迫切的内容
    const dueCards = allCards
      .filter((c) => !c.isNew && c.due > 0 && c.due < tomorrow)
      .sort((a, b) => a.due - b.due);

    // 逻辑分支 2：筛选新卡片
    // 配合 ImportService 的阶梯式由于时间 (staggered due) 逻辑，只取今天分配到的新内容
    const newCards = allCards
      .filter((c) => c.isNew && c.due < tomorrow)
      .sort((a, b) => a.due - b.due || a.id - b.id);

    // 应用复习上限约束
    let reviewTake = dueCards;
    if (config.reviewLimit !== null && config.reviewLimit > 0) {
      reviewTake = dueCards.slice(0, config.reviewLimit);
    }

    // 回归模式约束：若用户断卡多日回来，则受平滑配额限制
    if (config.inReturnMode && config.returnQuota > 0) {
      reviewTake = reviewTake.slice(0, config.returnQuota);
    }

    // 应用新卡上限约束
    const newTake = newCards.slice(0, Math.max(0, config.newLimit));

    // 合并队列并计算预计耗时
    const cards = reviewTake.concat(newTake);
    const totalMs = cards.length * MS_PER_CARD;

    return {
      cards: cards,
      newCount: newTake.length,
      reviewCount: reviewTake.length,
      // 耗时估算逻辑：空队列返回 0，非空队列至少返回 1 分钟以保持正向激励
      estimatedMinutes: cards.length === 0 ? 0 : Math.max(1, Math.round(totalMs / 60000))
    };
  }

  /**
   * 回归模式平滑分批算法 (PRD 7.3)
   * 
   * 当用户长时间未登录导致大量积压时，将积压量平摊到未来数日。
   * 核心准则：宁可多分几天，也绝不让单日任务量超过阈值，且绝不向用户展示积压总数。
   * 
   * @param backlogCount 积压的到期卡片总数
   * @param normalDaily 用户设定的每日正常复习量
   * @param minDays 最少分摊天数，默认 3 天
   * @returns 每日分配的复习配额数组
   */
  static returnPlan(backlogCount: number, normalDaily: number, minDays: number = 3): number[] {
    // 单日宽限上限：允许比平时多 50% 的工作量作为热身
    const cap = Math.round(normalDaily * 1.5);
    
    if (backlogCount <= 0) {
      return [];
    }
    
    if (backlogCount <= cap) {
      // 积压量较小，一天内即可温和消化
      return [backlogCount];
    }
    
    // 计算天数：取「最小天数」与「按上限平摊所需天数」的最大值
    const days = Math.max(minDays, Math.ceil(backlogCount / cap));
    const base = Math.floor(backlogCount / days);
    const remainder = backlogCount % days;
    const plan: number[] = [];
    
    // 平均分配基础值
    for (let i = 0; i < days; i++) {
      plan.push(base);
    }
    
    // 将余数均匀摊到前几天，确保每日波动量不超过 1
    for (let i = 0; i < remainder; i++) {
      plan[i] += 1;
    }
    return plan;
  }

  /**
   * 判断是否触发回归模式
   * 定义：当距离上次复习超过 3 天（含）时，视为断卡回归
   * @param lastStudyTs 上次复习的毫秒时间戳
   * @param nowTs 当前时间戳
   */
  static shouldEnterReturnMode(lastStudyTs: number, nowTs: number = TimeUtil.now()): boolean {
    if (lastStudyTs <= 0) {
      return false;
    }
    return TimeUtil.elapsedDays(lastStudyTs, nowTs) >= 3;
  }
}
