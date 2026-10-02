import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import {
  FsrsScheduler, MemoryState, Rating,
  FSRS6_DEFAULT_PARAMS
} from '../../main/ets/domain/scheduler/FsrsScheduler';
import fs from '@ohos.file.fs';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';

export default function fsrsSchedulerTest() {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const context = delegator.getAppContext();
  const fsrs = new FsrsScheduler(FSRS6_DEFAULT_PARAMS);

  function near(a: number, b: number, eps: number = 1e-6): boolean {
    return Math.abs(a - b) <= eps;
  }

  describe('FsrsSchedulerTest', () => {
    // ============================================================
    // A 段：自洽性断言
    // ============================================================

    it('A1_遗忘曲线恒等式_IntervalEqualsStability', 0, () => {
      for (const s of [0.1, 1, 5, 10, 100, 1000]) {
        const i = fsrs.nextInterval(s, 0.9);
        expect(near(i, s, Math.max(s * 1e-6, 1e-6))).assertTrue();
      }
    });

    it('A1_遗忘曲线恒等式_RetrievabilityAtStability', 0, () => {
      for (const s of [1, 5, 50, 365]) {
        const r = fsrs.retrievability(s, s);
        expect(near(r, 0.9, 1e-7)).assertTrue();
      }
    });

    it('A1_遗忘曲线单调性_Time', 0, () => {
      let prev = 1.1;
      for (const t of [0, 1, 2, 5, 10, 30, 100]) {
        const r = fsrs.retrievability(t, 10);
        expect(r <= prev).assertTrue();
        prev = r;
      }
    });

    it('A1_遗忘曲线单调性_Retention', 0, () => {
      let prev = -1;
      for (const dr of [0.99, 0.95, 0.9, 0.85, 0.8, 0.7]) {
        const i = fsrs.nextInterval(10, dr);
        expect(i >= prev).assertTrue();
        prev = i;
      }
    });

    it('A2_新卡初始化_Stability', 0, () => {
      const vals = [1, 2, 3, 4].map((g) => fsrs.initStability(g));
      expect(vals.every((v) => v > 0)).assertTrue();
      for (let i = 1; i < vals.length; i++) {
        expect(vals[i] > vals[i - 1]).assertTrue();
      }
      expect(near(vals[0], 0.212, 1e-9)).assertTrue();
      expect(near(vals[3], 8.2956, 1e-9)).assertTrue();
    });

    it('A2_新卡初始化_Difficulty', 0, () => {
      const vals = [1, 2, 3, 4].map((g) => fsrs.initDifficulty(g));
      expect(vals.every((v) => v >= 1 && v <= 10)).assertTrue();
      for (let i = 1; i < vals.length; i++) {
        expect(vals[i] <= vals[i - 1]).assertTrue();
      }
    });

    it('A2_新卡初始化_Robustness', 0, () => {
      for (const g of [1, 2, 3, 4]) {
        const info = fsrs.next(new MemoryState(0, 0), 0, g);
        expect(Number.isFinite(info.state.stability)).assertTrue();
        expect(Number.isFinite(info.state.difficulty)).assertTrue();
        expect(Number.isFinite(info.interval)).assertTrue();
      }
    });

    it('A3_老卡更新_Difficulty', 0, () => {
      const d0 = fsrs.initDifficulty(Rating.Good);
      const afterAgain = fsrs.nextDifficulty(d0, Rating.Again);
      const afterEasy = fsrs.nextDifficulty(d0, Rating.Easy);
      const afterGood = fsrs.nextDifficulty(d0, Rating.Good);
      expect(afterAgain > d0).assertTrue();
      expect(afterEasy < d0).assertTrue();
      expect(Math.abs(afterGood - d0) < 0.05).assertTrue();
    });

    it('A3_老卡更新_StabilityMonotonicity', 0, () => {
      let s = 5.0;
      let d = 5.0;
      for (const g of [Rating.Hard, Rating.Good, Rating.Easy]) {
        for (const elapsed of [1, 3, 7, 30, 100]) {
          const r = fsrs.retrievability(elapsed, s);
          const ns = fsrs.nextStability(d, s, r, g, elapsed);
          expect(ns >= s - 1e-9).assertTrue();
        }
      }
      for (const elapsed of [1, 3, 7, 30]) {
        const r = fsrs.retrievability(elapsed, s);
        const ns = fsrs.nextStability(d, s, r, Rating.Again, elapsed);
        expect(ns <= s + 1e-9).assertTrue();
      }
    });

    it('A4_数值健壮性_AllCombinations', 0, () => {
      const stabilities = [0.001, 0.1, 1, 10, 100, 1000, 36500];
      const difficulties = [1.0, 3.0, 5.0, 7.5, 10.0];
      const elapsedList = [0, 1, 2, 7, 30, 365, 3650];
      for (const s of stabilities) {
        for (const d of difficulties) {
          for (const el of elapsedList) {
            for (const g of [1, 2, 3, 4]) {
              const info = fsrs.next(new MemoryState(s, d), el, g);
              const S = info.state.stability, D = info.state.difficulty, I = info.interval;
              expect(Number.isFinite(S) && S > 0).assertTrue();
              expect(D >= 1 && D <= 10).assertTrue();
              expect(I >= 0).assertTrue();
            }
          }
        }
      }
    });

    // ============================================================
    // B 段：黄金向量测试
    // ============================================================

    it('B_GoldenVectors', 0, async () => {
      const filePath = context.filesDir + '/vectors.json';
      if (!fs.accessSync(filePath)) {
        console.error('B_GoldenVectors skipped: vectors.json not found in ' + context.filesDir);
        return;
      }

      const content = fs.readTextSync(filePath);
      const data = JSON.parse(content);
      let mismatch = 0;
      let checked = 0;
      const diffs: string[] = [];
      const newCardCoverage = new Set<string>();

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
        const okI = di < 5e-4;

        if (!okS || !okD || !okI) {
          mismatch++;
          if (diffs.length < 5) {
            diffs.push(`Mismatch at index ${checked}: S_diff=${ds.toExponential(2)}, D_diff=${dd.toExponential(2)}, I_diff=${di.toExponential(2)}`);
          }
        }
      }

      expect(mismatch).assertEqual(0);
      expect(newCardCoverage.size >= 4).assertTrue();
    });
  });
}
