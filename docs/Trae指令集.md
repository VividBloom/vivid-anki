# 瞄一眼 · Trae 可执行指令集

> 把 todo 清单翻译成可直接粘贴给 Trae 执行的指令。
> 共 1 条上下文注入 + 56 条任务指令，按 M1 → M7 顺序编排。

## 怎么用

## 编号体系（勿混用）

| 前缀                | 来源              | 用途                               |
| ----------------- | --------------- | -------------------------------- |
| `F01-F23`         | 最小文档 · MVP 需求清单 | 需求编号，带 Must / Should / Could 优先级 |
| `PRD#1-#17`       | PRD 第四章功能清单     | 另一套功能编号（含回归模式、回收站等后补项）           |
| `TC01-TC15`       | 最小文档 4.2 功能测试用例 | 验收用例                             |
| `R01-R08`         | 最小文档 4.4 回归清单   | 核心路径                             |
| `T0-xx / T1-xx …` | 本指令集            | 任务编号                             |

两套功能编号**互相独立**，引用时请带上前缀，避免「F13」被同时理解成统计与卡片管理。

## 目录

***

## STEP 0 · 上下文注入

先复制下面这段，让 Trae 建立项目认知。**每个新会话都要先执行一次。**

```
读取并记住以下文件，之后所有改动都必须遵守其中的约定：

1. /anki/README.md                —— 工程约定与目录结构
2. /anki/docs/db/V1__init.sql        —— 10 张数据表的字段定义与关键注释
3. /anki/scripts/check_deps.py    —— 分层依赖检查规则
4. /anki/entry/src/main/ets/domain/scheduler/FsrsScheduler.ets  —— 已实现的调度器接口

请回答三个问题确认你已理解：
  a) 五层架构的允许依赖方向是什么？举一个被禁止的例子。
  b) revlog.card_id 和 card.deck_id 为什么【不建】外键？
  c) UI 文案中被禁止出现的词有哪些？

回答完等待我的下一条指令，不要自行开始写代码。
```

> 若 Trae 答错 b) 或 c)，说明没读进去，重新粘贴一次。

### 【T0-08】check\_deps 挂 git pre-commit

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common

任务：把 scripts/check_deps.py 挂到 git pre-commit，使分层违规在提交前被拦截

涉及文件：
  · .git/hooks/pre-commit（新建，或 .husky/pre-commit）
  · scripts/check_deps.py（已存在，加 --strict 参数）

实现要求：
  在 pre-commit 中调用 python3 scripts/check_deps.py --strict
  非 0 退出码时阻断提交，并打印违规文件与依赖方向
  在 README 中写明安装方式（因为 .git/hooks 不随仓库分发，需提供安装脚本）
  提供 scripts/install_hooks.sh 一键安装

验收标准：
  ✓ 人为制造一处 ui → data 的跨层引用后，git commit 被阻断
  ✓ 修复后 commit 成功
  ✓ scripts/install_hooks.sh 可执行
```

## M1 · 调度核心与数据层

> T1-01/02/12/13/14/15/17/18 已完成，从 T1-03 继续。

### 【T1-03】接入黄金测试向量，跑通 B 段断言

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：把官方 fsrs crate 生成的黄金向量接入自检，验证自研 ArkTS 调度器与官方实现一致

涉及文件：
  · dev-tests/fsrs.selftest.ts（新增 B 段断言）
  · dev-tests/golden_vectors/vectors.json（需先由本机生成，见文末 D-01）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  在 selftest.ts 中新增 B 段：读取 vectors.json，对每组调用 FsrsScheduler.next()
  比对 nextIntervalDays 与官方值，容差 1e-4
  必须同时覆盖新卡分支（reps=0）与老卡分支，只测老卡会漏掉初始化错误
  失败时输出前 5 组差异最大的用例，含输入参数与期望/实际值

特别注意：
  ! 若 vectors.json 不存在，停止并提示我：需先本机执行 cargo run 生成
  ! 常见失败定位：全部偏差大查 w20；只有新卡错查 init；只有 Hard/Easy 错查 w15/w16 是否互换

验收标准：
  ✓ B 段约 4300 组全部通过，容差 1e-4
  ✓ A 段 32 项自洽断言仍全绿
  ✓ 新卡分支至少覆盖 4 个评分 × 不同 elapsed_days
```

### 【T1-04】补 Hypium 单元测试并纳入 CI

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：把 dev-tests 下的 Node 测试改写为鸿蒙 Hypium 测试，使其可在真机 / 模拟器运行

