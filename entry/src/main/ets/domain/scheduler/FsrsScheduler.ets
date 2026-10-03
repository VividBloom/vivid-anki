/**
 * FSRS-6 调度器 —— ArkTS 参考实现
 *
 * 设计约束（对应 PRD 8.4）：
 *   1. 纯函数，不依赖 UI、不依赖数据库、不依赖网络
 *   2. 必须区分「新卡初始化」与「老卡更新」两条分支
 *      —— 新卡 S=0 / D=0，直接代入 nextState 会产生 NaN，这是最容易踩的坑
 *   3. 所有公式集中在Scheduler 内部，参数通过构造注入，便于跑黄金测试向量
 *
 * 协议说明：默认参数取自 fsrs crate（BSD-3-Clause），可合法使用。
 *           未使用 Anki rslib（AGPL-3.0），本文件为自研实现。
 */

// ============================================================
// 常量
// ============================================================

/** FSRS-6 默认 21 参数（fsrs crate DEFAULT_PARAMETERS） */
export const FSRS6_DEFAULT_PARAMS: number[] = [
  0.212, 1.2931, 2.3065, 8.2956,        // w0-w3  初始稳定性（Again/Hard/Good/Easy）
  6.4133, 0.8334, 3.0194, 0.001,        // w4-w7  初始难度 / 难度更新 / 均值回归
  1.8722, 0.1666, 0.796, 1.4835,        // w8-w11 成功时稳定性 / 失败基准
  0.0614, 0.2629, 1.6483, 0.6014,       // w12-w15 失败时稳定性 / Hard 惩罚
  1.8729, 0.5425, 0.0912, 0.0658,       // w16-w19 Easy 奖励 / 短期稳定性
  0.1542                                 // w20    遗忘曲线 decay
];

/** 评分区间：与 UI 四档按钮一一对应，顺序不可改 */
export enum Rating {
  /** 再来一次 —— 完全想不起来 */
  Again = 1,
  /** 有点难 —— 想起来了但很吃力 */
  Hard = 2,
  /** 记得 —— 正常想起来了 */
  Good = 3,
  /** 太简单 —— 毫不费力 */
  Easy = 4
}

/**
 * 稳定性下限（通用），防止退化到 0 后公式失效。
 * 官方 fsrs crate 取 0.01。
 */
export const S_MIN = 0.01;
/**
 * 初始稳定性下限。官方取 0.1，比通用下限更严格 ——
 * 新卡首次评分后至少要撑住半天，否则会立刻回到当日队列。
 *
 * 这两个常量不能合并：initStability 与 clampStability 的语义不同，
 * 用同一个值会让「初始化」与「更新后钳制」互相干扰。
 */
export const S_MIN_INIT = 0.1;
/** 稳定性上限（100 年），防止数值发散 */
export const S_MAX = 36500.0;
/** 难度区间 */
export const D_MIN = 1.0;
export const D_MAX = 10.0;
/** 默认目标留存率 */
export const DEFAULT_DESIRED_RETENTION = 0.9;

// ============================================================
// 数据结构
// ============================================================

/**
 * 记忆状态。对应 card 表的 stability / difficulty 两列。
 * stability = 0 且 difficulty = 0 表示「新卡，尚未初始化」。
 */
export class MemoryState {
  stability: number;
  difficulty: number;

  constructor(stability: number = 0, difficulty: number = 0) {
    this.stability = stability;
    this.difficulty = difficulty;
  }

  /** 是否已完成首次评分（即是否走过 init 分支） */
  isInitialized(): boolean {
    return this.stability > 0 && this.difficulty >= D_MIN;
  }
}

/** 一次调度的完整结果 */
export class SchedulingInfo {
  /** 新的记忆状态，写回 card.stability / card.difficulty */
  state: MemoryState;
  /** 由目标留存率反解出的间隔（天），可为小数；写回 card.due 前需按业务规则取整 */
  interval: number;
  /** 复习前的可提取性 R，仅老卡有意义；新卡为 0。用于埋点与调试 */
  retrievability: number;

