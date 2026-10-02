import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 设备同步元数据实体（SyncMeta Entity）
 * 对应数据库 sync_meta 表。
 * V1.0 仅作本地记录，为多端接续预留。
 */
export interface SyncMetaEntity {
  deviceId: string;
  deviceName?: string;
  deviceType?: string;
  lastActiveAt: number;
  lastSessionId?: string;
  syncCursor?: string;
  schemaVersion: number;
  createdAt: number;
  updatedAt: number;
}

export default class SyncMetaDao {
  private static readonly TAG = 'SyncMetaDao';
  private static readonly TABLE_NAME = 'sync_meta';

  /**
   * 记录/更新设备信息
   */
  async upsert(store: relationalStore.RdbStore, meta: Partial<SyncMetaEntity>): Promise<Result<void>> {
    try {
      if (!meta.deviceId) {
        return Result.failure(ErrorCode.DB_WRITE, '设备 ID 缺失');
      }

      const now = TimeUtil.now();
      const sql = `
        INSERT INTO ${SyncMetaDao.TABLE_NAME} (
          device_id, device_name, device_type, last_active_at, 
          last_session_id, sync_cursor, schema_version, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(device_id) DO UPDATE SET
          device_name = COALESCE(excluded.device_name, device_name),
          device_type = COALESCE(excluded.device_type, device_type),
          last_active_at = excluded.last_active_at,
          last_session_id = excluded.last_session_id,
          sync_cursor = excluded.sync_cursor,
          schema_version = excluded.schema_version,
          updated_at = excluded.updated_at
      `;

      const args = [
        meta.deviceId,
        meta.deviceName || null,
        meta.deviceType || null,
        now,
        meta.lastSessionId || null,
        meta.syncCursor || null,
        meta.schemaVersion || 1,
        now,
        now
      ];

      await store.executeSql(sql, args);
      return Result.success(undefined);
    } catch (e) {
      LogUtil.e(SyncMetaDao.TAG, '同步元数据保存失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '设备信息保存失败');
    }
  }

  /**
   * 获取指定设备的信息
   */
  async queryByDeviceId(store: relationalStore.RdbStore, deviceId: string): Promise<Result<SyncMetaEntity | null>> {
    try {
      const predicates = new relationalStore.RdbPredicates(SyncMetaDao.TABLE_NAME);
      predicates.equalTo('device_id', deviceId);
      const resultSet = await store.query(predicates);
      const list = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(list.length > 0 ? list[0] : null);
    } catch (e) {
      return Result.success(null);
    }
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): SyncMetaEntity[] {
    const list: SyncMetaEntity[] = [];
    while (resultSet.goToNextRow()) {
      list.push({
        deviceId: resultSet.getString(resultSet.getColumnIndex('device_id')),
        deviceName: resultSet.getString(resultSet.getColumnIndex('device_name')),
        deviceType: resultSet.getString(resultSet.getColumnIndex('device_type')),
        lastActiveAt: resultSet.getLong(resultSet.getColumnIndex('last_active_at')),
        lastSessionId: resultSet.getString(resultSet.getColumnIndex('last_session_id')),
        syncCursor: resultSet.getString(resultSet.getColumnIndex('sync_cursor')),
        schemaVersion: resultSet.getLong(resultSet.getColumnIndex('schema_version')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
        updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
      });
    }
    return list;
  }
}