涉及文件：
  · entry/src/ohosTest/（Hypium 测试目录，新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  文件读取改用 @ohos.file.fs + context.filesDir，不得使用 fs / path / process 等 Node API
  测试内容 = A 段 32 项自洽断言 + B 段黄金向量
  在 README 中写明运行方式

验收标准：
  ✓ Hypium 测试可运行且全绿
  ✓ entry/src/main 下无任何 Node API 残留（grep 验证）
```

### 【T1-05】实现 CardDao

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：卡片表的数据访问层，后续一切功能的基础

涉及文件：
  · entry/src/main/ets/data/dao/CardDao.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  insert：插入新卡，state 默认 'new'，stability/difficulty 为 0（0 表示未初始化）
  queryDue(nowTs, limit)：查到期卡，必须命中 idx_card_due，带 deleted_at IS NULL AND suspended=0
  queryByDeck(deckId)：同样带 deleted_at IS NULL
  update：更新字段并同步 updated_at
  softDelete(cardId)：置 deleted_at，且 deleted_by_deck=0
  queryById / countByDeck
  所有返回用 Result<T> 包装，不向上抛异常

验收标准：
  ✓ queryDue 在 EXPLAIN QUERY PLAN 中显示使用 idx_card_due
  ✓ 软删除后该卡不再出现在 queryDue 与 queryByDeck 结果中
  ✓ python3 scripts/check_deps.py 通过
```

### 【T1-06】实现 DeckDao

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：牌组表数据访问层，含冗余字段维护

涉及文件：
  · entry/src/main/ets/data/dao/DeckDao.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  CRUD 全套；列表查询必须带 WHERE deleted_at IS NULL（deck 已加软删字段）
  card_count / due_count 由业务层在事务内维护，DAO 只负责写入
  提供 recalcCounts(deckId, nowTs) 供低频重算

验收标准：
  ✓ 已删除牌组不出现在 listAll() 结果中
  ✓ 删除牌组后 card_count 归零
  ✓ 依赖方向合规
```

### 【T1-07】实现 RevlogDao

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：复习日志访问层，FSRS 参数训练的数据来源

涉及文件：
  · entry/src/main/ets/data/dao/RevlogDao.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  insert：*_before 与 *_after 必须成对写入，缺一不可
  撤销走软删除：置 is_deleted=1，绝不 DELETE
  findLastValid(cardId)：按 reviewed_at 倒序查第一条 is_deleted=0 的记录（撤销回滚依据）
  queryForTraining()：导出全部有效日志用于参数训练

验收标准：
  ✓ 撤销后该条不再出现在 findLastValid 结果中，但物理行数不变
  ✓ before/after 字段完整性校验通过
```

### 【T1-08】实现 SessionDao

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：复习会话访问层，支撑中断恢复与多端接续

涉及文件：
  · entry/src/main/ets/data/dao/SessionDao.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  create / updateProgress / finish / abandon
  findActive()：查 state='active' 的最新会话，用于启动时的中断检测
  30 分钟无更新判定为 abandoned

验收标准：
  ✓ 启动检测能找到上次未完成会话
  ✓ 超时判定正确
```

### 【T1-09】实现 SettingsDao 与 DailyStatsDao

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：设置与每日统计访问层

涉及文件：
  · entry/src/main/ets/data/dao/SettingsDao.ets（新建）
  · entry/src/main/ets/data/dao/DailyStatsDao.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  SettingsDao：单行读写（表有 CHECK(id=1) 约束，不要插第二行）
  DailyStatsDao：按本地自然日 yyyy-MM-dd upsert，用 TimeUtil 取日期
  统计字段含 ai_generated/kept、resumed、undo、session_count 等新增埋点口径

验收标准：
  ✓ 连续写入同一天只产生一行
  ✓ 跨零点写入产生新行
  ✓ settings 插入第二行会失败（约束生效）
```

### 【T1-10】实现 AiDraft / Media / Backup / SyncMeta 四个 DAO

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：补齐剩余四张表的数据访问层

涉及文件：
  · entry/src/main/ets/data/dao/AiDraftDao.ets
  · entry/src/main/ets/data/dao/MediaDao.ets
  · entry/src/main/ets/data/dao/BackupDao.ets
  · entry/src/main/ets/data/dao/SyncMetaDao.ets

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  AiDraft：status 流转 draft → confirmed / discarded，含 quota_charged（失败不扣额度）
  Media：ref_count 增减，归零后可清理
  Backup：记录快照，含 pre_migration 类型
  SyncMeta：设备表，V1.0 仅本地使用，结构预留

