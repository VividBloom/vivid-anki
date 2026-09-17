# 瞄一眼 · 工程骨架

配套 PRD V1.1 与《个人开发者最小文档》。**目标是让你今天就能 `git init` 写第一行业务代码。**

## 一、五层架构

```
ui        →  domain  →  data  →  common
                    ↘ scheduler ↗
```

| 层 | 目录 | 职责 | 允许依赖 |
|---|---|---|---|
| 公共 / 工具 | `common/` | 日志、时间、结果类型、错误码、常量 | **无**（最底层） |
| 数据层 | `data/` | RdbStore 封装、建表、DAO、迁移 | common |
| 调度层 | `domain/scheduler/` | FSRS-6 调度器、复习队列（**纯函数**） | common |
| 业务层 | `domain/{card,session,stats,...}/` | 制卡、AI 草稿、导入导出、会话、统计 | 调度层 + 数据层 |
| UI 层 | `ui/` | 页面与组件，不写业务逻辑 | 业务层 |

**common 是横切工具层**（日志 / 时间 / 结果类型），任何层都可以用——这是刻意开放的。
**但 ui 不得绕过 domain 直接取 data**。

```bash
python3 scripts/check_deps.py            # 检查
python3 scripts/check_deps.py --strict   # 有问题退出码非 0
```

建议挂 git pre-commit：
```bash
echo 'python3 scripts/check_deps.py --strict' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

脚本已验证能抓到三类违规：反向依赖、跨层依赖（ui→data）、循环依赖。

## 二、数据库

| 文件 | 说明 |
|---|---|
| `docs/V1__init.sql` | **完整建表 SQL**（给人看 / 给评审看，含注释） |
| `data/db/Schema.ets` | **同一份 SQL 的代码形态**（按表拆成数组，便于逐条执行）<br>⚠️ 两份需同步，改一处要改另一处 |
| `data/db/DbHelper.ets` | 单例、建表、版本检查、迁移钩子、事务封装 |

**共 10 张表**（PRD 6.2 - 6.11）：

```
deck  card  revlog  session  ai_draft  media  backup  sync_meta
user_settings  daily_stats
```

> 注：对外文档里曾写作「11 张」，实际为 10 张，已更正。

**索引（PRD 6.12）**已全部建好，关键三个：
- `idx_card_due` —— 复习队列构建，每次进首页和答完一张都会查
- `idx_revlog_card` —— 撤销定位
- `idx_session_state` —— 启动时的中断检测

## 三、已实现的代码

> ⚠️ **测试脚本位置已变更**：`FsrsScheduler.test.ets` 原放在 `domain/scheduler/` 下，
> 但它依赖 `fs` / `path` / `process` 与顶层 await，在 ArkTS 中不存在，会导致工程编译失败。
> 现已移至 `dev-tests/fsrs.selftest.ts`（不参与 App 编译），详见该目录 README。

| 文件 | 状态 |
|---|---|
| `domain/scheduler/FsrsScheduler.ets` | ✅ 完整实现，32 项断言全绿 |
| `domain/scheduler/ReviewQueue.ets` | ✅ 队列构建 + 每日上限 + 回归分批（纯函数）<br>⚠️ returnPlan(minDays) 天数动态计算，UI 文案不能写死「3 天」 |
| `domain/deck/DeckLifecycleService.ets` | ✅ 牌组/卡片删除、恢复、到期清理 |
| `domain/maintenance/StartupTasks.ets` | ✅ 启动期维护任务（回收站清理） |
| `entryability/EntryAbility.ets` | ✅ 入口，onCreate 调 StartupTasks |
| `pages/Index.ets` | ✅ 路由壳 + 数据库/调度器冒烟（M2 替换为 P02） |
| `common/utils/{LogUtil,TimeUtil,Result}.ets` | ✅ 可用 |
| `common/constants/ErrorCode.ets` | ✅ 对齐最小文档 3.4 |
| `data/db/{Schema,DbHelper}.ets` | ✅ 可用（迁移逻辑留 TODO） |
| `data/dao/` | ⬜ 待写 |
| `domain/{card,session,stats}/` | ⬜ 待写 |
| `ui/pages/` | ⬜ 待写 |

## 四、开工顺序（建议）

**第一周目标：跑通最小闭环，别做完整架构。**

1. `data/dao/CardDao.ets` —— 只写 `insert` 和 `queryDue` 两个方法
2. `ui/pages/ReviewPage.ets` —— 硬编码 3 张假卡，能翻卡、能评分
3. 接上 `FsrsScheduler` —— 评分后真算间隔，写回数据库
4. **杀进程重进，数据还在** —— 这一步过了，FSRS 才有意义

跑通后再补：DeckDao → 首页 → SessionDao + 中断恢复 → 制卡页。

## 五、还没做，且开工前必须知道的

| 项 | 说明 |
|---|---|
| **黄金测试向量** | 阻塞项。见 `docs/黄金测试向量说明.md`，不跑完别进 M2 |
| **迁移逻辑** | `DbHelper` 里留了 TODO。发布结构变更版本前必须实现 `pre_migration` 备份 |
| **权限** | 已声明 INTERNET / CAMERA / MICROPHONE / PUBLISH_AGENT_REMINDER。<br>通知已定方案：`reminderAgentManager` + PUBLISH_AGENT_REMINDER（system_grant，无系统弹窗），详见第七节 |
| **选图** | 建议用系统 Picker，就无需申请 READ_IMAGEVIDEO 权限 |
| **包名** | `com.example.memo` 是占位，**上架前必须改成你自己的**，且与 AGC 创建的应用一致 |

## 六、目录树

```
MemoApp/
├── docs/
│   ├── V1__init.sql              建表 SQL（含注释）
│   ├── generate_golden_vectors.rs
│   └── 黄金测试向量说明.md
├── scripts/
│   └── check_deps.py             依赖方向检查
└── entry/src/main/
    ├── module.json5              权限声明
    └── ets/
        ├── common/
        │   ├── constants/ErrorCode.ets
        │   └── utils/{LogUtil,TimeUtil,Result}.ets
        ├── data/
        │   ├── db/{Schema,DbHelper}.ets
        │   ├── dao/              ⬜ 待写
        │   └── migration/        ⬜ 待写
        ├── domain/
        │   ├── scheduler/{FsrsScheduler,ReviewQueue}.ets
        │   ├── deck/DeckLifecycleService.ets
        │   ├── maintenance/StartupTasks.ets
        │   └── {card,session,stats}/   ⬜ 待写
        ├── entryability/EntryAbility.ets
        └── pages/Index.ets
        └── ui/
            ├── pages/            ⬜ 待写
            └── components/       ⬜ 待写
