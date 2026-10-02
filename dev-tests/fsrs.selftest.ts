/**
 * FSRS-6 调度器 —— 自检测试
 *
 * 运行：npx tsx fsrs.selftest.ts   或   node（编译后）
 * 也可直接把断言抄进鸿蒙的 Hypium 单元测试。
 *
 * 这些断言分两类：
 *   A 类（恒等式）：不依赖外部实现，能独立抓住绝大多数公式写错
 *   B 类（黄金向量）：需要先用 fsrs crate 生成 JSON，见 golden_vectors 目录说明
 */

import {
  FsrsScheduler, MemoryState, Rating,
  FSRS6_DEFAULT_PARAMS, S_MIN, DEFAULT_DESIRED_RETENTION
} from './FsrsScheduler';

let passed = 0;
let failed = 0;

function ok(cond: boolean, name: string, detail: string = ''): void {
  if (cond) {
    passed++;
    console.log('  ✓ ' + name);
  } else {
    failed++;
    console.log('  ✗ ' + name + (detail ? '  → ' + detail : ''));
  }
}

function near(a: number, b: number, eps: number = 1e-6): boolean {
  return Math.abs(a - b) <= eps;
}

function section(t: string): void {
  console.log('\n' + t);
}

const fsrs = new FsrsScheduler(FSRS6_DEFAULT_PARAMS);

// ============================================================
section('A1. 遗忘曲线恒等式');
// ============================================================

// 恒等式①：目标留存率 0.9 时，间隔 == 稳定性
for (const s of [0.1, 1, 5, 10, 100, 1000]) {
  const i = fsrs.nextInterval(s, 0.9);
  ok(near(i, s, Math.max(s * 1e-9, 1e-9)),
     'nextInterval(S=' + s + ', 0.9) === S',
     '实际 ' + i);
}

// 恒等式②：R(S, S) ≈ 0.9 —— 稳定性定义就是「R 降到 90% 所需天数」
for (const s of [1, 5, 50, 365]) {
  const r = fsrs.retrievability(s, s);
  ok(near(r, 0.9, 1e-9), 'retrievability(S=' + s + ', ' + s + ') === 0.9', '实际 ' + r);
}

// 恒等式③：R 随 t 单调递减
{
  let mono = true;
  let prev = 1.1;
  for (const t of [0, 1, 2, 5, 10, 30, 100]) {
    const r = fsrs.retrievability(t, 10);
    if (r > prev) { mono = false; break; }
    prev = r;
  }
  ok(mono, 'R(t) 关于 t 单调递减');
}

// 恒等式④：目标留存率越低，间隔越长
{
  let mono = true;
  let prev = -1;
  for (const dr of [0.99, 0.95, 0.9, 0.85, 0.8, 0.7]) {
    const i = fsrs.nextInterval(10, dr);
    if (i < prev) { mono = false; break; }
    prev = i;
  }
  ok(mono, 'interval 随目标留存率单调递减');
}

// ============================================================
section('A2. 新卡初始化分支（PRD 8.4 最容易算错的地方）');
// ============================================================

// 初始稳定性：随评分递增，且恒 > 0
{
  const vals = [1, 2, 3, 4].map((g) => fsrs.initStability(g));
  ok(vals.every((v) => v > 0), 'initStability 恒 > 0（S=0 会导致除零）',
     JSON.stringify(vals.map((v) => v.toFixed(4))));
  let inc = true;
  for (let i = 1; i < vals.length; i++) { if (vals[i] <= vals[i - 1]) { inc = false; } }
  ok(inc, 'initStability 随评分单调递增', JSON.stringify(vals));
  ok(near(vals[0], 0.212, 1e-9), 'S0(Again) === w0 === 0.212', String(vals[0]));
  ok(near(vals[3], 8.2956, 1e-9), 'S0(Easy) === w3 === 8.2956', String(vals[3]));
}

// 初始难度：随评分递减，且恒在 [1, 10]
{
  const vals = [1, 2, 3, 4].map((g) => fsrs.initDifficulty(g));
  ok(vals.every((v) => v >= 1 && v <= 10), 'initDifficulty 恒在 [1,10]',
     JSON.stringify(vals.map((v) => v.toFixed(4))));
  let dec = true;
  for (let i = 1; i < vals.length; i++) { if (vals[i] > vals[i - 1]) { dec = false; } }
  ok(dec, 'initDifficulty 随评分单调递减', JSON.stringify(vals.map((v) => v.toFixed(4))));
}

// 关键：新卡走 next 不能产生 NaN / Infinity
{
  let clean = true;
  const bad: string[] = [];
  for (const g of [1, 2, 3, 4]) {
    const info = fsrs.next(new MemoryState(0, 0), 0, g);
    if (!isFinite(info.state.stability) || !isFinite(info.state.difficulty) ||
        !isFinite(info.interval)) {
      clean = false;
      bad.push('rating=' + g + ' S=' + info.state.stability + ' D=' + info.state.difficulty +
               ' I=' + info.interval);
    }
  }
  ok(clean, '新卡 next() 不产生 NaN / Infinity', bad.join('; '));
}