验收标准：
  ✓ 四个 DAO 基本 CRUD 可用
  ✓ AiDraft 失败时 quota_charged=0
```

### 【T1-11】实现 MigrationManager 与升级前快照

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：保证「升级不丢数据」这条红线

涉及文件：
  · entry/src/main/ets/data/migration/MigrationManager.ets（新建）
  · entry/src/main/ets/data/db/DbHelper.ets（接入）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  backupPreMigration(store, fromVersion)：迁移前写快照，失败必须阻断迁移
  migrate(store, from, to)：按版本逐级迁移
  DbHelper.doInit 中已有 TODO 占位，替换为真实调用
  迁移前快照记入 backup 表，type='pre_migration'

验收标准：
  ✓ 从 v1 升级到 v2 后数据完整
  ✓ 备份失败时迁移被阻断，不带着风险升级
```

### 【T1-16】牌组列表查询补齐软删过滤

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：deck 表新增 deleted_at 后，所有列表查询必须过滤

涉及文件：
  · entry/src/main/ets/data/dao/DeckDao.ets（依赖 T1-06）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  全局搜索所有 SELECT ... FROM deck，逐个确认带 WHERE deleted_at IS NULL
  覆盖首页牌组选择、卡片页列表、统计页三处

验收标准：
  ✓ 已删除牌组在任何列表都不可见
  ✓ grep 验证无遗漏
```

### 【T1-19】替换首页占位为 P02「今天」骨架

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：把 pages/Index.ets 的占位内容替换为真实首页入口

涉及文件：
  · entry/src/main/ets/pages/Index.ets（改造）
  · entry/src/main/ets/ui/pages/TodayPage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  pages/Index.ets 保持为路由壳（main_pages.json 已指向它），渲染 TodayPage
  TodayPage 先只做数据层接线：读今日待复习数与预计耗时，不追求视觉
  若数据为空走空态（原型 P02c）
  底部三个 Tab 入口先留空壳

验收标准：
  ✓ 首屏能显示从数据库读出的真实数字
  ✓ 空库时进入空态而非白屏
  ✓ 依赖方向合规
```

## M2 · 复习主链路

### 【T2-01】实现 P03 复习页 UI

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：核心页面，整个产品的中心

涉及文件：
  · entry/src/main/ets/ui/pages/ReviewPage.ets（新建）
  · entry/src/main/ets/ui/components/RatingBar.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  全屏单卡，正面问题居中大字号
  点卡片翻面（或上滑手势），背面显示答案 + 四档评分
  四档按钮文案固定为：再来一次 / 有点难 / 记得 / 太简单，2×2 布局便于单手
  顶部细进度条，文字为「还剩 N 张」而非「已完成 x/y」
  深色模式适配

特别注意：
  ! 四档文案必须逐字照写，不得改成「忘记」「错误」等措辞

验收标准：
  ✓ 界面无任何禁用词（牌组 / 字段 / 模板 / 间隔 / 难度 / 错误率）
  ✓ 翻卡与评分可完整走一轮
```

### 【T2-02】接 FSRS，事务落盘

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：把复习页与调度器、数据库打通

涉及文件：
  · entry/src/main/ets/domain/review/ReviewService.ets（新建）
  · entry/src/main/ets/ui/pages/ReviewPage.ets（改造）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  评分时在一个事务内完成：写 revlog（before/after 成对）→ 调 FsrsScheduler.next() → 更新 card 的 S/D/due/reps/lapses/last_review → 更新 daily_stats
  新卡（reps=0）必须走 initStability/initDifficulty 分支，不得用 S=0 代入公式（会 NaN）
  评分即时落盘，不等会话结束

验收标准：
  ✓ 评分后杀进程重进，数据与进度都在
  ✓ 新卡首评间隔为正数（不为 NaN、不为 0）
```

### 【T2-03】手势与左右手切换

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：单手可用性

涉及文件：
  · entry/src/main/ets/ui/pages/ReviewPage.ets（改造）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  上滑翻面，左右滑 = 再来一次
  设置项支持左右手切换评分按钮位置

验收标准：
  ✓ 单手可完成一轮复习
  ✓ 左撇子模式按钮位置正确
