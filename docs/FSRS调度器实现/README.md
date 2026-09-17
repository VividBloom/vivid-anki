# FSRS-6 调度器（ArkTS 自研实现）

M1 的核心交付物。已通过 32 项自洽断言，**尚未跑黄金测试向量**。

## 文件

| 文件 | 说明 |
|---|---|
| `FsrsScheduler.ets` | **交付代码**。纯 ArkTS，约 300 行，可直接放进鸿蒙工程 |
| `fsrs.selftest.ts` | 自检测试。A 类断言 32 项（自洽），B 类断言（对齐官方）待补 |
| `golden_vectors/` | 黄金向量生成脚本（Rust）+ 说明 |
| `ets2js.py` | 把 .ets 转成 Node 可跑的 ESM，用于本地验证 |
| `_FsrsScheduler.mjs` / `_selftest.mjs` | 转译产物，自动化测试生成，勿手改 |

## 本地验证

```bash
python3 ets2js.py        # .ets -> .mjs
node _selftest.mjs       # 跑断言
```

## 用法示例

```typescript
import { FsrsScheduler, MemoryState, Rating } from './FsrsScheduler';

const fsrs = new FsrsScheduler();   // 默认 FSRS-6 参数

// 新卡首次评分 —— 传空的 MemoryState，内部自动走 init 分支
const first = fsrs.next(new MemoryState(), 0, Rating.Good, 0.9);
// first.state.stability / difficulty  -> 写回 card 表
// first.interval                       -> 换算成 due

// 老卡复习
const later = fsrs.next(first.state, 5, Rating.Good, 0.9);
```

## 与 card 表的对应

| Scheduler 字段 | card 列 | 备注 |
|---|---|---|
| `MemoryState.stability` | `stability` | 0 表示新卡未初始化 |
| `MemoryState.difficulty` | `difficulty` | 0 表示新卡未初始化 |
| `SchedulingInfo.interval` | 换算后写入 `due` | `nextIntervalDays()` 已做取整与 <1 天归零 |
| `SchedulingInfo.retrievability` | 不入库 | 仅埋点与调试用 |

## 三条必须写进 CI 的断言

```typescript
// ① 间隔与稳定性互为反函数
assert(Math.abs(fsrs.nextInterval(s, 0.9) - s) < 1e-9);

// ② 稳定性的定义：R 衰减到 90% 所需天数
assert(Math.abs(fsrs.retrievability(s, s) - 0.9) < 1e-9);

// ③ 新卡绝不产生 NaN（S=0 代入老卡公式会除零）
const info = fsrs.next(new MemoryState(), 0, Rating.Again);
assert(isFinite(info.state.stability) && isFinite(info.interval));
```

## 状态

- [x] 新卡初始化分支（PRD 8.4 最容易算错的地方）
- [x] 恒等式与单调性断言
- [x] 980 组组合无 NaN / 越界
- [ ] **黄金测试向量对齐（阻塞 M2，见 golden_vectors/README.md）**
