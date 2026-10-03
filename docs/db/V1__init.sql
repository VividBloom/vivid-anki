-- ============================================================
-- 瞄一眼 · 数据库初始结构 V1
-- 目标：HarmonyOS relationalStore（SQLite 兼容）
--
-- 对应 PRD 第六章 6.2 - 6.11（共 10 张表）与 6.12（索引约束）
--
-- 约定：
--   1. 所有时间戳为 INTEGER 毫秒（UTC），展示时按本地时区转换
--   2. 布尔统一用 INTEGER 0/1，不用 SQLite 的 BOOLEAN
--   3. 所有表带 created_at / updated_at，便于排查与增量同步
--   4. 软删除统一用 deleted_at（NULL 表示未删除）
-- ============================================================

PRAGMA foreign_keys = ON;

-- 版本号：与 user_settings.schema_version 保持一致，迁移时递增
PRAGMA user_version = 1;

-- ============================================================
-- 6.4 deck（牌组）
-- 刻意不支持嵌套：无 parent_id，扁平列表 + 搜索
-- ============================================================
CREATE TABLE IF NOT EXISTS deck (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT    NOT NULL,
    cover        TEXT,                                   -- 封面图资源路径
    is_preset    INTEGER NOT NULL DEFAULT 0,             -- 1=官方预置牌组
    new_limit    INTEGER NOT NULL DEFAULT 20,            -- 每日新卡上限
    sort_order   INTEGER NOT NULL DEFAULT 0,
    -- 冗余字段：由业务层事务维护，列表页禁止 COUNT
    card_count   INTEGER NOT NULL DEFAULT 0,
    due_count    INTEGER NOT NULL DEFAULT 0,
    suspended    INTEGER NOT NULL DEFAULT 0,             -- 1=暂停，不进复习队列
    batch_offset INTEGER NOT NULL DEFAULT 0,             -- 大批量导入后的分批游标
    deleted_at    INTEGER,                               -- 软删除，与 card 一致，30 天内可恢复
    last_studied_at INTEGER,
    created_at   INTEGER NOT NULL,
    updated_at   INTEGER NOT NULL
);

-- ============================================================
-- 6.2 card（卡片）
-- 刻意不做 Note 层：一张卡 = 一个完整问答对
-- ============================================================
CREATE TABLE IF NOT EXISTS card (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    -- 刻意不建外键：删除牌组时必须先软删卡片，由清理任务统一硬删。
    -- 若保留 ON DELETE CASCADE，删牌组会绕过软删除直接物理删除卡片，
    -- PRD 6.2 承诺的「删除后 30 天可恢复」即彻底失效（审查报告 N-01）。
    deck_id       INTEGER NOT NULL,
    card_type     TEXT    NOT NULL DEFAULT 'basic',      -- basic / cloze / reverse
    front         TEXT    NOT NULL,
    back          TEXT    NOT NULL,
    extra         TEXT,                                  -- 补充说明，翻卡后可选展示
    media_refs    TEXT,                                  -- JSON 数组，关联 media.id
    source        TEXT    NOT NULL DEFAULT 'manual',     -- manual / ai / import / preset
    source_ref    TEXT,                                  -- 草稿ID / 导入批次 / 牌组版本号
    state         TEXT    NOT NULL DEFAULT 'new',        -- new / learning / review / suspended
    -- FSRS 状态。0 表示「尚未初始化」，仅存在于 new 状态
    stability     REAL    NOT NULL DEFAULT 0,
    difficulty    REAL    NOT NULL DEFAULT 0,
    due           INTEGER NOT NULL DEFAULT 0,            -- 下次到期时间戳（毫秒）
    last_review   INTEGER,
    reps          INTEGER NOT NULL DEFAULT 0,
    lapses        INTEGER NOT NULL DEFAULT 0,            -- 仅内部记录，不向用户展示
    -- 撤销锚点：指向最近一条 is_deleted=0 的 revlog
    last_revlog_id INTEGER,
    suspended     INTEGER NOT NULL DEFAULT 0,            -- 1=暂停这张卡
    deleted_at    INTEGER,                               -- 软删除，30 天内可恢复
    deleted_by_deck INTEGER NOT NULL DEFAULT 0,          -- 1=随牌组一起删除（恢复牌组时才恢复）
    created_at    INTEGER NOT NULL,
    updated_at    INTEGER NOT NULL
);