```

### 【T2-04】性能验证：5000 张卡首卡渲染

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：确保大数据量不卡

涉及文件：
  · 验证为主，必要时加索引或分页

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  造 5000 张卡测试数据
  测量冷启动到首卡渲染耗时
  若 >300ms，检查 queryDue 是否命中索引、是否有全表 COUNT

验收标准：
  ✓ 5000 张卡库首卡渲染 ≤300ms
  ✓ EXPLAIN QUERY PLAN 确认走索引
```

### 【T2-05】实现 P04 结算页

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：复习完成的收尾页

涉及文件：
  · entry/src/main/ets/ui/pages/DonePage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  显示今日完成量、连续天数 +1、明日预告
  不展示错误率、不展示正确率百分比
  提供自然的收尾而非鼓励再刷

验收标准：
  ✓ 无错误率相关元素
  ✓ 连续天数正确 +1
```

### 【T2-06】实现复习中断恢复

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：中途退出不丢进度

涉及文件：
  · entry/src/main/ets/domain/session/ResumeService.ets（新建）
  · entry/src/main/ets/ui/pages/ReviewPage.ets（改造）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  启动时通过 SessionDao.findActive() 检测未完成会话
  提示「已完成 N 张，都保存好了」，可从第 N+1 张继续
  提供「今天先到这里」退路
  恢复后不重复计数

验收标准：
  ✓ 复习中途杀进程，重进提示正确且进度一致
  ✓ daily_stats 不重复累加
```

### 【T2-07】实现撤销评分

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：评分错了能反悔

涉及文件：
  · entry/src/main/ets/domain/review/UndoService.ets（新建）
  · entry/src/main/ets/ui/pages/ReviewPage.ets（改造）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  回滚 S/D/due/reps/lapses 到 revlog 中记录的 *_before 值
  对应 revlog 置 is_deleted=1（软删除，不物理删除，否则污染 FSRS 训练集）
  找上一条有效日志时用 is_deleted=0 倒序查，不要用 card.last_revlog_id 单指针（连撤两次会失效）
  UI 用 Snackbar 提示，含「重做」反向出口

验收标准：
  ✓ 连续撤销两次仍正确
  ✓ 撤销后 revlog 物理行数不变，is_deleted=1
```

### 【T2-08】实现 P02「今天」完整页

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：首页正式版

涉及文件：
  · entry/src/main/ets/ui/pages/TodayPage.ets（改造）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  主卡：还有 N 张 · 约 M 分钟 + 巨大开始按钮
  下方：连续天数、今日热力格、未来 7 天预测
  零复习态走绿色主卡「今天已全部完成」
  任何路径不显示逾期总数

验收标准：
  ✓ 无「逾期 N 张」这类表述
  ✓ 零复习态正确触发
```

### 【T2-09】最小闭环验证

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：M2 出口检查

涉及文件：
  · 验证

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  走一遍：建库 → 插 3 张假卡 → 复习页翻卡评分 → 杀进程重进 → 数据还在
  逐项打勾并记录耗时

验收标准：
  ✓ 杀进程后数据与进度完整保留
  ✓ 间隔计算为正数
```

## M3 · 引导与制卡链路

### 【T3-01】实现 P01 引导四屏

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：新用户前 30 秒的体验，决定留存

涉及文件：
  · entry/src/main/ets/ui/pages/OnboardPage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  屏1 选个起点：3 个精品牌组 + 「我自己有内容」
  屏2 丢进内容：拍照 / 粘贴 / 文档三入口
  屏3 定个时间：5 / 15 / 30 分钟三档，副文案「随时可以改」
  屏4 讲清原理：遗忘曲线示意 + 「今天只给你 12 张 —— 这不是少，是刚刚好」
  顶部四段进度条

验收标准：
  ✓ 全四屏无任何禁用词
  ✓ onboarding_step 记录进度
```

### 【T3-02】引导计时验收

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：确保引导不拖沓

涉及文件：
  · 验证 + 必要时简化

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  实测从点击图标到开始第一张复习的耗时
  目标 ≤120 秒
  只问「每天几分钟」一个问题，其余全给默认值

验收标准：
  ✓ ≤120 秒
  ✓ 无额外设置询问
```

### 【T3-03】引导断点续接

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：中途退出不用重来

涉及文件：
  · entry/src/main/ets/ui/pages/OnboardPage.ets（改造）
  · entry/src/main/ets/data/dao/SettingsDao.ets（依赖 T1-09）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  onboarding_step 写入 user_settings
  重进时回到对应屏

验收标准：
  ✓ 杀进程后回到第 N 屏
```

### 【T3-04】实现 P05 制卡页

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：制卡成本决定留存

