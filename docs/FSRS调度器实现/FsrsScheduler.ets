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

/** 稳定性下限，防止退化到 0 后公式失效 */
export const S_MIN = 0.001;
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

export class FsrsScheduler {
  private w: number[];
  private decay: number;
  private factor: number;

  /**
   * @param params FSRS 权重向量，默认使用 FSRS-6 官方默认参数
   */
  constructor(params: number[] = FSRS6_DEFAULT_PARAMS) {
    if (params.length !== 21) {
      throw new Error('FSRS-6 参数必须恰好 21 个，实际为 ' + params.length);
    }
    this.w = params;
    // 遗忘曲线：R(t,S) = (1 + FACTOR * t / S) ^ DECAY
    this.decay = -params[20];
    // FACTOR 由 DECAY 导出，以保证恒等式 R(S, S) === 0.9 成立
    this.factor = Math.pow(0.9, 1 / this.decay) - 1;
  }

  // ---------------- 遗忘曲线 ----------------

  /**
   * 可提取性 R：距上次复习 elapsedDays 天后，仍能回忆起来的概率。
   * 恒等式：retrievability(stability, stability) ≈ 0.9
   */
  retrievability(elapsedDays: number, stability: number): number {
    if (stability <= 0) {
      // 新卡没有稳定性；返回 0 并由调用方走初始化分支
      return 0;
    }
    return Math.pow(1 + this.factor * elapsedDays / stability, this.decay);
  }

  /**
   * 由稳定性与目标留存率反解间隔（天）。
   * 恒等式：nextInterval(s, 0.9) === s（误差应 < 1e-9）
   */
  nextInterval(stability: number, desiredRetention: number): number {
    const dr = this.clampRetention(desiredRetention);
    const raw = (stability / this.factor) * (Math.pow(dr, 1 / this.decay) - 1);
    return Math.max(raw, 0);
  }

  // ---------------- 初始化（新卡分支） ----------------

  /**
   * 初始稳定性：S0(G) = max(w[G-1], S_MIN)
   * 注意这里绝不能返回 0 —— 否则后续 S^(-w9) 会变成 Infinity。
   */
  initStability(rating: number): number {
    return Math.max(this.w[rating - 1], S_MIN);
  }

  /**
   * 初始难度：D0(G) = clamp(w4 - e^(w5*(G-1)) + 1, 1, 10)
   */
  initDifficulty(rating: number): number {
    const raw = this.w[4] - Math.exp(this.w[5] * (rating - 1)) + 1;
    return this.clampDifficulty(raw);
  }

  // ---------------- 更新（老卡分支） ----------------

  /**
   * 难度更新：先按评分做增量，再向 D0(Easy) 做均值回归，防止漂移。
   */
  nextDifficulty(difficulty: number, rating: number): number {
    const delta = -this.w[6] * (rating - 3);
    // 难度越高，可调整空间越小（乘 (10-D)/9）
    const dPrime = difficulty + delta * ((10 - difficulty) / 9);
    const reverted = this.w[7] * this.initDifficulty(Rating.Easy) + (1 - this.w[7]) * dPrime;
    return this.clampDifficulty(reverted);
  }

  /**
   * 稳定性更新。同日复习（elapsedDays <= 0）走短期公式，否则走长期公式。
   */
  nextStability(difficulty: number, stability: number, r: number, rating: number,
                elapsedDays: number): number {
    let next: number;
    if (elapsedDays <= 0) {
      next = this.shortTermStability(stability, rating);
    } else if (rating === Rating.Again) {
      next = this.stabilityAfterFailure(difficulty, stability, r);
    } else {
      next = this.stabilityAfterSuccess(difficulty, stability, r, rating);
    }
    return this.clampStability(next);
  }

  /** 短期稳定性（同日复习）：S' = S * e^(w17*(G-3+w18)) * S^(-w19) */
  private shortTermStability(stability: number, rating: number): number {
    const sinc = Math.exp(this.w[17] * (rating - 3 + this.w[18])) * Math.pow(stability, -this.w[19]);
    return stability * sinc;
  }

