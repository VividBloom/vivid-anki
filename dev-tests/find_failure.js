
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
    this.w = params.map(v => Math.fround(v));
    this.decay = Math.fround(-this.w[20]);
    this.factor = Math.fround(Math.pow(0.9, 1 / this.decay) - 1);
  }

  retrievability(elapsedDays, stability) {
    if (stability <= 0) return 0;
    return Math.fround(Math.pow(1 + this.factor * elapsedDays / stability, this.decay));
  }

  nextInterval(stability, desiredRetention) {
    const dr = Math.fround(Math.min(Math.max(desiredRetention, 0.01), 0.99));
    const raw = (stability / this.factor) * (Math.pow(dr, 1 / this.decay) - 1);
    return Math.fround(Math.max(raw, 0));
  }

  initStability(rating) {
    return Math.fround(Math.max(this.w[rating - 1], S_MIN_INIT));
  }

  initDifficultyRaw(rating) {
    return Math.fround(this.w[4] - Math.exp(this.w[5] * (rating - 1)) + 1);
  }

  initDifficulty(rating) {
    return this.clampDifficulty(this.initDifficultyRaw(rating));
  }

  nextDifficulty(difficulty, rating) {
    const delta = -this.w[6] * (rating - 3);
    const dPrime = difficulty + delta * ((10 - difficulty) / 9);
    const target = this.initDifficultyRaw(Rating.Easy);
    const reverted = this.w[7] * target + (1 - this.w[7]) * dPrime;
    return this.clampDifficulty(Math.fround(reverted));
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
    return this.clampStability(Math.fround(next));
  }

  shortTermStability(stability, rating) {
    const sinc = Math.fround(Math.exp(this.w[17] * (rating - 3 + this.w[18])) * Math.pow(stability, -this.w[19]));
    if (rating >= Rating.Good) {
      return Math.max(stability, Math.fround(stability * sinc));
    }
    return Math.fround(stability * sinc);
  }

  stabilityAfterSuccess(difficulty, stability, r, rating) {
    const tD = 11 - difficulty;
    const tS = Math.pow(stability, -this.w[9]);
    const tR = Math.exp(this.w[10] * (1 - r)) - 1;
    const h = rating === Rating.Hard ? this.w[15] : 1;
    const b = rating === Rating.Easy ? this.w[16] : 1;
    const c = Math.exp(this.w[8]);
    const alpha = 1 + tD * tS * tR * h * b * c;
    return Math.fround(stability * alpha);
  }

  stabilityAfterFailure(difficulty, stability, r) {
    const dF = Math.pow(difficulty, -this.w[12]);
    const sF = Math.pow(stability + 1, this.w[13]) - 1;
    const rF = Math.exp(this.w[14] * (1 - r));
    const next = this.w[11] * dF * sF * rF;
    const cap = stability / Math.exp(this.w[17] * this.w[18]);
    return Math.fround(Math.min(next, cap));
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

  clampDifficulty(d) {
    if (!Number.isFinite(d)) return D_MAX;
    return Math.min(Math.max(d, D_MIN), D_MAX);
  }

  clampStability(s) {
    if (!Number.isFinite(s) || s < S_MIN) return S_MIN;
    return Math.min(s, S_MAX);
  }
}

const fsrs = new FsrsScheduler(FSRS6_DEFAULT_PARAMS);
const p = path.join(__dirname, 'golden_vectors', 'vectors.json');
const data = JSON.parse(fs.readFileSync(p, 'utf-8'));

for (let i = 0; i < data.vectors.length; i++) {
  const v = data.vectors[i];
  const state = v.is_new ? new MemoryState(0, 0) : new MemoryState(v.stability, v.difficulty);
  const info = fsrs.next(state, v.elapsed_days, v.rating, v.desired_retention);
  
  const ds = Math.abs(info.state.stability - v.expected_stability);
  const dd = Math.abs(info.state.difficulty - v.expected_difficulty);
  const di = Math.abs(info.interval - v.expected_interval);
  
  const maxDiff = Math.max(ds, dd, di);
  if (maxDiff > 1e-3) {
    console.log(JSON.stringify({
      index: i + 1,
      input: {
        is_new: v.is_new,
        stability: v.stability,
        difficulty: v.difficulty,
        elapsed_days: v.elapsed_days,
        rating: v.rating,
        desired_retention: v.desired_retention
      },
      expected: {
        stability: v.expected_stability,
        difficulty: v.expected_difficulty,
        interval: v.expected_interval
      },
      actual: {
        stability: info.state.stability,
        difficulty: info.state.difficulty,
        interval: info.interval
      },
      difference: {
        ds, dd, di
      }
    }, null, 2));
    process.exit(0);
  }
}
console.log("No failure found with difference > 1e-3");