```

## 七、两项重要设计约定（改动前请先读）

### revlog 不建外键
`revlog.card_id` 刻意**不**加 `REFERENCES card(id)`。原因是本工程开启了
`PRAGMA foreign_keys = ON`：
- 加 `ON DELETE CASCADE` → 硬删卡片会连带删光复习日志（日志是 FSRS 训练集，丢失不可逆）
- 只加 `REFERENCES`（默认 NO ACTION）→ 删卡片会被数据库阻止，30 天清理机制失效

故改为无外键，硬删卡片后 revlog 完整保留，`card_id` 成为悬空值。
训练只需 `*_before` / `*_after` 数值字段，悬空不影响参数优化。

### 通知用后台代理提醒
已在 `module.json5` 声明 `ohos.permission.PUBLISH_AGENT_REMINDER`（system_grant）。
每日定时提醒请用 `reminderAgentManager` 的闹钟类提醒，由系统后台代理计时，
App 未启动也能准时触发。

**不要**声明 `NOTIFICATION_CONTROLLER` / `NOTIFICATION_AGENT` ——
那是系统应用权限，普通应用声明会在应用市场审核时被质疑。

### 删除用软删除，且牌组与卡片联动（N-01 已修）
`card.deck_id` **没有**外键。删牌组会连带删卡片的问题已修，规则如下：

| 操作 | 行为 |
|---|---|
| 删除牌组 | 牌组与名下卡片一并置 `deleted_at`，30 天内可恢复 |
| 恢复牌组 | 只恢复 `deleted_by_deck=1` 且 `deleted_at` 与牌组一致的卡片 |
| 到期清理 | 先硬删过期卡片，再硬删「名下无任何卡片」的过期牌组 |

实现见 `domain/deck/DeckLifecycleService.ets`，回归测试：

```bash
python3 dev-tests/test_deck_lifecycle.py
```

**新增字段后必须注意**：`deck` 表已加 `deleted_at`，
所有牌组列表查询都要带 `WHERE deleted_at IS NULL`，否则已删除牌组会重现。

**回收站原型已完成**（P16 列表 / P16b 空态 / P16c 删除确认，见 prototype）。
数据层与产品层均已就绪，剩下的就是把 TrashPage 真正实现出来（todo T4-08）。

### 时间计算按自然日，不用固定 24 小时
`TimeUtil.startOfTomorrow` 用日历运算（`setDate +1`）而非 `+86400000`。
夏令时切换日一天只有 23 或 25 小时，固定加 24 小时会得到错误的次日零点，
与 `elapsedDays` 的自然日语义打架。中国大陆无夏令时，但面向海外时这是真实 bug。

### 稳定性下限有两个，不要合并
`S_MIN_INIT = 0.1`（初始稳定性下限，官方值）与 `S_MIN = 0.01`（通用下限，官方值）
语义不同：前者保证新卡首次评分后至少撑住半天，后者防止更新后退化到 0。
