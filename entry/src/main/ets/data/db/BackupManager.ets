import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import BackupDao from '../dao/BackupDao';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 备份管理器 (Data 层)
 * 
 * 职责：物理文件操作与备份记录维护，实现「保留 7 份」红线。
 */
export class BackupManager {
  private static readonly TAG = 'BackupManager';
  private static readonly MAX_BACKUPS = 7;
  private static backupDao = new BackupDao();

  /**
   * 执行备份并自动触发淘汰
   */
  static async performBackupAndRotate(ctx: common.UIAbilityContext, store: relationalStore.RdbStore, 
                                     backupName: string, type: string): Promise<void> {
    LogUtil.i(BackupManager.TAG, `开始备份任务 [${type}]: ${backupName}`);
    
    // 1. RDB 物理备份
    await store.backup(backupName);

    // 2. 获取文件大小
    let fileSize = 0;
    const backupPath = `${ctx.databaseDir}/${backupName}`;
    try {
      if (fs.accessSync(backupPath)) {
        const stat = fs.statSync(backupPath);
        fileSize = stat.size;
      }
    } catch (err) {
      LogUtil.w(BackupManager.TAG, '无法获取备份文件大小: ' + JSON.stringify(err));
    }

    // 3. 统计数据与版本
    let cardCount = 0;
    const cardRs = await store.querySql('SELECT count(*) FROM card');
    if (cardRs.goToFirstRow()) cardCount = cardRs.getLong(0);
    cardRs.close();

    const versionRs = await store.querySql('PRAGMA user_version');
    let schemaVersion = 1;
    if (versionRs.goToFirstRow()) schemaVersion = versionRs.getLong(0);
    versionRs.close();

    // 4. 登记入库
    const result = await BackupManager.backupDao.insert(store, {
      filePath: backupName,
      fileSize: fileSize,
      backupType: type,
      schemaVersion: schemaVersion,
      cardCount: cardCount
    });

    if (!result.ok) {
      throw new Error('备份登记失败: ' + result.error.message);
    }

    // 5. 执行淘汰 (保留最近 7 份)
    await BackupManager.rotate(ctx, store);
    
    LogUtil.i(BackupManager.TAG, `备份任务完成: ${backupName}`);
  }

  /**
   * 淘汰策略实现
   */
  private static async rotate(ctx: common.UIAbilityContext, store: relationalStore.RdbStore): Promise<void> {
    const result = await BackupManager.backupDao.listRecent(store, 20);
    if (!result.ok || result.data.length <= BackupManager.MAX_BACKUPS) {
      return;
    }

    const toDelete = result.data.slice(BackupManager.MAX_BACKUPS);
    for (const item of toDelete) {
      // 物理删除
      const fullPath = `${ctx.databaseDir}/${item.filePath}`;
      try {
        if (fs.accessSync(fullPath)) {
          fs.unlinkSync(fullPath);
        }
      } catch (e) {
        LogUtil.w(BackupManager.TAG, `清理物理备份失败: ${item.filePath}`);
      }
      // 记录删除
      await BackupManager.backupDao.delete(store, item.id!);
    }
    LogUtil.i(BackupManager.TAG, `已清理 ${toDelete.length} 份过期备份`);
  }
}
