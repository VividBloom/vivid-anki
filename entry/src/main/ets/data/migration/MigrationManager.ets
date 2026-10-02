import { relationalStore } from '@kit.ArkData';
import { LogUtil } from '../../common/utils/LogUtil';
import BackupDao from '../dao/BackupDao';
import CardDao from '../dao/CardDao';

/**
 * 数据库迁移管理器
 * 
 * 职责：
 *   1. 升级前的强制备份（pre_migration）
 *   2. 执行版本迁移脚本（ALTER TABLE 等）
 * 
 * 红线：升级失败必须阻断，确保用户数据不丢失。
 */
export class MigrationManager {
  private static readonly TAG = 'MigrationManager';

  /**
   * 迁移前备份
   * 失败时抛出异常，由 DbHelper 捕获并阻断初始化流程。
   */
  static async backupPreMigration(store: relationalStore.RdbStore, from: number): Promise<void> {
    const backupName = `memo_v${from}_pre_migration.db`;
    LogUtil.i(MigrationManager.TAG, `开始迁移前备份: ${backupName}`);

    try {
      // 1. 执行物理备份
      await store.backup(backupName);

      // 2. 统计当前要点总数（含已标记删除的，以确保数据快照的准确性）
      const cardDao = new CardDao();
      const predicates = new relationalStore.RdbPredicates('card');
      const resultSet = await store.query(predicates);
      const totalCards = resultSet.rowCount;
      resultSet.close();

      // 3. 记录到 backup 表，供用户后续在「设置 - 数据恢复」中查阅
      const backupDao = new BackupDao();
      const result = await backupDao.insert(store, {
        filePath: backupName,
        fileSize: 0, // 物理备份文件大小需通过 ohos.file.fs 获取，此处先填 0
        backupType: 'pre_migration',
        schemaVersion: from,
        cardCount: totalCards
      });

      if (!result.ok) {
        throw new Error('备份记录登记失败: ' + result.error.message);
      }

      LogUtil.i(MigrationManager.TAG, '迁移前备份完成');
    } catch (e) {
      LogUtil.e(MigrationManager.TAG, '迁移前备份失败，将阻断升级: ' + JSON.stringify(e));
      throw e;
    }
  }

  /**
   * 执行版本迁移
   * 采用「步进式」迁移，从 v1 -> v2, v2 -> v3 ...
   */
  static async migrate(store: relationalStore.RdbStore, from: number, to: number): Promise<void> {
    LogUtil.i(MigrationManager.TAG, `执行迁移脚本: v${from} -> v${to}`);

    for (let v = from; v < to; v++) {
      await MigrationManager.runStep(store, v, v + 1);
    }
  }

  private static async runStep(store: relationalStore.RdbStore, from: number, to: number): Promise<void> {
    LogUtil.i(MigrationManager.TAG, `Step: v${from} -> v${to}`);
    
    // 根据版本号分发具体的 SQL 脚本
    if (from === 1 && to === 2) {
      // 示例：v1 -> v2 的迁移逻辑
      // await store.executeSql('ALTER TABLE deck ADD COLUMN new_feature TEXT');
    }
    
    // 后续版本在此追加逻辑
  }
}
