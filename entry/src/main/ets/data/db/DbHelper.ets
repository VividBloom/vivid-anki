/**
 * 数据库入口
 *
 * 职责（仅此三项，业务逻辑一律不放这里）：
 *   1. 持有 RdbStore 单例
 *   2. 首次启动建表建索引
 *   3. 版本变化时触发迁移（迁移前强制写 pre_migration 备份）
 *
 * 【不含】启动期的业务维护动作（如回收站到期清理）不在这里调用 ——
 * 那属于 domain 层职责，由 StartupTasks 统一执行，避免 data 反向依赖 domain。
 *
 * 依赖方向：data → common。禁止反向依赖 domain / ui。
 */

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CREATE_INDEXES, CREATE_TABLES, INIT_SETTINGS } from './Schema';
import { LogUtil } from '../../common/utils/LogUtil';
import { MigrationManager } from '../migration/MigrationManager';

const DB_NAME = 'memo.db';
/** 每次结构变更 +1，与 user_settings.schema_version 保持一致 */
const TARGET_VERSION = 1;

/**
 * 数据库辅助类 (DbHelper)
 * 
 * 核心职责：
 * 1. 单例管理：持有全局唯一的 RdbStore 实例，确保数据库连接复用。
 * 2. 生命周期维护：处理数据库的创建 (onCreate) 与版本升级 (onUpgrade)。
 * 3. 安全与原子性：提供 inTransaction 封装，确保评分落盘、撤销、导入等核心操作的原子性。
 * 4. 迁移保护：集成 MigrationManager，在执行版本升级前强制生成 pre_migration 快照，践行“升级不丢数据”的原则。
 * 
 * 架构约束：
 * - 仅限 data 层与 domain 层调用。
 * - 严禁在 doInit 中直接调用业务逻辑，避免循环依赖。
 */
export class DbHelper {
  private static store: relationalStore.RdbStore | null = null;
  private static initPromise: Promise<relationalStore.RdbStore> | null = null;

  /**
   * 获取数据库单例（线程安全）
   * 
   * @param ctx UIAbilityContext 上下文
   * @returns Promise<relationalStore.RdbStore>
   */
  static async getInstance(ctx: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    if (DbHelper.store) {
      return DbHelper.store;
    }
    // 防止并发初始化导致建表执行两次
    if (!DbHelper.initPromise) {
      DbHelper.initPromise = DbHelper.doInit(ctx);
    }
    return DbHelper.initPromise;
  }

  /**
   * 执行初始化流程
   * 流程：打开连接 -> 设置 PRAGMA -> 版本检测 -> [创建表/执行迁移] -> 注入单例。
   */
  private static async doInit(ctx: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      // S1：本地数据，不涉及跨设备同步；若后续开启云同步需重新评估
      securityLevel: relationalStore.SecurityLevel.S1
    };

    const store = await relationalStore.getRdbStore(ctx, config);
    LogUtil.i('DbHelper', '数据库已打开 ' + DB_NAME);

    await store.executeSql('PRAGMA foreign_keys = ON');

    const current = await DbHelper.readVersion(store);
    LogUtil.i('DbHelper', '当前版本 ' + current + '，目标版本 ' + TARGET_VERSION);

    if (current === 0) {
      await DbHelper.createAll(store);
      await DbHelper.writeVersion(store, TARGET_VERSION);
    } else if (current < TARGET_VERSION) {
      // 迁移前必写快照 —— 这是「升级不丢数据」红线的兜底
      await DbHelper.backupBeforeMigration(ctx, store, current);
      await DbHelper.migrate(store, current, TARGET_VERSION);
      await DbHelper.writeVersion(store, TARGET_VERSION);
    }

    DbHelper.store = store;
    return store;
  }

  private static async createAll(store: relationalStore.RdbStore): Promise<void> {
    for (const sql of CREATE_TABLES) {
      await store.executeSql(sql);
    }
    for (const sql of CREATE_INDEXES) {
      await store.executeSql(sql);
    }
    await store.executeSql(INIT_SETTINGS);
    LogUtil.i('DbHelper', '建表完成，共 ' + CREATE_TABLES.length + ' 张表');
  }

  private static async readVersion(store: relationalStore.RdbStore): Promise<number> {
    try {
      const rs = await store.querySql('PRAGMA user_version');
      let version = 0;
      if (rs.goToFirstRow()) {
        version = rs.getLong(rs.getColumnIndex('user_version'));
      }
      rs.close();
      return version;
    } catch (e) {
      LogUtil.w('DbHelper', '读取版本号失败，按 0 处理');
    }
    return 0;
  }

  private static async writeVersion(store: relationalStore.RdbStore, v: number): Promise<void> {
    await store.executeSql('PRAGMA user_version = ' + v);
  }

  /**
   * 迁移前备份。失败必须阻断迁移，不能带着风险升级。
   * 具体实现见 data/migration/MigrationManager.ets
   */
  private static async backupBeforeMigration(ctx: common.UIAbilityContext,
                                             store: relationalStore.RdbStore,
                                             from: number): Promise<void> {
    await MigrationManager.backupPreMigration(ctx, store, from);
  }

  private static async migrate(store: relationalStore.RdbStore, from: number,
                               to: number): Promise<void> {
    await MigrationManager.migrate(store, from, to);
  }

  /**
   * 事务执行器
   * 用于确保多表操作的原子性。评分落盘、数据恢复、彻底删除等关键逻辑必须通过此方法包裹。
   * 
   * @param store 数据库实例
   * @param fn 待执行的异步业务逻辑
   * @returns 业务逻辑的返回结果
   */
  static async inTransaction<T>(store: relationalStore.RdbStore,
                                fn: () => Promise<T>): Promise<T> {
    await store.beginTransaction();
    try {
      const r = await fn();
      await store.commit();
      return r;
    } catch (e) {
      await store.rollBack();
      const errMsg = e instanceof Error ? e.message : JSON.stringify(e);
      LogUtil.e('DbHelper', '事务回滚: ' + errMsg);
      throw e;
    }
  }

  /** 仅测试用：关闭连接 */
  static async destroy(): Promise<void> {
    if (DbHelper.store) {
      DbHelper.store = null;
      DbHelper.initPromise = null;
    }
  }
}