涉及文件：
  · entry/src/main/ets/ui/pages/CreateCardPage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  单页输入：正面 / 背面两个框 + 图片 / 录音 / 拍照 / 公式四个入口
  不要求先建牌组，写完即可保存
  高级选项（Cloze、反向卡）收在「更多选项」，默认不暴露

验收标准：
  ✓ ≤3 次点击完成保存
  ✓ 无禁用词
```

### 【T3-05】多行文本自动拆分

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：批量制卡能力

涉及文件：
  · entry/src/main/ets/domain/card/CardParseService.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  粘贴多行文本时自动识别分隔符（换行 / Tab / 逗号 / 顿号）
  提示「帮你拆成 N 张？」并给预览

验收标准：
  ✓ 6 行文本 → 6 张卡
  ✓ 分隔符识别正确
```

### 【T3-06】实现 P06 AI 卡片预览页

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：AI 制卡的质量闸门

涉及文件：
  · entry/src/main/ets/ui/pages/AiPreviewPage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  顶部橙色警示条「请逐张确认后再入库」
  每张卡可勾选 / 编辑 / 删除
  底部「确认(N)」按钮
  未确认的草稿绝不写入 card 表

验收标准：
  ✓ 不点确认则 card 表无新增
  ✓ 可逐张编辑
```

### 【T3-07】接入 AI 与三态

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：AI 制卡及其失败处理

涉及文件：
  · entry/src/main/ets/domain/ai/AiService.ets（新建）
  · entry/src/main/ets/ui/pages/AiPreviewPage.ets（改造）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  生成中：转圈 + 分步进度 + 「通常需要 3-8 秒」+ 可取消
  失败：明确原因 + 「手动制卡」退路 + 声明不扣额度
  无网：说明哪些能用、哪些不能
  只做提取式生成，不编造事实

验收标准：
  ✓ 三个异常态都有出口，无死路
  ✓ 失败时 quota_charged=0
```

### 【T3-08】三种卡片类型

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：基础 / Cloze / 双向

涉及文件：
  · entry/src/main/ets/domain/card/CardTypeService.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  basic 基础正反面、cloze 填空、reverse 双向
  三种均可制卡与复习

验收标准：
  ✓ 三种类型渲染与评分均正确
```

### 【T3-09】媒体支持

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：图片与音频

涉及文件：
  · entry/src/main/ets/domain/card/MediaService.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  图片与音频可插入、展示、播放
  media.ref_count 正确增减
  评估 LaTeX：若决定支持，先评估包体积影响再告知我结论

验收标准：
  ✓ 图片音频可用
  ✓ ref_count 归零后可清理
```

## M4 · 管理与统计

### 【T4-01】实现 P07 卡片管理页

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：内容管理入口

涉及文件：
  · entry/src/main/ets/ui/pages/CardsPage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  扁平牌组列表（不支持嵌套）+ 搜索 + 右下角悬浮加号
  空态有明确出口；搜索无结果保留关键词并给「新建这张卡」

验收标准：
  ✓ 无嵌套结构
  ✓ 空态与无结果态正确
```

### 【T4-02】实现 P09 统计页

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：新手版统计，克制

涉及文件：
  · entry/src/main/ets/ui/pages/StatsPage.ets（新建）
  · entry/src/main/ets/domain/stats/StatsService.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  只放四项：连续天数（带火苗，唯一强调数字）、今日完成圈、未来 7 天预测柱、月度热力图
  不放假留存率曲线、不展示错误率
  数据从 daily_stats 冗余表读，秒开

验收标准：
  ✓ 无留存率曲线与错误率
  ✓ 首屏秒开
```

### 【T4-03】统计冗余与跨零点

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：连续天数正确性

涉及文件：
  · entry/src/main/ets/domain/stats/StatsService.ets（改造）
  · entry/src/main/ets/common/utils/TimeUtil.ets（检查）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  daily_stats 在评分事务内同步更新
  连续天数按本地自然日算，跨零点 +1 正确

验收标准：
  ✓ 23:50 复习与 00:10 复习，连续天数与日期归属均正确
```

### 【T4-04】实现 P10 回归模式

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：断卡回来不惩罚

涉及文件：
  · entry/src/main/ets/ui/pages/BackPage.ets（新建）
  · entry/src/main/ets/domain/scheduler/ReviewQueue.ets（复用）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  断卡 ≥3 天启动，文案「欢迎回来！先来 15 张热热身？」
  明确写「不催你，也不显示积压数字」
  分批天数由 returnPlan 动态计算，UI 文案不能写死「3 天」

验收标准：
  ✓ 不显示任何积压总数
  ✓ 1000 张积压时不出现单日 940 张的情况
```

