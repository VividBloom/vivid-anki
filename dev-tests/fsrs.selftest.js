/**
 * FSRS-6 调度器 —— 自检测试 (Plain JS version for Node.js)
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
      throw new Error('FSRS-6 参数必须恰好 21 个，实际为 ' + params.length);
    }
    this.w = params.map(v => Math.fround(v));
    this.decay = Math.fround(-this.w[20]);
    this.factor = Math.fround(Math.fround(Math.pow(Math.fround(0.9), Math.fround(1 / this.decay))) - 1);
  }

  retrievability(elapsedDays, stability) {
    if (stability <= 0) return 0;
    const t = Math.fround(elapsedDays);
    const s = Math.fround(stability);
    const ratio = Math.fround(t / s);
    const inner = Math.fround(1 + Math.fround(this.factor * ratio));
    return Math.fround(Math.pow(inner, this.decay));
  }

  nextInterval(stability, desiredRetention) {
    const dr = Math.fround(Math.min(Math.max(desiredRetention, 0.01), 0.99));
    const s = Math.fround(stability);
    const p = Math.fround(1 / this.decay);
    const drPow = Math.fround(Math.pow(dr, p));
    const raw = Math.fround((s / this.factor) * (drPow - 1));
    return Math.fround(Math.max(raw, 0));
  }

  initStability(rating) {
    return Math.max(this.w[rating - 1], S_MIN_INIT);
  }

  initDifficultyRaw(rating) {
    const rMinus1 = Math.fround(rating - 1);
    const expPart = Math.fround(Math.exp(Math.fround(this.w[5] * rMinus1)));
    return Math.fround(Math.fround(this.w[4] - expPart) + 1);
  }

  initDifficulty(rating) {
    return Math.fround(this.clampDifficulty(this.initDifficultyRaw(rating)));
  }

  nextDifficulty(difficulty, rating) {
    const rMinus3 = Math.fround(rating - 3);
    const delta = Math.fround(-this.w[6] * rMinus3);
    const tenMinusD = Math.fround(10 - difficulty);
    const ratio = Math.fround(tenMinusD / 9);
    const dPrime = Math.fround(difficulty + Math.fround(delta * ratio));
    const target = this.initDifficultyRaw(Rating.Easy);
    const w7 = this.w[7];
    const reverted = Math.fround(Math.fround(w7 * target) + Math.fround(Math.fround(1 - w7) * dPrime));
    return this.clampDifficulty(reverted);
  }

  nextStability(difficulty, stability, r, rating, elapsedDays) {
    let next;
    if (elapsedDays <= 0) {
      next = this.shortTermStability(stability, rating);
    } else if (rating === Rating.Again) {
      next = this.stabilityAfterFailure(difficulty, stability, r);
    } else {
      next = this.stabilityAfterSuccess(difficulty, stability, r, rating);
    }
    return this.clampStability(next);
  }

  shortTermStability(stability, rating) {
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

  stabilityAfterSuccess(difficulty, stability, r, rating) {
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

  stabilityAfterFailure(difficulty, stability, r) {
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

  next(state, elapsedDays, rating, desiredRetention = DEFAULT_DESIRED_RETENTION) {
    if (!state.isInitialized()) {
      const s = this.initStability(rating);
      const d = this.initDifficulty(rating);
      return new SchedulingInfo(
        new MemoryState(Math.fround(s), Math.fround(d)),
        Math.fround(this.nextInterval(s, desiredRetention)),
        0
      );
    }
    const r = this.retrievability(elapsedDays, state.stability);
    const d = this.nextDifficulty(state.difficulty, rating);
    const s = this.nextStability(state.difficulty, state.stability, r, rating, elapsedDays);
    return new SchedulingInfo(
      new MemoryState(Math.fround(s), Math.fround(d)),
      Math.fround(this.nextInterval(s, desiredRetention)),
      r
    );
  }

  clampDifficulty(d) {
    if (!Number.isFinite(d)) return D_MAX;
    return Math.min(Math.max(d, D_MIN), D_MAX);
  }

  clampStability(s) {
    if (!Number.isFinite(s) || s < S_MIN) return S_MIN;
    return Math.min(s, S_MAX);
  }
}

// ============================================================
// Test Framework
// ============================================================
let passed = 0;
let failed = 0;

function ok(cond, name, detail = '') {
  if (cond) {
    passed++;
    console.log('  ✓ ' + name);
  } else {
    failed++;
    console.log('  ✗ ' + name + (detail ? '  → ' + detail : ''));
  }
}

function near(a, b, eps = 1e-6) {
  return Math.abs(a - b) <= eps;
}

function section(t) {
  console.log('\n' + t);
}

const fsrs = new FsrsScheduler(FSRS6_DEFAULT_PARAMS);

// ============================================================
section('A1. 遗忘曲线恒等式');
// ============================================================
for (const s of [0.1, 1, 5, 10, 100, 1000]) {
  const i = fsrs.nextInterval(s, 0.9);
  ok(near(i, s, Math.max(s * 1e-6, 1e-6)), 'nextInterval(S=' + s + ', 0.9) === S', '实际 ' + i);
}

for (const s of [1, 5, 50, 365]) {
  const r = fsrs.retrievability(s, s);
  ok(near(r, 0.9, 1e-7), 'retrievability(S=' + s + ', ' + s + ') === 0.9', '实际 ' + r);
}

// ============================================================
section('A2. 新卡初始化分支');
// ============================================================
{
  const vals = [1, 2, 3, 4].map((g) => fsrs.initStability(g));
  ok(vals.every((v) => v > 0), 'initStability 恒 > 0');
  ok(near(vals[0], 0.212), 'S0(Again) === 0.212');
}

// ============================================================
section('B. 黄金测试向量');
// ============================================================
const p = path.join(__dirname, 'golden_vectors', 'vectors.json');
if (!fs.existsSync(p)) {
  console.error('未找到 vectors.json');
  process.exit(1);
}

const data = JSON.parse(fs.readFileSync(p, 'utf-8'));
let mismatch = 0;
let checked = 0;
const diffs = [];
const newCardCoverage = new Set();

for (const v of data.vectors) {
  checked++;
  const state = v.is_new ? new MemoryState(0, 0) : new MemoryState(v.stability, v.difficulty);
  const info = fsrs.next(state, v.elapsed_days, v.rating, v.desired_retention);
  
  const ds = Math.abs(info.state.stability - v.expected_stability);
  const dd = Math.abs(info.state.difficulty - v.expected_difficulty);
  const di = Math.abs(info.interval - v.expected_interval);
  
  if (v.is_new) newCardCoverage.add(`${v.rating}_${v.elapsed_days}`);

  const okS = ds < 1e-4;
  const okD = dd < 1e-4;
  const okI = di < 5e-4; // 间隔放大效应，放宽至 5e-4以应对跨语言 powf 差异

  if (!okS || !okD || !okI) {
    mismatch++;
    if (diffs.length < 5) {
      diffs.push(`组 ${checked} (${v.is_new ? '新卡' : '老卡'}, Rating=${v.rating}, Elapsed=${v.elapsed_days}):\n` +
                 `    输入: S=${v.stability}, D=${v.difficulty}, R_desired=${v.desired_retention}\n` +
                 `    期望: S=${v.expected_stability.toFixed(8)}, D=${v.expected_difficulty.toFixed(8)}, I=${v.expected_interval.toFixed(8)}\n` +
                 `    实际: S=${info.state.stability.toFixed(8)}, D=${info.state.difficulty.toFixed(8)}, I=${info.interval.toFixed(8)}\n` +
                 `    差异: dS=${ds.toExponential(2)}, dD=${dd.toExponential(2)}, dI=${di.toExponential(2)}`);
    }
  }
}

if (mismatch > 0) {
  ok(false, `黄金向量失败: ${mismatch} 组不匹配`, '\n' + diffs.join('\n\n'));
} else {
  ok(true, `黄金向量 ${checked} 组全部对齐`);
}
ok(newCardCoverage.size >= 4, `覆盖了 ${newCardCoverage.size} 组新卡`);

console.log(`\n通过 ${passed}, 失败 ${failed}`);
if (failed > 0) process.exit(1);
