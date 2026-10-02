/**
 * FSRS-6 调度器 —— 自检测试 (Plain JS version for Sandbox)
 * Includes A and B sections.
 */

const fs = require('fs');
const path = require('path');

class MemoryState {
  constructor(stability = 0, difficulty = 0) {
    this.stability = stability;
    this.difficulty = difficulty;
  }
  isInitialized() {
    return this.stability > 0 && this.difficulty >= 1.0;
  }
}

class SchedulingInfo {
  constructor(state, interval, retrievability = 0) {
    this.state = state;
    this.interval = interval;
    this.retrievability = retrievability;
  }
}

const FSRS6_DEFAULT_PARAMS = [
  0.212, 1.2931, 2.3065, 8.2956,
  6.4133, 0.8334, 3.0194, 0.001,
  1.8722, 0.1666, 0.796, 1.4835,
  0.0614, 0.2629, 1.6483, 0.6014,
  1.8729, 0.5425, 0.0912, 0.0658,
  0.1542
];

const S_MIN_INIT = 0.1;
const S_MIN = 0.01;
const S_MAX = 36500.0;
const D_MIN = 1.0;
const D_MAX = 10.0;
const DEFAULT_DESIRED_RETENTION = 0.9;

const Rating = {
  Again: 1,
  Hard: 2,
  Good: 3,
  Easy: 4
};

class FsrsScheduler {
  constructor(params = FSRS6_DEFAULT_PARAMS) {
    if (params.length !== 21) {
      throw new Error('FSRS-6 参数必须恰好 21 个');
    }
    this.w = params;
    // FSRS-6 (v4.5+) 遗忘曲线：R = (1 + factor * t/S)^(-w20)
    this.decay = Math.fround(params[20]);
    // factor = 0.9^(-1/w20) - 1
    this.factor = Math.fround(Math.pow(0.9, -1 / this.decay) - 1);
  }

  retrievability(elapsedDays, stability) {
    if (stability <= 0) return 0;
    // R = (1 + factor * t/S)^(-w20)
    const factor_t_s = Math.fround(Math.fround(this.factor * elapsedDays) / stability);
    return Math.fround(Math.pow(Math.fround(1 + factor_t_s), -this.decay));
  }

  nextInterval(stability, desiredRetention) {
    const dr = Math.min(Math.max(desiredRetention, 0.01), 0.99);
    const pow_res = Math.fround(Math.pow(dr, -1 / this.decay));
    const raw = Math.fround(Math.fround(stability / this.factor) * Math.fround(pow_res - 1));
    return Math.fround(Math.max(raw, 0));
  }

  initStability(rating) {
    return Math.fround(Math.max(this.w[rating - 1], S_MIN_INIT));
  }

  initDifficulty(rating) {
    const raw = this.w[4] - Math.exp(this.w[5] * (rating - 1)) + 1;
    return Math.fround(Math.min(Math.max(raw, D_MIN), D_MAX));
  }

  nextDifficulty(difficulty, rating) {
    const delta = Math.fround(-this.w[6] * (rating - 3));
    const d0 = Math.fround(difficulty + Math.fround(Math.fround(delta * Math.fround(10 - difficulty)) / 9));
    const target = Math.fround(Math.fround(this.w[4] - Math.fround(Math.exp(Math.fround(this.w[5] * 3)))) + 1);
    const reverted = Math.fround(Math.fround(this.w[7] * target) + Math.fround(Math.fround(1 - this.w[7]) * d0));
    return Math.fround(Math.min(Math.max(reverted, D_MIN), D_MAX));
  }

  nextStability(difficulty, stability, r, rating, elapsedDays) {
    let next;
    if (elapsedDays <= 0) {
      const sinc = Math.exp(this.w[17] * (rating - 3 + this.w[18])) * Math.pow(stability, -this.w[19]);
      next = Math.fround(stability * sinc);
      if (rating >= Rating.Good) {
        next = Math.max(stability, next);
      }
    } else if (rating === Rating.Again) {
      const dF = Math.pow(difficulty, -this.w[12]);
      const sF = Math.pow(stability + 1, this.w[13]) - 1;
      const rF = Math.exp(this.w[14] * (1 - r));
      const raw = Math.fround(this.w[11] * dF * sF * rF);
      next = Math.min(raw, Math.fround(stability / Math.exp(this.w[17] * this.w[18])));
    } else {
      const tD = Math.fround(11 - difficulty);
      const tS = Math.fround(Math.pow(stability, -this.w[9]));
      const tR = Math.fround(Math.fround(Math.exp(Math.fround(this.w[10] * Math.fround(1 - r)))) - 1);
      const boost = Math.fround(Math.exp(this.w[8]));
      const h = rating === Rating.Hard ? this.w[15] : 1;
      const b = rating === Rating.Easy ? this.w[16] : 1;
      const increment = Math.fround(Math.fround(Math.fround(Math.fround(Math.fround(Math.fround(tD * tS) * tR) * boost) * h) * b));
      next = Math.fround(stability * Math.fround(1 + increment));
    }
    
    if (!Number.isFinite(next) || next < S_MIN) return S_MIN;
    return Math.fround(Math.min(next, S_MAX));
  }