### 【T4-05】实现每日提醒

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：温和的一次性提醒

涉及文件：
  · entry/src/main/ets/domain/reminder/ReminderService.ets（新建）
  · entry/src/main/ets/ui/pages/ReminderPage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  用 reminderAgentManager 发布闹钟类提醒（系统后台代理，App 未启动也能触发）
  已在 module.json5 声明 PUBLISH_AGENT_REMINDER（system_grant，安装即授予，无系统弹窗）
  文案为「今天的 N 张已就绪」，禁止「你有 N 张逾期」
  用户关闭后不再打扰

验收标准：
  ✓ 每日定时触发一次
  ✓ 文案无惩罚意味
  ✓ 未声明 NOTIFICATION_CONTROLLER（那是系统应用权限，审核会被质疑）
```

### 【T4-06】偏好设置与关于页

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：克制的设置

涉及文件：
  · entry/src/main/ets/ui/pages/SettingsPage.ets（新建）
  · entry/src/main/ets/ui/pages/AboutPage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  偏好设置只放 6 个开关，不要堆选项
  关于页写明「自研 FSRS-6 + BSD-3 参数，未使用 rslib」

验收标准：
  ✓ 设置项 ≤6 个
  ✓ 关于页协议说明准确
```

### 【T4-07】逐页补齐四态

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：每个页面的空 / 加载中 / 失败 / 无网

涉及文件：
  · 全部 UI 页面

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  对照最小文档的四态表逐页确认
  加载中优先用骨架屏（形状与真实内容对应）
  失败态必须有出口按钮

验收标准：
  ✓ 无空白页
  ✓ 每个失败页都有可点击的退路
```

### 【T4-08】实现回收站页面

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：「30 天可恢复」的产品层出口

涉及文件：
  · entry/src/main/ets/ui/pages/TrashPage.ets（新建）
  · entry/src/main/ets/domain/deck/DeckLifecycleService.ets（复用）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  列表展示 30 天内可恢复的牌组与卡片，按剩余天数分组
  天数文案为「还剩 N 天」，≤7 天用橙色提醒（不用红色）
  每条支持恢复与彻底删除
  说明条写明「到期清理后复习记录会保留」
  列表底部注明「恢复牌组不会捞回你单独删除的卡片」
  参考原型 P16 / P16b / P16c 三屏

验收标准：
  ✓ 删除牌组后能在回收站看到并恢复
  ✓ 恢复只捞 deleted_by_deck=1 的卡片
```

### 【T4-09】删除确认弹窗

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
已有：domain/deck/DeckLifecycleService.ets（softDeleteDeck / softDeleteCard）

任务：实现删除确认弹窗，承接回收站的入口

涉及文件：
  · entry/src/main/ets/ui/components/DeleteConfirmDialog.ets（新建）
  · entry/src/main/ets/ui/pages/CardsPage.ets 或 DeckDetailPage（接入）
  · entry/src/main/ets/ui/pages/CardEditPage.ets（接入删除项）

硬约束：
1. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
2. 删除一律软删除（置 deleted_at），30 天内可恢复。

实现要求：
  弹窗叠加在当前页之上，让用户看清正在删什么
  按钮文案为「移入回收站」而非「删除」
  删除牌组时明确写出影响的卡片数量，例如「牌组内的 860 张卡片会一起移入」
  弹窗内含一条绿色提示「复习记录不会丢失」
  确认后跳转或提示可前往回收站

验收标准：
  ✓ 文案无惩罚意味，不写「删除后无法恢复」
  ✓ 牌组删除时明确写出影响的卡片数量
  ✓ 提示「复习记录不会丢失」
```

## M5 · 导入导出与桌面卡片

### 【T5-01】实现 .apkg 导入

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：冷启动引流口

涉及文件：
  · entry/src/main/ets/domain/io/ImportService.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  自研解析：apkg = zip + SQLite + JSON，不依赖 rslib
  解析 collection.anki2 的 notes / cards / revlog 映射到本项目表结构
  事务内批量插入

验收标准：
  ✓ 导入成功率 ≥95%（用真实 apkg 测试）
```

### 【T5-02】导入分批

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：防止一次性淹没用户

涉及文件：
  · entry/src/main/ets/domain/io/ImportService.ets（改造）
  · entry/src/main/ets/domain/scheduler/ReviewQueue.ets（复用）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  导入后按每日新卡上限（默认 20 张）分批安排，用 deck.batch_offset 记录游标
  结果页明确提示已按每天 20 张分批安排