  constructor(state: MemoryState, interval: number, retrievability: number = 0) {
    this.state = state;
    this.interval = interval;
    this.retrievability = retrievability;
  }
}

// ============================================================
// 调度器
// ============================================================

/**
 * FSRS-6 调度器 —— ArkTS 参考实现
 * 
 * 核心逻辑：基于自由间隔重复调度算法 (FSRS-6) 计算记忆状态与下次复习时间。
 * 设计约束：
 * 1. 纯函数设计：不依赖外部环境（UI/DB/网络），便于测试与迁移。
 * 2. 状态隔离：严格区分新卡片（S=0/D=0）与已评分卡片的处理逻辑。
 * 3. 算法对齐：权重向量 (21参数) 与官方 fsrs crate 保持一致，支持 BSD-3 协议。
 */
export class FsrsScheduler {
  private w: number[];
  private decay: number;
  private factor: number;

  /**
   * 构造函数：注入算法权重向量
   * @param params 21位长度的权重数组，缺省使用 FSRS6_DEFAULT_PARAMS
   * @throws Error 当参数长度不等于 21 时抛出异常
   */
  constructor(params: number[] = FSRS6_DEFAULT_PARAMS) {
    if (params.length !== 21) {
      throw new Error('FSRS-6 参数必须恰好 21 个，实际为 ' + params.length);
    }
    // 使用 Math.fround 强制 32 位浮点精度，对齐 Rust 实现，减少多轮调度后的累计误差
    this.w = params.map(v => Math.fround(v));
    // 遗忘曲线基本公式：R = (1 + factor * t / S) ^ decay
    this.decay = Math.fround(-this.w[20]);
    // 预计算因子，保证当间隔 t = 稳定性 S 时，留存率 R 恰好等于 0.9
    this.factor = Math.fround(Math.fround(Math.pow(Math.fround(0.9), Math.fround(1 / this.decay))) - 1);
  }

  /**
   * 计算可提取性 (Retrievability)：即用户能回忆起内容的概率
   * @param elapsedDays 自上次复习以来经过的天数
   * @param stability 当前卡片的稳定性（记忆持续时间）
   * @returns 0.0 ~ 1.0 之间的概率值
   */
  retrievability(elapsedDays: number, stability: number): number {
    if (stability <= 0) {
      // 未初始化的卡片无稳定性概念，返回 0 强制走初始化逻辑
      return 0;
    }
    const t = Math.fround(elapsedDays);
    const s = Math.fround(stability);
    const ratio = Math.fround(t / s);
    const inner = Math.fround(1 + Math.fround(this.factor * ratio));
    return Math.fround(Math.pow(inner, this.decay));
  }

  /**
   * 根据目标留存率反解复习间隔
   * @param stability 记忆稳定性
   * @param desiredRetention 用户期望的留存率（推荐 0.9）
   * @returns 理论复习间隔天数（浮点数）
   */
  nextInterval(stability: number, desiredRetention: number): number {
    const dr = Math.fround(Math.min(Math.max(desiredRetention, 0.01), 0.99));
    const s = Math.fround(stability);
    const p = Math.fround(1 / this.decay);
    const drPow = Math.fround(Math.pow(dr, p));
    const raw = Math.fround(Math.fround(s / this.factor) * Math.fround(drPow - 1));
    return Math.fround(Math.max(raw, 0));
  }

  /**
   * 新卡片初始化稳定性计算
   * @param rating 用户评分 (1-4)
   * @returns 初始稳定性值，下限受 S_MIN_INIT 保护
   */
  initStability(rating: number): number {
    return Math.max(this.w[rating - 1], S_MIN_INIT);
  }