// 新卡四个评分给出的首日间隔应递增
{
  const ivs = [1, 2, 3, 4].map((g) => fsrs.next(new MemoryState(0, 0), 0, g).interval);
  let inc = true;
  for (let i = 1; i < ivs.length; i++) { if (ivs[i] <= ivs[i - 1]) { inc = false; } }
  ok(inc, '新卡首日间隔随评分递增', JSON.stringify(ivs.map((v) => v.toFixed(2))));
}

// ============================================================
section('A3. 老卡更新分支');
// ============================================================

// 难度：Again 升高，Easy 降低，Good 基本不变
{
  const d0 = fsrs.initDifficulty(Rating.Good);
  const afterAgain = fsrs.nextDifficulty(d0, Rating.Again);
  const afterEasy = fsrs.nextDifficulty(d0, Rating.Easy);
  const afterGood = fsrs.nextDifficulty(d0, Rating.Good);
  ok(afterAgain > d0, '评 Again 后难度上升', d0.toFixed(4) + ' → ' + afterAgain.toFixed(4));
  ok(afterEasy < d0, '评 Easy 后难度下降', d0.toFixed(4) + ' → ' + afterEasy.toFixed(4));
  ok(Math.abs(afterGood - d0) < 0.05, '评 Good 后难度基本不变',
     d0.toFixed(4) + ' → ' + afterGood.toFixed(4));
}

// 难度恒在 [1,10]：连续 50 次 Again 不应越界
{
  let d = fsrs.initDifficulty(Rating.Good);
  for (let i = 0; i < 50; i++) { d = fsrs.nextDifficulty(d, Rating.Again); }
  ok(d <= 10.0001 && d >= 1, '连续 50 次 Again 后难度仍在 [1,10]', String(d));
  let d2 = fsrs.initDifficulty(Rating.Good);
  for (let i = 0; i < 50; i++) { d2 = fsrs.nextDifficulty(d2, Rating.Easy); }
  ok(d2 >= 0.9999 && d2 <= 10, '连续 50 次 Easy 后难度仍在 [1,10]', String(d2));
}

// 稳定性：成功只增不减，失败只减不增
{
  let s = 5.0;
  let d = 5.0;
  let okSuccess = true;
  for (const g of [Rating.Hard, Rating.Good, Rating.Easy]) {
    for (const elapsed of [1, 3, 7, 30, 100]) {
      const r = fsrs.retrievability(elapsed, s);
      const ns = fsrs.nextStability(d, s, r, g, elapsed);
      // 间隔极长时 R 极低，允许微小数值误差
      if (ns < s - 1e-9) { okSuccess = false; }
    }
  }
  ok(okSuccess, '成功回忆后稳定性不降低');

  let okFail = true;
  for (const elapsed of [1, 3, 7, 30]) {
    const r = fsrs.retrievability(elapsed, s);
    const ns = fsrs.nextStability(d, s, r, Rating.Again, elapsed);
    if (ns > s + 1e-9) { okFail = false; }
  }
  ok(okFail, '评 Again 后稳定性不升高');
}

// 间隔效应：在「快忘了」的时候复习，收益应大于刚复习就复习
{
  const s = 10.0, d = 5.0;
  const rEarly = fsrs.retrievability(1, s);     // 刚复习，R 高
  const rLate = fsrs.retrievability(15, s);     // 快忘了，R 低
  const gainEarly = fsrs.nextStability(d, s, rEarly, Rating.Good, 1);
  const gainLate = fsrs.nextStability(d, s, rLate, Rating.Good, 15);
  ok(gainLate > gainEarly,
     '间隔效应：R 更低时复习，稳定性增益更大',
     'R=' + rEarly.toFixed(3) + ' → ' + gainEarly.toFixed(3) +
     ' vs R=' + rLate.toFixed(3) + ' → ' + gainLate.toFixed(3));
}

// ============================================================
section('A4. 数值健壮性（线上最容易崩的地方）');
// ============================================================

// 遍历全组合，确保永不出现 NaN / 负数 / Infinity
{
  const bad: string[] = [];
  let count = 0;
  const stabilities = [0.001, 0.1, 1, 10, 100, 1000, 36500];
  const difficulties = [1.0, 3.0, 5.0, 7.5, 10.0];
  const elapsedList = [0, 1, 2, 7, 30, 365, 3650];
  for (const s of stabilities) {
    for (const d of difficulties) {
      for (const el of elapsedList) {
        for (const g of [1, 2, 3, 4]) {
          count++;
          const info = fsrs.next(new MemoryState(s, d), el, g);
          const S = info.state.stability, D = info.state.difficulty, I = info.interval;
          if (!isFinite(S) || !isFinite(D) || !isFinite(I) || S <= 0 || D < 1 || D > 10 || I < 0) {
            if (bad.length < 5) {
              bad.push('s=' + s + ' d=' + d + ' el=' + el + ' g=' + g +
                       ' → S=' + S + ' D=' + D + ' I=' + I);
            }
          }
        }
      }
    }
  }
  ok(bad.length === 0, '全组合 ' + count + ' 例无 NaN / 越界', bad.join('; '));
}