验收标准：
  ✓ 导入 1860 张后首页今日量仍 ≤20
```

### 【T5-03】导入三态

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：进度可见、失败可解释

涉及文件：
  · entry/src/main/ets/ui/pages/ImportPage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  导入中：分步进度可取消
  成功：显示导入数量与分批说明
  失败：说明具体原因（如缺少 collection 表）并声明原始文件没有被修改

验收标准：
  ✓ 三态齐全
  ✓ 失败页无死路
```

### 【T5-04】实现导出

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：数据可迁移是信任资产

涉及文件：
  · entry/src/main/ets/domain/io/ExportService.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  导出 .apkg 与 JSON 两种格式
  不限量、不收费、不加水印
  导出的 apkg 能被本 App 再次导入

验收标准：
  ✓ 导出再导入完整还原
  ✓ 无付费墙
```

### 【T5-05】自动本地备份

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：升级不丢数据

涉及文件：
  · entry/src/main/ets/data/migration/MigrationManager.ets（依赖 T1-11）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  每日快照，保留 7 份
  含 pre_migration 类型快照

验收标准：
  ✓ 保留 7 份，超出自动淘汰最旧
```

### 【T5-06】实现 P12 桌面服务卡片

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：鸿蒙差异化杀手锏

涉及文件：
  · entry/src/main/ets/ui/pages/（FormAbility 或卡片提供方，新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  2×2 卡片显示「今天还剩 N 张」+ 进度环 + 「继续复习」按钮
  点击直达复习页
  刷新延迟 ≤5 分钟

验收标准：
  ✓ 桌面可见且点击直达复习页
```

### 【T5-07】导出与备份页

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：用户可见的数据出口

涉及文件：
  · entry/src/main/ets/ui/pages/ExportPage.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  三种格式 + 自动备份开关
  写明导出永久免费、永不设限

验收标准：
  ✓ 文案准确
```

## M6 · 埋点与稳定性

### 【T6-01】接入 22 个埋点事件

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：数据驱动的前提

涉及文件：
  · entry/src/main/ets/common/utils/Analytics.ets（新建）

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  三层：激活漏斗 / 核心行为 / 留存流失，共 22 个事件
  事件名与 PRD 第十一章一致
  V1.0 未接入第三方统计 SDK，先本地记录并可在设置中导出

验收标准：
  ✓ 22 个事件均可触发与记录
```

### 【T6-02】校验 5 个分析口径

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：确保埋点能回答业务问题

涉及文件：
  · 验证

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  逐项核对 PRD 的 5 个分析口径能否用现有埋点算出
  缺失则补事件或补参数

验收标准：
  ✓ 5 个口径数值可解释
```

### 【T6-03】稳定性达标

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：崩溃率 ≤0.1%

涉及文件：
  · 验证 + 修复

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  内测期间收集崩溃
  重点排查：数据库并发、大图 OOM、后台恢复空指针

验收标准：
  ✓ 崩溃率 ≤0.1%
```

### 【T6-04】执行 R01-R08 八条核心路径

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：回归验证

涉及文件：
  · 验证

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  逐条跑 PRD 定义的 8 条核心路径
  R08 升级不丢数据必须实测（用旧版本数据升级）

验收标准：
  ✓ 8 条全通过
```

### 【T6-05】深色模式与字号缩放

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：无障碍

涉及文件：
  · 全部 UI 页面

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  深色模式无脏背景、无不可读文字
  字号缩放至最大无截断无错位

验收标准：
  ✓ 两种模式与最大字号下均可正常使用
```

### 【T6-06】多设备兼容

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：一次开发多端部署

涉及文件：
  · 布局文件

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  小屏 / 大屏 / 平板 / 折叠屏适配
  平板展开走双栏（左侧牌组导航 + 右侧内容），四档评分改一行四个

验收标准：
  ✓ 四种尺寸布局正常
```

## M7 · 上架

### 【T7-01】执行发布 Checklist

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：上架前自检

涉及文件：
  · 检查，部分条目需我确认

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  逐项执行最小文档第五章的 31 项 Checklist
  10 条鸿蒙特有项重点核对：AGC 包名一致、发布证书非调试证书、module.json5 权限声明一致、元服务单独验证、预置牌组内容自研说明

验收标准：
  ✓ 31 项全通过
