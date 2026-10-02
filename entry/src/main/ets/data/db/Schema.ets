/**
 * 建表语句
 *
 * 【重要】本文件与 docs/V1__init.sql 是同一份内容的两种形态：
 *   - 本文件：给代码执行用，按表拆分成数组，便于逐条执行与错误定位
 *   - docs/V1__init.sql：给人看 / 给评审看，含完整注释
 *   改一处必须改另一处。
 *
 * 表清单对应 PRD 6.2 - 6.11，共 10 张表。
 */

/** 每张表一条，executeSql 不支持一次多语句，因此必须拆开 */
export const CREATE_TABLES: string[] = [
  // 6.4 deck
  `CREATE TABLE IF NOT EXISTS deck (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    cover TEXT,
    is_preset INTEGER NOT NULL DEFAULT 0,
    new_limit INTEGER NOT NULL DEFAULT 20,
    sort_order INTEGER NOT NULL DEFAULT 0,
    card_count INTEGER NOT NULL DEFAULT 0,
    due_count INTEGER NOT NULL DEFAULT 0,
    suspended INTEGER NOT NULL DEFAULT 0,
    batch_offset INTEGER NOT NULL DEFAULT 0,
    deleted_at INTEGER,
    last_studied_at INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`,

  // 6.2 card
  `CREATE TABLE IF NOT EXISTS card (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    -- 刻意不建外键：删牌组必须先软删卡片（理由同 docs/V1__init.sql，审查报告 N-01）
    deck_id INTEGER NOT NULL,
    card_type TEXT NOT NULL DEFAULT 'basic',
    front TEXT NOT NULL,
    back TEXT NOT NULL,
    extra TEXT,
    media_refs TEXT,
    source TEXT NOT NULL DEFAULT 'manual',
    source_ref TEXT,
    state TEXT NOT NULL DEFAULT 'new',
    stability REAL NOT NULL DEFAULT 0,
    difficulty REAL NOT NULL DEFAULT 0,
    due INTEGER NOT NULL DEFAULT 0,
    last_review INTEGER,
    reps INTEGER NOT NULL DEFAULT 0,
    lapses INTEGER NOT NULL DEFAULT 0,
    last_revlog_id INTEGER,
    suspended INTEGER NOT NULL DEFAULT 0,
    deleted_at INTEGER,
    deleted_by_deck INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`,

  // 6.3 revlog
  `CREATE TABLE IF NOT EXISTS revlog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    -- 刻意不建外键：硬删 card 时必须保留本行（理由同 docs/V1__init.sql）
    card_id INTEGER NOT NULL,
    rating INTEGER NOT NULL,
    elapsed_days INTEGER NOT NULL,
    session_id TEXT,
    device_id TEXT,
    stability_before REAL NOT NULL,
    difficulty_before REAL NOT NULL,
    interval_before REAL,
    reps_before INTEGER NOT NULL,
    lapses_before INTEGER NOT NULL,
    stability_after REAL NOT NULL,
    difficulty_after REAL NOT NULL,
    interval_after REAL NOT NULL,
    duration_ms INTEGER,
    reviewed_at INTEGER NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
  )`,

  // 6.7 session
  `CREATE TABLE IF NOT EXISTS session (
    session_id TEXT PRIMARY KEY,
    deck_id INTEGER REFERENCES deck(id) ON DELETE SET NULL,
    state TEXT NOT NULL DEFAULT 'active',
    total_planned INTEGER NOT NULL DEFAULT 0,
    completed INTEGER NOT NULL DEFAULT 0,
    last_card_id INTEGER,
    last_position INTEGER NOT NULL DEFAULT 0,
    device_id TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    updated_at INTEGER NOT NULL
  )`,

  // 6.8 ai_draft
  `CREATE TABLE IF NOT EXISTS ai_draft (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_text TEXT NOT NULL,
    source_type TEXT NOT NULL,
    cards_json TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    generated_count INTEGER NOT NULL DEFAULT 0,
    kept_count INTEGER NOT NULL DEFAULT 0,
    error_code TEXT,
    quota_charged INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    confirmed_at INTEGER
  )`,

  // 6.9 media
  `CREATE TABLE IF NOT EXISTS media (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    local_path TEXT NOT NULL,
    file_size INTEGER NOT NULL DEFAULT 0,
    checksum TEXT,
    ref_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
  )`,

  // 6.10 backup
  `CREATE TABLE IF NOT EXISTS backup (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,
    file_size INTEGER NOT NULL DEFAULT 0,
    backup_type TEXT NOT NULL,
    schema_version INTEGER NOT NULL,
    card_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
  )`,

  // 6.11 sync_meta
  `CREATE TABLE IF NOT EXISTS sync_meta (
    device_id TEXT PRIMARY KEY,
    device_name TEXT,
    device_type TEXT,
    last_active_at INTEGER NOT NULL,
    last_session_id TEXT,
    sync_cursor TEXT,
    schema_version INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`,

  // 6.5 user_settings（强制单行）
  `CREATE TABLE IF NOT EXISTS user_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    daily_minutes INTEGER NOT NULL DEFAULT 15,
    desired_retention REAL NOT NULL DEFAULT 0.90,
    new_limit INTEGER NOT NULL DEFAULT 20,
    reminder_enabled INTEGER NOT NULL DEFAULT 1,
    reminder_time TEXT NOT NULL DEFAULT '20:00',
    reminder_dismissed INTEGER NOT NULL DEFAULT 0,
    gesture_mode INTEGER NOT NULL DEFAULT 0,
    handedness TEXT NOT NULL DEFAULT 'right',
    font_scale TEXT NOT NULL DEFAULT 'standard',
    read_aloud INTEGER NOT NULL DEFAULT 0,
    left_handed INTEGER NOT NULL DEFAULT 0,
    onboarding_done INTEGER NOT NULL DEFAULT 0,
    onboarding_step INTEGER NOT NULL DEFAULT 0,
    device_id TEXT,
    device_name TEXT,
    device_type TEXT,
    sync_enabled INTEGER NOT NULL DEFAULT 0,
    auto_backup INTEGER NOT NULL DEFAULT 1,
    last_backup_at INTEGER,
    last_session_id TEXT,
    ai_quota_date TEXT,
    ai_quota_used INTEGER NOT NULL DEFAULT 0,
    fsrs_params TEXT,
    schema_version INTEGER NOT NULL DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`,

  // 6.6 daily_stats
  `CREATE TABLE IF NOT EXISTS daily_stats (
    date TEXT PRIMARY KEY,
    review_count INTEGER NOT NULL DEFAULT 0,
    new_count INTEGER NOT NULL DEFAULT 0,
    correct_count INTEGER NOT NULL DEFAULT 0,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    goal_done INTEGER NOT NULL DEFAULT 0,
    ai_generated_count INTEGER NOT NULL DEFAULT 0,
    ai_kept_count INTEGER NOT NULL DEFAULT 0,
    resumed_count INTEGER NOT NULL DEFAULT 0,
    undo_count INTEGER NOT NULL DEFAULT 0,
    session_count INTEGER NOT NULL DEFAULT 0,
    import_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`
];