  /**
   * 计算初始难度值
   * @param rating 用户评分
   * @returns 初始难度（原始值）
   */
  private initDifficultyRaw(rating: number): number {
    const rMinus1 = Math.fround(rating - 1);
    const expPart = Math.fround(Math.exp(Math.fround(this.w[5] * rMinus1)));
    return Math.fround(Math.fround(this.w[4] - expPart) + 1);
  }

  /**
   * 获取受限的初始难度值 (1.0 ~ 10.0)
   * @param rating 用户评分
   * @returns 钳制后的难度值
   */
  initDifficulty(rating: number): number {
    return this.clampDifficulty(this.initDifficultyRaw(rating));
  }

  /**
   * 计算下一次复习后的难度值（含均值回归逻辑）
   * @param difficulty 当前难度
   * @param rating 本次评分
   * @returns 更新后的难度值
   */
  nextDifficulty(difficulty: number, rating: number): number {
    const rMinus3 = Math.fround(rating - 3);
    const delta = Math.fround(-this.w[6] * rMinus3);
    const tenMinusD = Math.fround(10 - difficulty);
    const ratio = Math.fround(tenMinusD / 9);
    const dPrime = Math.fround(difficulty + Math.fround(delta * ratio));
    
    // 均值回归：防止难度数值向极端偏移，向“简单”评分对应的难度靠拢
    const target = this.initDifficultyRaw(Rating.Easy);
    const w7 = this.w[7];
    const reverted = Math.fround(Math.fround(w7 * target) + Math.fround(Math.fround(1 - w7) * dPrime));
    return this.clampDifficulty(reverted);
  }

  /**
   * 计算评分后的新稳定性
   * @param difficulty 当前难度
   * @param stability 当前稳定性
   * @param r 当前可提取性（概率）
   * @param rating 用户评分
   * @param elapsedDays 实际间隔天数
   * @returns 更新后的稳定性
   */
  nextStability(difficulty: number, stability: number, r: number, rating: number,
                elapsedDays: number): number {
    let next: number;
    // 复杂逻辑分支：区分同日复习、失败反馈、成功反馈三种场景
    if (elapsedDays <= 0) {
      // 同日复习（短时记忆）：使用短期稳定性公式，防止频繁刷分导致稳定性膨胀
      next = this.shortTermStability(stability, rating);
    } else if (rating === Rating.Again) {
      // 遗忘反馈：大幅降低稳定性，但受限于卡片历史最小稳定性
      next = this.stabilityAfterFailure(difficulty, stability, r);
    } else {
      // 回忆成功：根据当前难度与留存率计算新的稳定性增量
      next = this.stabilityAfterSuccess(difficulty, stability, r, rating);
    }
    return this.clampStability(next);
  }

  /**
   * 短期稳定性算法：用于处理同一天内的多次复习
   */
  private shortTermStability(stability: number, rating: number): number {
    const rMinus3 = Math.fround(rating - 3);
    const w18 = this.w[18];
    const expPart = Math.fround(Math.exp(Math.fround(this.w[17] * Math.fround(rMinus3 + w18))));
    const powPart = Math.fround(Math.pow(stability, Math.fround(-this.w[19])));
    const sinc = Math.fround(expPart * powPart);
    if (rating >= Rating.Good) {
      return Math.fround(Math.max(stability, Math.fround(stability * sinc)));
    }
    return Math.fround(stability * sinc);
  }

  /**
   * 成功复习后的长期稳定性增长公式
   */
  private stabilityAfterSuccess(difficulty: number, stability: number, r: number,
                                rating: number): number {
    const tD = Math.fround(11 - difficulty);
    const tS = Math.fround(Math.pow(stability, Math.fround(-this.w[9])));
    const tR = Math.fround(Math.fround(Math.exp(Math.fround(this.w[10] * Math.fround(1 - r)))) - 1);
    const h = Math.fround(rating === Rating.Hard ? this.w[15] : 1);
    const b = Math.fround(rating === Rating.Easy ? this.w[16] : 1);
    const c = Math.fround(Math.exp(this.w[8]));
    let tmp = Math.fround(c * h);
    tmp = Math.fround(tmp * b);
    tmp = Math.fround(tmp * tR);
    tmp = Math.fround(tmp * tD);
    tmp = Math.fround(tmp * tS);
    const alpha = Math.fround(1 + tmp);
    return Math.fround(stability * alpha);
  }

