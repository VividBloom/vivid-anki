# 黄金测试向量

## 为什么必须有这一步

`fsrs.selftest.ts` 里的 A 类断言（32 项）只能证明**实现自洽**：

- 恒等式成立（间隔与稳定性互为反函数）
- 单调性正确（难度随评分升降、稳定性成功不降失败不升）
- 数值不发散（980 组组合无 NaN / 越界）

但它**不能证明「与官方 FSRS-6 一致」**。如果我把某个权重的下标写错（比如 w[15] 用成 w[16]），
A 类断言很可能照样全绿。

**B 类断言就是用来抓这类错误的**：拿官方 `fsrs` crate 的输出逐组比对，要求对齐到 1e-4。

> 这是 PRD 8.5 定的验收红线。没有跑过 B 类断言，调度器不能进 M2。

## 生成步骤

### 1. 建一个临时 Rust 工程

```bash
cargo new fsrs_golden
cd fsrs_golden
```

`Cargo.toml` 加依赖：

```toml
[dependencies]
fsrs = { version = "4", default-features = false }
serde_json = "1"
```

### 2. 放入生成脚本

把同目录的 `generate_golden_vectors.rs` 覆盖到 `src/main.rs`。

### 3. 运行并导出

```bash
cargo run --release > vectors.json
```

### 4. 放回本目录，重跑自检

```bash
cp vectors.json <本目录>/
# 回到 fsrs/ 目录
python3 ets2js.py && node _selftest.mjs
```

B 段会自动加载并对齐，输出形如：

```
B. 黄金测试向量
  ✓ 黄金向量 1760 组全部对齐（1e-4）
```

## 覆盖组合

| 维度 | 取值 |
|---|---|
| 稳定性 S | 0.1, 1, 5, 10, 100, 1000 |
| 难度 D | 1, 3, 5, 7.5, 10 |
| 距上次复习 elapsed_days | 0, 1, 2, 3, 7, 14, 30, 90, 365 |
| 评分 rating | 1, 2, 3, 4 |
| 目标留存率 | 0.8, 0.85, 0.9, 0.95 |

外加**新卡分支**（state = None）4 × 4 = 16 组。

合计约 4300 组。文件较大（约 1-2 MB），但一次性生成、长期复用。

## 如果版本 API 对不上

`fsrs` crate v4 之后 API 有调整。若 `next_states` 签名与本脚本不一致，
按以下原则调整即可，核心不变：

1. **新卡传 `None`**（不是 `MemoryState::default()`）—— 二者在部分版本里行为不同
2. `by_rating(rating)` 取出对应评分的结果
3. 输出 `memory.stability` / `memory.difficulty` / `interval` 三个值

## 对齐失败怎么办

先定位是第一组就错，还是某类组合才错：

- **全部偏差很大** → 多半是遗忘曲线参数错了，先检查 `w[20]`（decay）与 `factor` 的推导
- **只有新卡错** → 检查 `init_stability` / `init_difficulty` 的公式与下标
- **只有 elapsed_days = 0 错** → 短期稳定性公式（`w[17]`-`w[19]`），FSRS-6 这块与 FSRS-5 不同
- **只有 Again 错** → 检查失败分支 `w[11]`-`w[14]`
- **只有 Hard / Easy 错** → 检查 `w[15]`（Hard 惩罚）与 `w[16]`（Easy 奖励）

最后一种最常见：这两个权重很容易互换，且互换后整体行为仍然"看起来正常"。