-- ============================================================
-- 6.3 revlog（复习日志）
-- 只增不改。撤销时置 is_deleted=1，绝不物理删除
-- —— 它是 FSRS 参数训练集，物理删除会污染数据分布
-- ============================================================
CREATE TABLE IF NOT EXISTS revlog (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    -- 刻意不建外键：硬删 card 时必须保留本行。
    -- 若保留 REFERENCES 且开启 PRAGMA foreign_keys，默认行为 NO ACTION 会「阻止删除卡片」；
    -- 若写 ON DELETE CASCADE 则会「连带删掉复习日志」——两者都不可接受。
    -- 训练所需数据已在本行 *_before / *_after 中冗余保存，card_id 悬空不影响 FSRS 参数训练。
    card_id           INTEGER NOT NULL,
    rating            INTEGER NOT NULL,                  -- 1再来一次 2有点难 3记得 4太简单
    elapsed_days      INTEGER NOT NULL,
    session_id        TEXT,
    device_id         TEXT,
    -- 撤销回滚依据：*_before 与 *_after 成对记录
    stability_before  REAL    NOT NULL,
    difficulty_before REAL    NOT NULL,
    interval_before   REAL,
    reps_before       INTEGER NOT NULL,
    lapses_before     INTEGER NOT NULL,
    stability_after   REAL    NOT NULL,
    difficulty_after  REAL    NOT NULL,
    interval_after    REAL    NOT NULL,
    duration_ms       INTEGER,
    reviewed_at       INTEGER NOT NULL,
    is_deleted        INTEGER NOT NULL DEFAULT 0,        -- 软删除，不物理删除
    created_at        INTEGER NOT NULL
);

-- ============================================================
-- 6.7 session（复习会话）
-- 支撑中断恢复（P03b）与多端接续（P13）
-- ============================================================
CREATE TABLE IF NOT EXISTS session (
    session_id    TEXT    PRIMARY KEY,                   -- UUID
    deck_id       INTEGER REFERENCES deck(id) ON DELETE SET NULL,  -- NULL=跨牌组混合
    state         TEXT    NOT NULL DEFAULT 'active',     -- active / finished / abandoned
    total_planned INTEGER NOT NULL DEFAULT 0,
    completed     INTEGER NOT NULL DEFAULT 0,
    last_card_id  INTEGER,
    last_position INTEGER NOT NULL DEFAULT 0,
    device_id     TEXT    NOT NULL,
    started_at    INTEGER NOT NULL,
    ended_at      INTEGER,
    updated_at    INTEGER NOT NULL
);

-- ============================================================
-- 6.8 ai_draft（AI 草稿）
-- 数据层落实「不确认不入库」
-- ============================================================
CREATE TABLE IF NOT EXISTS ai_draft (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    source_text     TEXT    NOT NULL,                    -- 失败重试与「不丢输入」的依据
    source_type     TEXT    NOT NULL,                    -- paste / photo / document
    cards_json      TEXT,                                -- 生成结果，每项含 front/back/selected
    status          TEXT    NOT NULL DEFAULT 'pending',  -- pending/confirmed/failed/discarded
    generated_count INTEGER NOT NULL DEFAULT 0,
    kept_count      INTEGER NOT NULL DEFAULT 0,          -- kept/generated 是核心质量指标
    error_code      TEXT,
    quota_charged   INTEGER NOT NULL DEFAULT 0,          -- 失败必须为 0
    created_at      INTEGER NOT NULL,
    confirmed_at    INTEGER
);

-- ============================================================
-- 6.9 media（媒体资源）
-- 独立成表以支持引用计数：ref_count 归零后可安全清理
-- ============================================================
CREATE TABLE IF NOT EXISTS media (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    type       TEXT    NOT NULL,                         -- image / audio
    local_path TEXT    NOT NULL,
    file_size  INTEGER NOT NULL DEFAULT 0,
    checksum   TEXT,                                     -- 导入去重
    ref_count  INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
);

-- ============================================================
-- 6.10 backup（本地备份）
-- 「升级不丢数据」红线的兜底：升级前强制写 pre_migration 快照
-- ============================================================
CREATE TABLE IF NOT EXISTS backup (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path      TEXT    NOT NULL,
    file_size      INTEGER NOT NULL DEFAULT 0,
    backup_type    TEXT    NOT NULL,                     -- auto / manual / pre_migration
    schema_version INTEGER NOT NULL,
    card_count     INTEGER NOT NULL DEFAULT 0,
    created_at     INTEGER NOT NULL
);

-- ============================================================
-- 6.11 sync_meta（设备与同步）
-- V1.0 不使用云同步，仅本地记录本设备信息并预留多端能力
-- ============================================================
CREATE TABLE IF NOT EXISTS sync_meta (
    device_id      TEXT    PRIMARY KEY,
    device_name    TEXT,                                 -- 接续弹窗展示用
    device_type    TEXT,                                 -- phone / tablet / foldable
    last_active_at INTEGER NOT NULL,
    last_session_id TEXT,
    sync_cursor    TEXT,
    schema_version INTEGER NOT NULL DEFAULT 1,
    created_at     INTEGER NOT NULL,
    updated_at     INTEGER NOT NULL
);