  next(state, elapsedDays, rating, desiredRetention = DEFAULT_DESIRED_RETENTION) {
    if (!state.isInitialized()) {
      const s = this.initStability(rating);
      const d = this.initDifficulty(rating);
      return new SchedulingInfo(new MemoryState(s, d), this.nextInterval(s, desiredRetention), 0);
    }
    
    const r = this.retrievability(elapsedDays, state.stability);
    const d = this.nextDifficulty(state.difficulty, rating);
    const s = this.nextStability(state.difficulty, state.stability, r, rating, elapsedDays);
    
    return new SchedulingInfo(new MemoryState(s, d), this.nextInterval(s, desiredRetention), r);
  }
}

// Test runner
let passed = 0;
let failed = 0;

function ok(cond, name, detail = '') {
  if (cond) {
    passed++;
  } else {
    failed++;
    console.log('  ✗ ' + name + (detail ? '  → ' + detail : ''));
  }
}

function near(a, b, eps = 1e-6) {
  return Math.abs(a - b) <= eps;
}

const fsrs = new FsrsScheduler();

async function run() {
  console.log('--- A段: 恒等式测试 ---');
  // A1
  for (const s of [0.1, 1, 5, 10, 100, 1000]) {
    const i = fsrs.nextInterval(s, 0.9);
    ok(near(i, s, Math.max(s * 1e-9, 1e-9)), `nextInterval(S=${s}, 0.9) === S`);
  }
  
  // A2
  const vals = [1, 2, 3, 4].map(g => fsrs.initStability(g));
  ok(near(vals[0], 0.212, 1e-9), 'S0(Again) === 0.212');
  ok(near(vals[3], 8.2956, 1e-9), 'S0(Easy) === 8.2956');

  console.log('--- B段: 黄金向量比对 ---');
  const p = path.join(process.cwd(), 'anki', 'dev-tests', 'golden_vectors', 'vectors.json');
  if (!fs.existsSync(p)) {
    console.error('vectors.json not found');
    process.exit(1);
  }

  let content = fs.readFileSync(p, 'utf-8');
  if (content.charCodeAt(0) === 0xFEFF) content = content.slice(1);
  const data = JSON.parse(content);
  
  let checked = 0;
  let mismatch = 0;
  const diffs = [];

  for (const v of data.vectors) {
    checked++;
    const state = v.is_new ? new MemoryState(0, 0) : new MemoryState(v.stability, v.difficulty);
    const info = fsrs.next(state, v.elapsed_days, v.rating, v.desired_retention);
    
    const ds = Math.abs(info.state.stability - v.expected_stability);
    const dd = Math.abs(info.state.difficulty - v.expected_difficulty);
    const di = Math.abs(info.interval - v.expected_interval);
    
    const maxDiff = Math.max(ds, dd, di);
    if (maxDiff > 1e-4) {
      mismatch++;
      diffs.push({ diff: maxDiff, desc: `Group ${checked} [new=${v.is_new}, r=${v.rating}, el=${v.elapsed_days}, S=${v.stability}, D=${v.difficulty}, DR=${v.desired_retention.toFixed(2)}]: Actual(S=${info.state.stability.toFixed(6)}, D=${info.state.difficulty.toFixed(6)}, I=${info.interval.toFixed(6)}), Expected(S=${v.expected_stability.toFixed(6)}, D=${v.expected_difficulty.toFixed(6)}, I=${v.expected_interval.toFixed(6)})` });
    }
  }

  if (mismatch > 0) {
    diffs.sort((a, b) => b.diff - a.diff);
    console.log(`B段比对失败: ${mismatch}/${checked} 组不匹配`);
    console.log("前 5 组差异最大:");
    diffs.slice(0, 5).forEach(d => console.log(d.desc));
  } else {
    console.log(`✓ B段黄金向量 ${checked} 组全部通过 (容差 1e-4)`);
  }
  
  console.log(`通过 ${passed} 项，失败 ${failed} 项`);
  if (failed > 0 || mismatch > 0) process.exit(1);
}

run();
