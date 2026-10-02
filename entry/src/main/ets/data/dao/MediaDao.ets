import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 媒体文件实体（Media Entity）
 * 对应数据库 media 表。
 */
export interface MediaEntity {
  id?: number;
  type: string; // 'image', 'audio'
  localPath: string;
  fileSize: number;
  checksum?: string;
  refCount: number;
  createdAt: number;
}

export default class MediaDao {
  private static readonly TAG = 'MediaDao';
  private static readonly TABLE_NAME = 'media';

  /**
   * 注册媒体文件
   */
  async insert(store: relationalStore.RdbStore, media: Partial<MediaEntity>): Promise<Result<number>> {
    try {
      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'type': media.type || 'image',
        'local_path': media.localPath || '',
        'file_size': media.fileSize || 0,
        'checksum': media.checksum || null,
        'ref_count': 1, // 初始引用为 1
        'created_at': now
      };
      const rowId = await store.insert(MediaDao.TABLE_NAME, valueBucket);
      return Result.success(rowId);
    } catch (e) {
      LogUtil.e(MediaDao.TAG, '媒体注册失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法登记媒体文件');
    }
  }

  /**
   * 增加引用计数
   */
  async incrementRef(store: relationalStore.RdbStore, id: number): Promise<Result<void>> {
    try {
      const sql = `UPDATE ${MediaDao.TABLE_NAME} SET ref_count = ref_count + 1 WHERE id = ?`;
      await store.executeSql(sql, [id]);
      return Result.success(undefined);
    } catch (e) {
      return Result.failure(ErrorCode.DB_WRITE, '更新引用计数失败');
    }
  }

  /**
   * 减少引用计数
   */
  async decrementRef(store: relationalStore.RdbStore, id: number): Promise<Result<void>> {
    try {
      const sql = `UPDATE ${MediaDao.TABLE_NAME} SET ref_count = MAX(0, ref_count - 1) WHERE id = ?`;
      await store.executeSql(sql, [id]);
      return Result.success(undefined);
    } catch (e) {
      return Result.failure(ErrorCode.DB_WRITE, '更新引用计数失败');
    }
  }

  /**
   * 查找已无引用的媒体（待物理删除）
   */
  async queryUnused(store: relationalStore.RdbStore): Promise<Result<MediaEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(MediaDao.TABLE_NAME);
      predicates.equalTo('ref_count', 0);
      const resultSet = await store.query(predicates);
      const list = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(list);
    } catch (e) {
      return Result.success([]);
    }
  }

  /**
   * 物理删除记录
   */
  async delete(store: relationalStore.RdbStore, id: number): Promise<Result<void>> {
    try {
      const predicates = new relationalStore.RdbPredicates(MediaDao.TABLE_NAME);
      predicates.equalTo('id', id);
      await store.delete(predicates);
      return Result.success(undefined);
    } catch (e) {
      return Result.failure(ErrorCode.DB_WRITE, '删除媒体记录失败');
    }
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): MediaEntity[] {
    const list: MediaEntity[] = [];
    while (resultSet.goToNextRow()) {
      list.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        type: resultSet.getString(resultSet.getColumnIndex('type')),
        localPath: resultSet.getString(resultSet.getColumnIndex('local_path')),
        fileSize: resultSet.getLong(resultSet.getColumnIndex('file_size')),
        checksum: resultSet.getString(resultSet.getColumnIndex('checksum')),
        refCount: resultSet.getLong(resultSet.getColumnIndex('ref_count')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
      });
    }
    return list;
  }
}