  /**
   * 成功回忆（Hard / Good / Easy）后的稳定性。
   * S' = S * (1 + t_d * t_s * t_r * h * b * e^w8)
   *   t_d = 11 - D     难度惩罚：越难增长越慢
   *   t_s = S^(-w9)    饱和：越稳定越难更稳定
   *   t_r = e^(w10*(1-R)) - 1    间隔效应：R 越低收益越大
   */
  private stabilityAfterSuccess(difficulty: number, stability: number, r: number,
                                rating: number): number {
    const tD = 11 - difficulty;
    const tS = Math.pow(stability, -this.w[9]);
    const tR = Math.exp(this.w[10] * (1 - r)) - 1;
    const h = rating === Rating.Hard ? this.w[15] : 1;
    const b = rating === Rating.Easy ? this.w[16] : 1;
    const c = Math.exp(this.w[8]);
    const alpha = 1 + tD * tS * tR * h * b * c;
    return stability * alpha;
  }

  /**
   * 遗忘（Again）后的稳定性。
   * S' = min(w11 * D^(-w12) * ((S+1)^w13 - 1) * e^(w14*(1-R)), S)
   * min(..., S) 保证失败后稳定性只降不升。
   */
  private stabilityAfterFailure(difficulty: number, stability: number, r: number): number {
    const dF = Math.pow(difficulty, -this.w[12]);
    const sF = Math.pow(stability + 1, this.w[13]) - 1;
    const rF = Math.exp(this.w[14] * (1 - r));
    const raw = this.w[11] * dF * sF * rF;
    return Math.min(raw, stability);
  }

  // ---------------- 主入口 ----------------

  /**
   * 计算一次评分后的完整调度结果。
   *
   * @param state        当前记忆状态；未初始化（S=0 且 D=0）时自动走新卡分支
   * @param elapsedDays  距上次复习的天数；同日复习传 0
   * @param rating       1=再来一次 2=有点难 3=记得 4=太简单
   * @param desiredRetention 目标留存率，默认 0.9
   */
  next(state: MemoryState, elapsedDays: number, rating: number,
       desiredRetention: number = DEFAULT_DESIRED_RETENTION): SchedulingInfo {
    this.assertRating(rating);

    // 分支一：新卡 —— 绝不能把 S=0 / D=0 代入老卡公式
    if (!state.isInitialized()) {
      const s = this.initStability(rating);
      const d = this.initDifficulty(rating);
      return new SchedulingInfo(new MemoryState(s, d), this.nextInterval(s, desiredRetention), 0);
    }

    // 分支二：老卡
    const r = this.retrievability(elapsedDays, state.stability);
    const d = this.nextDifficulty(state.difficulty, rating);
    const s = this.nextStability(state.difficulty, state.stability, r, rating, elapsedDays);
    return new SchedulingInfo(new MemoryState(s, d), this.nextInterval(s, desiredRetention), r);
  }

  /**
   * 便捷方法：直接算出下次复习间隔（天，向上取整，至少 1 天）。
   * 同日复习（间隔 < 1 天）返回 0，由业务层决定是否进入当日队列。
   */
  nextIntervalDays(state: MemoryState, elapsedDays: number, rating: number,
                   desiredRetention: number = DEFAULT_DESIRED_RETENTION): number {
    const info = this.next(state, elapsedDays, rating, desiredRetention);
    if (info.interval < 1) {
      return 0;
    }
    return Math.round(info.interval);
  }

  // ---------------- 工具 ----------------

  private assertRating(rating: number): void {
    if (rating !== 1 && rating !== 2 && rating !== 3 && rating !== 4) {
      throw new Error('评分必须为 1-4，实际为 ' + rating);
    }
  }

  private clampDifficulty(d: number): number {
    if (!isFinite(d)) {
      return D_MAX;
    }
    return Math.min(Math.max(d, D_MIN), D_MAX);
  }

  private clampStability(s: number): number {
    if (!isFinite(s) || s < S_MIN) {
      return S_MIN;
    }
    return Math.min(s, S_MAX);
  }

  private clampRetention(r: number): number {
    // 留存率必须在 (0, 1) 开区间内，否则反解间隔会发散
    return Math.min(Math.max(r, 0.01), 0.99);
  }
}
