import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { DbHelper } from '../../data/db/DbHelper';
import BackupDao, { BackupEntity } from '../../data/dao/BackupDao';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { Result } from '../../common/utils/Result';

/**
 * 备份服务
 * 
 * 职责：
 *   1. 执行每日自动快照
 *   2. 执行升级前强制备份 (pre_migration)
 *   3. 维护「保留 7 份」策略，自动淘汰旧备份
 */
export class BackupService {
  private static readonly TAG = 'BackupService';
  private static readonly MAX_BACKUPS = 7;
  private backupDao = new BackupDao();

  /**
   * 执行自动备份（每日一次）
   */
  async checkAutoBackup(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const store = await DbHelper.getInstance(ctx);
      
      // 1. 检查今日是否已备份
      const startOfToday = TimeUtil.startOfToday();
      const recent = await this.backupDao.listRecent(store, 1);
      
      if (recent.ok && recent.data.length > 0) {
        const lastBackup = recent.data[0];
        if (lastBackup.createdAt >= startOfToday && lastBackup.backupType === 'auto') {
          LogUtil.d(BackupService.TAG, '今日已完成自动备份，跳过');
          return;
        }
      }

      // 2. 执行备份
      const backupName = `memo_auto_${TimeUtil.now()}.db`;
      await this.performBackup(ctx, store, backupName, 'auto');
      
      // 3. 执行淘汰策略
      await this.rotate(ctx, store);
    } catch (e) {
      LogUtil.e(BackupService.TAG, '自动备份失败: ' + JSON.stringify(e));
    }
  }

  /**
   * 物理备份与登记逻辑
   */
  async performBackup(ctx: common.UIAbilityContext, store: relationalStore.RdbStore, 
                      backupName: string, type: string): Promise<void> {
    LogUtil.i(BackupService.TAG, `开始备份 [${type}]: ${backupName}`);
    
    // 1. RDB 物理备份
    await store.backup(backupName);

    // 2. 获取文件大小 (备份文件默认在 databases 目录下)
    let fileSize = 0;
    const backupPath = `${ctx.databaseDir}/${backupName}`;
    try {
      if (fs.accessSync(backupPath)) {
        const stat = fs.statSync(backupPath);
        fileSize = stat.size;
      }
    } catch (err) {
      LogUtil.w(BackupService.TAG, '无法获取备份文件大小: ' + JSON.stringify(err));
    }

    // 3. 统计卡片数
    let cardCount = 0;
    const res = await store.querySql('SELECT count(*) FROM card');
    if (res.goToFirstRow()) {
      cardCount = res.getLong(0);
    }
    res.close();

    // 4. 登记
    const schemaVersionRs = await store.querySql('PRAGMA user_version');
    let schemaVersion = 1;
    if (schemaVersionRs.goToFirstRow()) {
      schemaVersion = schemaVersionRs.getLong(0);
    }
    schemaVersionRs.close();

    const result = await this.backupDao.insert(store, {
      filePath: backupName,
      fileSize: fileSize,
      backupType: type,
      schemaVersion: schemaVersion,
      cardCount: cardCount
    });

    if (!result.ok) {
      throw new Error('备份记录失败: ' + result.error.message);
    }
    
    LogUtil.i(BackupService.TAG, `备份完成: ${backupName}, 大小: ${fileSize} 字节`);
  }

  /**
   * 淘汰策略：保留最近 7 份，物理删除旧文件
   */
  private async rotate(ctx: common.UIAbilityContext, store: relationalStore.RdbStore): Promise<void> {
    // 获取全部备份记录（按时间倒序）
    const result = await this.backupDao.listRecent(store, 20); // 取 20 条以确保覆盖
    if (!result.ok || result.data.length <= BackupService.MAX_BACKUPS) {
      return;
    }

    const toDelete = result.data.slice(BackupService.MAX_BACKUPS);
    LogUtil.i(BackupService.TAG, `执行淘汰策略，准备删除 ${toDelete.length} 份旧备份`);

    for (const item of toDelete) {
      // 1. 物理删除
      const fullPath = `${ctx.databaseDir}/${item.filePath}`;
      try {
        if (fs.accessSync(fullPath)) {
          fs.unlinkSync(fullPath);
          LogUtil.d(BackupService.TAG, `物理删除旧备份: ${item.filePath}`);
        }
      } catch (e) {
        LogUtil.w(BackupService.TAG, `物理删除失败 ${item.filePath}: ` + JSON.stringify(e));
      }

      // 2. 数据库记录删除
      await this.backupDao.delete(store, item.id!);
    }
  }
}