/** 6.12 索引 —— 缺索引会在几千张卡后明显掉帧 */
export const CREATE_INDEXES: string[] = [
  // 复习队列构建：每次进首页与每次答完一张都会查
  `CREATE INDEX IF NOT EXISTS idx_card_due ON card(due) WHERE deleted_at IS NULL`,
  // 牌组详情页状态分布
  `CREATE INDEX IF NOT EXISTS idx_card_deck_state ON card(deck_id, state) WHERE deleted_at IS NULL`,
  // 牌组列表维护 card_count
  `CREATE INDEX IF NOT EXISTS idx_card_deck ON card(deck_id) WHERE deleted_at IS NULL`,
  // 撤销定位：找某张卡最近一条有效日志
  `CREATE INDEX IF NOT EXISTS idx_revlog_card ON revlog(card_id, reviewed_at DESC) WHERE is_deleted = 0`,
  // 统计聚合，避免全表扫描
  `CREATE INDEX IF NOT EXISTS idx_revlog_stats ON revlog(is_deleted, reviewed_at)`,
  // 启动时的中断检测
  `CREATE INDEX IF NOT EXISTS idx_session_state ON session(state, updated_at)`,
  // AI 草稿状态筛选
  `CREATE INDEX IF NOT EXISTS idx_ai_draft_status ON ai_draft(status, created_at DESC)`,
  // 媒体去重与清理
  `CREATE INDEX IF NOT EXISTS idx_media_checksum ON media(checksum)`,
  `CREATE INDEX IF NOT EXISTS idx_media_refcount ON media(ref_count)`,
  // 备份保留最近 7 份
  `CREATE INDEX IF NOT EXISTS idx_backup_created ON backup(created_at DESC)`
];

/** 初始化 user_settings 唯一一行 */
export const INIT_SETTINGS: string =
  `INSERT OR IGNORE INTO user_settings (id, created_at, updated_at) VALUES (1, 0, 0)`;