// 极端目标留存率不发散
{
  const i1 = fsrs.nextInterval(10, 0.01);
  const i2 = fsrs.nextInterval(10, 0.99);
  ok(isFinite(i1) && isFinite(i2) && i1 > i2,
     '目标留存率取到边界 0.01 / 0.99 仍收敛',
     'I(0.01)=' + i1.toFixed(1) + ' I(0.99)=' + i2.toFixed(3));
}

// 参数个数校验
{
  let threw = false;
  try { new FsrsScheduler([1, 2, 3]); } catch (e) { threw = true; }
  ok(threw, '参数个数不为 21 时抛错');
}

// 非法评分抛错
{
  let threw = false;
  try { fsrs.next(new MemoryState(5, 5), 1, 9); } catch (e) { threw = true; }
  ok(threw, '评分越界时抛错');
}

// ============================================================
section('B. 黄金测试向量（需先生成 JSON，见 golden_vectors/README）');
// ============================================================
{
  // ArkTS / Hypium 环境下请改用 @ohos.file.fs 与应用沙箱路径
  const fs = await import('fs');
  const path = await import('path');
  const p = path.join(process.cwd(), 'golden_vectors', 'vectors.json');
  
  if (!fs.existsSync(p) || fs.statSync(p).size === 0) {
    console.error('\n【停止执行】: 未找到有效的 vectors.json。需先本机执行 cargo run 生成');
    console.error('请到 dev-tests/golden_vectors 目录下执行: cargo run --release > vectors.json\n');
    process.exit(1);
  }

  const data = JSON.parse(fs.readFileSync(p, 'utf-8'));
  let mismatch = 0;
  let checked = 0;
  
  // 用于记录偏差最大的前 5 组
  const diffs: Array<{diff: number, desc: string}> = [];

  // 记录新卡分支的覆盖情况
  const newCardCoverage = new Set<string>();

  for (const v of data.vectors) {
    checked++;
    const state = v.is_new
      ? new MemoryState(0, 0)
      : new MemoryState(v.stability, v.difficulty);
    const info = fsrs.next(state, v.elapsed_days, v.rating, v.desired_retention);
    const ds = Math.abs(info.state.stability - v.expected_stability);
    const dd = Math.abs(info.state.difficulty - v.expected_difficulty);
    const di = Math.abs(info.interval - v.expected_interval);
    
    // 收集新卡分支覆盖率
    if (v.is_new) {
      newCardCoverage.add(`${v.rating}_${v.elapsed_days}`);
    }

    const maxDiff = Math.max(ds, dd, di);

    // PRD 要求对齐到小数点后 4 位
    if (maxDiff > 1e-4) {
      mismatch++;
      diffs.push({
        diff: maxDiff,
        desc: `组 ${checked} [is_new=${v.is_new}, rating=${v.rating}, elapsed=${v.elapsed_days}, S=${v.stability}, D=${v.difficulty}]:\n` +
              `  实际: S=${info.state.stability.toFixed(6)}, D=${info.state.difficulty.toFixed(6)}, I=${info.interval.toFixed(6)}\n` +
              `  期望: S=${v.expected_stability.toFixed(6)}, D=${v.expected_difficulty.toFixed(6)}, I=${v.expected_interval.toFixed(6)}`
      });
    }
  }

  if (mismatch > 0) {
    // 失败时输出前 5 组差异最大的用例
    diffs.sort((a, b) => b.diff - a.diff);
    const top5 = diffs.slice(0, 5).map(x => x.desc).join('\n\n');
    ok(false, `黄金向量比对失败，共 ${mismatch} 组未对齐`, `差异最大的前5组:\n${top5}\n\n常见失败定位：全部偏差大查 w20；只有新卡错查 init；只有 Hard/Easy 错查 w15/w16 是否互换`);
  } else {
    ok(true, `黄金向量 ${checked} 组全部对齐（1e-4）`);
  }
  
  ok(newCardCoverage.size >= 4, `新卡分支至少覆盖 4 个评分 × 不同 elapsed_days (实际覆盖 ${newCardCoverage.size} 种情况)`);
}

// ============================================================
console.log('\n' + '='.repeat(52));
console.log('通过 ' + passed + ' 项，失败 ' + failed + ' 项');
console.log('='.repeat(52));
if (failed > 0) {
  process.exit(1);
}