-- ============================================================
-- 6.5 user_settings（用户设置，单表单行）
-- ============================================================
CREATE TABLE IF NOT EXISTS user_settings (
    id                 INTEGER PRIMARY KEY CHECK (id = 1),  -- 强制单行
    daily_minutes      INTEGER NOT NULL DEFAULT 15,         -- 5 / 15 / 30
    desired_retention  REAL    NOT NULL DEFAULT 0.90,
    new_limit          INTEGER NOT NULL DEFAULT 20,
    reminder_enabled   INTEGER NOT NULL DEFAULT 1,
    reminder_time      TEXT    NOT NULL DEFAULT '20:00',
    reminder_dismissed INTEGER NOT NULL DEFAULT 0,         -- 用户关闭后不再打扰
    gesture_mode       INTEGER NOT NULL DEFAULT 0,         -- 0按钮为主 1手势为主
    handedness         TEXT    NOT NULL DEFAULT 'right',
    font_scale         TEXT    NOT NULL DEFAULT 'standard',
    read_aloud         INTEGER NOT NULL DEFAULT 0,
    left_handed        INTEGER NOT NULL DEFAULT 0,
    -- 首次引导
    onboarding_done    INTEGER NOT NULL DEFAULT 0,
    onboarding_step    INTEGER NOT NULL DEFAULT 0,         -- 0-4，支持中途退出后回来
    -- 设备与同步
    device_id          TEXT,
    device_name        TEXT,
    device_type        TEXT,
    sync_enabled       INTEGER NOT NULL DEFAULT 0,
    auto_backup        INTEGER NOT NULL DEFAULT 1,
    last_backup_at     INTEGER,
    -- 中断恢复
    last_session_id    TEXT,
    -- AI 额度
    ai_quota_date      TEXT,
    ai_quota_used      INTEGER NOT NULL DEFAULT 0,
    fsrs_params        TEXT,                              -- JSON 数组，NULL=用默认值
    -- 迁移依据
    schema_version     INTEGER NOT NULL DEFAULT 1,
    created_at         INTEGER NOT NULL,
    updated_at         INTEGER NOT NULL
);

-- 初始化唯一一行
INSERT OR IGNORE INTO user_settings (id, created_at, updated_at)
VALUES (1, 0, 0);

-- ============================================================
-- 6.6 daily_stats（每日统计）
-- 冗余表：保证首页与统计页秒开，避免每次聚合 revlog 全表
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_stats (
    date               TEXT    PRIMARY KEY,               -- yyyy-MM-dd（本地时区）
    review_count       INTEGER NOT NULL DEFAULT 0,
    new_count          INTEGER NOT NULL DEFAULT 0,
    correct_count      INTEGER NOT NULL DEFAULT 0,        -- 仅内部统计
    duration_ms        INTEGER NOT NULL DEFAULT 0,
    goal_done          INTEGER NOT NULL DEFAULT 0,
    ai_generated_count INTEGER NOT NULL DEFAULT 0,
    ai_kept_count      INTEGER NOT NULL DEFAULT 0,
    resumed_count      INTEGER NOT NULL DEFAULT 0,        -- 中断恢复使用率
    undo_count         INTEGER NOT NULL DEFAULT 0,        -- 过高说明四档按钮有问题
    session_count      INTEGER NOT NULL DEFAULT 0,
    import_count       INTEGER NOT NULL DEFAULT 0,
    created_at         INTEGER NOT NULL,
    updated_at         INTEGER NOT NULL
);

-- ============================================================
-- 6.13 analytics_event（埋点事件，V1.0 本地存储）
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics_event (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    event_name  TEXT    NOT NULL,
    params      TEXT,                                      -- JSON 字符串，存储扩展属性
    created_at  INTEGER NOT NULL
);

-- ============================================================
-- 6.12 索引
-- 以下查询在首页 / 复习页 / 桌面卡片高频触发，缺索引会在几千张卡后掉帧
-- ============================================================

-- 复习队列构建（每次进首页与每次答完一张都会查）
CREATE INDEX IF NOT EXISTS idx_card_due
    ON card(due) WHERE deleted_at IS NULL;

-- 牌组详情页状态分布
CREATE INDEX IF NOT EXISTS idx_card_deck_state
    ON card(deck_id, state) WHERE deleted_at IS NULL;

-- 牌组列表维护 card_count
CREATE INDEX IF NOT EXISTS idx_card_deck
    ON card(deck_id) WHERE deleted_at IS NULL;

-- 撤销定位：找某张卡最近一条有效日志
CREATE INDEX IF NOT EXISTS idx_revlog_card
    ON revlog(card_id, reviewed_at DESC) WHERE is_deleted = 0;

-- 统计聚合，避免全表扫描
CREATE INDEX IF NOT EXISTS idx_revlog_stats
    ON revlog(is_deleted, reviewed_at);

-- 启动时的中断检测
CREATE INDEX IF NOT EXISTS idx_session_state
    ON session(state, updated_at);

-- AI 草稿状态筛选
CREATE INDEX IF NOT EXISTS idx_ai_draft_status
    ON ai_draft(status, created_at DESC);

-- 媒体去重与清理
CREATE INDEX IF NOT EXISTS idx_media_checksum ON media(checksum);
CREATE INDEX IF NOT EXISTS idx_media_refcount ON media(ref_count);

-- 备份保留最近 7 份
CREATE INDEX IF NOT EXISTS idx_backup_created ON backup(created_at DESC);

-- 埋点查询与导出
CREATE INDEX IF NOT EXISTS idx_analytics_event_name ON analytics_event(event_name);
CREATE INDEX IF NOT EXISTS idx_analytics_created ON analytics_event(created_at DESC);
