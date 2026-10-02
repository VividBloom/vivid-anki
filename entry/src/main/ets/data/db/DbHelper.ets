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

export class DbHelper {
  private static store: relationalStore.RdbStore | null = null;
  private static initPromise: Promise<relationalStore.RdbStore> | null = null;

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
      await DbHelper.backupBeforeMigration(store, current);
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
  private static async backupBeforeMigration(store: relationalStore.RdbStore,
                                             from: number): Promise<void> {
    await MigrationManager.backupPreMigration(store, from);
  }

  private static async migrate(store: relationalStore.RdbStore, from: number,
                               to: number): Promise<void> {
    await MigrationManager.migrate(store, from, to);
  }

  /**
   * 事务封装。评分落盘、撤销、导入都必须走事务。
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
      LogUtil.e('DbHelper', '事务回滚: ' + JSON.stringify(e as object));
      throw new Error(JSON.stringify(e as object));
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
