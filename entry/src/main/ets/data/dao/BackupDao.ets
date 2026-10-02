import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 备份记录实体（Backup Entity）
 * 对应数据库 backup 表。
 */
export interface BackupEntity {
  id?: number;
  filePath: string;
  fileSize: number;
  backupType: string; // 'manual', 'auto', 'pre_migration'
  schemaVersion: number;
  cardCount: number;
  createdAt: number;
}

export default class BackupDao {
  private static readonly TAG = 'BackupDao';
  private static readonly TABLE_NAME = 'backup';

  /**
   * 记录一次备份快照
   */
  async insert(store: relationalStore.RdbStore, backup: Partial<BackupEntity>): Promise<Result<number>> {
    try {
      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'file_path': backup.filePath || '',
        'file_size': backup.fileSize || 0,
        'backup_type': backup.backupType || 'manual',
        'schema_version': backup.schemaVersion || 1,
        'card_count': backup.cardCount || 0,
        'created_at': now
      };
      const rowId = await store.insert(BackupDao.TABLE_NAME, valueBucket);
      return Result.success(rowId);
    } catch (e) {
      LogUtil.e(BackupDao.TAG, '记录备份失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法登记备份记录');
    }
  }

  /**
   * 获取最近的备份列表
   */
  async listRecent(store: relationalStore.RdbStore, limit: number): Promise<Result<BackupEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(BackupDao.TABLE_NAME);
      predicates.orderByDesc('created_at').limitAs(limit);
      const resultSet = await store.query(predicates);
      const list = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(list);
    } catch (e) {
      return Result.success([]);
    }
  }

  /**
   * 删除记录
   */
  async delete(store: relationalStore.RdbStore, id: number): Promise<Result<void>> {
    try {
      const predicates = new relationalStore.RdbPredicates(BackupDao.TABLE_NAME);
      predicates.equalTo('id', id);
      await store.delete(predicates);
      return Result.success(undefined);
    } catch (e) {
      return Result.failure(ErrorCode.DB_WRITE, '删除备份记录失败');
    }
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): BackupEntity[] {
    const list: BackupEntity[] = [];
    while (resultSet.goToNextRow()) {
      list.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        filePath: resultSet.getString(resultSet.getColumnIndex('file_path')),
        fileSize: resultSet.getLong(resultSet.getColumnIndex('file_size')),
        backupType: resultSet.getString(resultSet.getColumnIndex('backup_type')),
        schemaVersion: resultSet.getLong(resultSet.getColumnIndex('schema_version')),
        cardCount: resultSet.getLong(resultSet.getColumnIndex('card_count')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
      });
    }
    return list;
  }
}