  /**
   * 复习失败（遗忘）后的稳定性惩罚公式
   */
  private stabilityAfterFailure(difficulty: number, stability: number, r: number): number {
    const dF = Math.fround(Math.pow(difficulty, Math.fround(-this.w[12])));
    const sPlus1 = Math.fround(stability + 1);
    const sF = Math.fround(Math.fround(Math.pow(sPlus1, this.w[13])) - 1);
    const rF = Math.fround(Math.exp(Math.fround(this.w[14] * Math.fround(1 - r))));
    let next = Math.fround(this.w[11] * dF);
    next = Math.fround(next * sF);
    next = Math.fround(next * rF);
    const capExp = Math.fround(Math.exp(Math.fround(this.w[17] * this.w[18])));
    const cap = Math.fround(stability / capExp);
    return Math.fround(Math.min(next, cap));
  }

  /**
   * 调度核心入口：计算单次评分后的所有记忆参数
   * @param state 当前记忆状态（稳定性与难度）
   * @param elapsedDays 实际经过天数
   * @param rating 用户评分
   * @param desiredRetention 期望留存率
   * @returns 包含新状态、间隔及可提取性的调度结果对象
   */
  next(state: MemoryState, elapsedDays: number, rating: number,
       desiredRetention: number = DEFAULT_DESIRED_RETENTION): SchedulingInfo {
    this.assertRating(rating);

    // 逻辑流转：判断卡片是否为首次复习
    if (!state.isInitialized()) {
      // 新卡分支：直接根据评分初始化 S 和 D
      const s = this.initStability(rating);
      const d = this.initDifficulty(rating);
      return new SchedulingInfo(
        new MemoryState(Math.fround(s), Math.fround(d)),
        Math.fround(this.nextInterval(s, desiredRetention)),
        0
      );
    }

    // 老卡分支：基于历史状态更新参数
    const r = this.retrievability(elapsedDays, state.stability);
    const d = this.nextDifficulty(state.difficulty, rating);
    const s = this.nextStability(state.difficulty, state.stability, r, rating, elapsedDays);
    
    return new SchedulingInfo(
      new MemoryState(Math.fround(s), Math.fround(d)),
      Math.fround(this.nextInterval(s, desiredRetention)),
      r
    );
  }

  /**
   * 业务级间隔计算：获取下次复习的天数（已取整）
   * @returns 下次复习的整数天数，0 表示需在当日队列内处理
   */
  nextIntervalDays(state: MemoryState, elapsedDays: number, rating: number,
                   desiredRetention: number = DEFAULT_DESIRED_RETENTION): number {
    const info = this.next(state, elapsedDays, rating, desiredRetention);
    if (info.interval < 1) {
      return 0;
    }
    return Math.round(info.interval);
  }

  private assertRating(rating: number): void {
    if (rating !== 1 && rating !== 2 && rating !== 3 && rating !== 4) {
      throw new Error('评分必须为 1-4，实际为 ' + rating);
    }
  }

  private clampDifficulty(d: number): number {
    if (!Number.isFinite(d)) {
      return D_MAX;
    }
    return Math.min(Math.max(d, D_MIN), D_MAX);
  }

  private clampStability(s: number): number {
    if (!Number.isFinite(s) || s < S_MIN) {
      return S_MIN;
    }
    return Math.min(s, S_MAX);
  }
}

  private clampRetention(r: number): number {
    // 留存率必须在 (0, 1) 开区间内，否则反解间隔会发散
    return Math.min(Math.max(r, 0.01), 0.99);
  }
}
