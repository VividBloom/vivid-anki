import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { BackupManager } from '../db/BackupManager';

/**
 * 数据库迁移管理器 (MigrationManager)
 * 
 * 核心职责：
 * 1. 结构变更维护：负责执行 SQL 迁移脚本（如 ALTER TABLE），支持数据库 Schema 的平滑升级。
 * 2. 升级安全兜底：在执行任何结构变更前，强制调用 BackupManager 生成 pre_migration 类型的快照。
 * 3. 步进式迁移：采用 step-by-step 模式（如 v1->v2, v2->v3），确保迁移逻辑的清晰与可追溯性。
 * 
 * 红线约束：
 * - 迁移前备份失败必须抛出异常并阻断初始化，严禁带病升级。
 * - 迁移逻辑仅限 data 层内部调用，严禁反向依赖 domain 层。
 */
export class MigrationManager {
  private static readonly TAG = 'MigrationManager';

  /**
   * 迁移前强制备份
   * 
   * @param ctx UIAbilityContext 上下文
   * @param store 数据库实例
   * @param from 当前版本号
   */
  static async backupPreMigration(ctx: common.UIAbilityContext, store: relationalStore.RdbStore, from: number): Promise<void> {
    const backupName = `memo_v${from}_pre_migration_${TimeUtil.now()}.db`;
    LogUtil.i(MigrationManager.TAG, `开始迁移前备份: ${backupName}`);

    try {
      await BackupManager.performBackupAndRotate(ctx, store, backupName, 'pre_migration');
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