```

### 【T7-02】准备上架物料

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：图标与截图

涉及文件：
  · 应用市场素材

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  图标多尺寸已在「正式图标_F1」目录备好
  5 张应用截图 + banner
  所有中文文案肉眼复核一遍（AI 生成中文有出错概率）

验收标准：
  ✓ 无错字
  ✓ banner 标题确认为「瞄一眼」而非「喵一眼」
```

### 【T7-03】预置牌组入库

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：冷启动内容

涉及文件：
  · 数据准备

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  3 个精品牌组入库，写入牌组版本号到 card.source_ref
  内容为自研，事实性内容已核对权威出处
  宁缺毋滥，不凑数

验收标准：
  ✓ 3 个牌组可正常复习
  ✓ 事实性内容无错误
```

### 【T7-04】资质与合规

```text
本项目：瞄一眼（鸿蒙版记忆卡片 App）。工作目录：entry/src/main/ets
架构（严格单向，反向/跨层一律拒绝）：ui → domain → data → common
现有可复用资产：entry/src/main/ets/domain/scheduler/FsrsScheduler.ets（FSRS-6 调度器，已验证）、
entry/src/main/ets/domain/scheduler/ReviewQueue.ets（队列+上限+回归分批，纯函数）、
entry/src/main/ets/domain/deck/DeckLifecycleService.ets（软删/恢复/清理）、
entry/src/main/ets/data/db/ 下的 DbHelper.ets 与 Schema.ets（10 表 10 索引，已建好）。
数据表定义见 MemoApp/docs/V1__init.sql（与 Schema.ets 逐字段一致，改一处要同步另一处）。

任务：备案与类目

涉及文件：
  · 审批，需我配合

硬约束（每次都必须遵守，违反即返工）：
1. 分层：ui 不得直接引用 data；data 不得引用 domain；common 不引用任何上层。
2. 外键：revlog.card_id 与 card.deck_id 都【不建】外键（有意为之 —— 删卡片要保留复习日志、
   删牌组要保留卡片）。任何建表 / ALTER 都不要加回去。
3. 软删除：删除一律置 deleted_at，30 天内可恢复；revlog 撤销用 is_deleted=1，绝不物理删除。
4. 事务：评分落盘、撤销、导入、删除牌组必须走 DbHelper.inTransaction。
5. UI 文案禁止出现：牌组、笔记类型、字段、模板、间隔、难度、leech、ease、逾期、错误率。
6. 改完必须跑：python3 scripts/check_deps.py（依赖方向）与相关回归测试。

实现要求：
  教育类目说明
  若 AI 走云端，需生成式 AI 备案（依赖 D-05 决策）
  软著与备案状态核对

验收标准：
  ✓ 与实现一致
```

## ⌨ 需本机执行的事项

以下 5 项 Trae 做不了，需要你在本地或走行政流程处理。

| 编号               | 事项                    | 为什么 Trae 做不了             | 何时               |
| ---------------- | --------------------- | ------------------------ | ---------------- |
| **T0-01 / D-02** | 软件著作权申请               | 行政审批，周期数周至数月             | 第 0 周立即（最不可压缩）   |
| **T0-02 / D-11** | 商标网第 9 / 42 类查询       | 需登录商标网                   | 第 0 周            |
| **T0-03 / D-11** | 应用市场同名查询              | 需登录应用市场后台                | 第 0 周            |
| **T0-04 / D-07** | 首批牌组场景选题              | 业务决策，决定冷启动抓手             | 第 0 周            |
| **T0-05**        | 编写 20 张样卡并计时          | 内容生产，需你亲自写               | 第 0 周（与开发并行）     |
| **T0-06 / D-03** | 确定正式包名并创建 AGC 应用      | 需 AGC 后台操作               | M1 建工程前          |
| **T0-07 / D-01** | 生成黄金测试向量 vectors.json | 需 Rust 工具链联网拉 fsrs crate | M2 开始前（阻塞 T1-03） |
| **T6-07 / D-08** | 隐私政策反馈邮箱与生效日期         | 必须是你能收信的真实邮箱             | M6 前             |
| **T7-05**        | 提交审核并跟踪               | 需应用市场后台操作                | M7               |

### D-01 的具体操作

```bash
cd /data/workspace/MemoApp/dev-tests/golden_vectors
cargo run --release > vectors.json
# 把 vectors.json 放回该目录，然后让 Trae 执行 T1-03
```

***

## 一句话原则

**按 M1 → M7 顺序执行，每条验收不通过就不往下走。**
错误会累积，越往后返工成本越高。
