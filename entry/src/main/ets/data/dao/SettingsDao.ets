import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 用户设置实体（UserSettings Entity）
 * 对应数据库 user_settings 表，强制单行（id=1）。
 */
export interface UserSettingsEntity {
  id: number;
  dailyMinutes: number;
  desiredRetention: number;
  newLimit: number;
  reminderEnabled: number;
  reminderTime: string;
  reminderDismissed: number;
  gestureMode: number;
  handedness: string;
  fontScale: string;
  readAloud: number;
  leftHanded: number;
  onboardingDone: number;
  onboardingStep: number;
  deviceId?: string;
  deviceName?: string;
  deviceType?: string;
  syncEnabled: number;
  autoBackup: number;
  lastBackupAt?: number;
  lastSessionId?: string;
  aiQuotaDate?: string;
  aiQuotaUsed: number;
  fsrsParams?: string;
  schemaVersion: number;
  createdAt: number;
  updatedAt: number;
}

export default class SettingsDao {
  private static readonly TAG = 'SettingsDao';
  private static readonly TABLE_NAME = 'user_settings';

  /**
   * 读取全局设置
   * 由于 DbHelper 中已初始化 id=1 的行，此处直接查询。
   */
  async query(store: relationalStore.RdbStore): Promise<Result<UserSettingsEntity>> {
    try {
      const predicates = new relationalStore.RdbPredicates(SettingsDao.TABLE_NAME);
      predicates.equalTo('id', 1);
      const resultSet = await store.query(predicates);
      const settings = this.parseResultSet(resultSet);
      resultSet.close();
      
      if (settings.length === 0) {
        return Result.failure(ErrorCode.DB_WRITE, '系统设置尚未初始化');
      }
      return Result.success(settings[0]);
    } catch (e) {
      LogUtil.e(SettingsDao.TAG, '读取设置失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法读取系统设置');
    }
  }

  /**
   * 更新设置
   * 自动同步 updatedAt
   */
  async update(store: relationalStore.RdbStore, settings: Partial<UserSettingsEntity>): Promise<Result<number>> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {};
      if (settings.dailyMinutes !== undefined) valueBucket['daily_minutes'] = settings.dailyMinutes;
      if (settings.desiredRetention !== undefined) valueBucket['desired_retention'] = settings.desiredRetention;
      if (settings.newLimit !== undefined) valueBucket['new_limit'] = settings.newLimit;
      if (settings.reminderEnabled !== undefined) valueBucket['reminder_enabled'] = settings.reminderEnabled;
      if (settings.reminderTime !== undefined) valueBucket['reminder_time'] = settings.reminderTime;
      if (settings.reminderDismissed !== undefined) valueBucket['reminder_dismissed'] = settings.reminderDismissed;
      if (settings.gestureMode !== undefined) valueBucket['gesture_mode'] = settings.gestureMode;
      if (settings.handedness !== undefined) valueBucket['handedness'] = settings.handedness;
      if (settings.fontScale !== undefined) valueBucket['font_scale'] = settings.fontScale;
      if (settings.readAloud !== undefined) valueBucket['read_aloud'] = settings.readAloud;
      if (settings.leftHanded !== undefined) valueBucket['left_handed'] = settings.leftHanded;
      if (settings.onboardingDone !== undefined) valueBucket['onboarding_done'] = settings.onboardingDone;
      if (settings.onboardingStep !== undefined) valueBucket['onboarding_step'] = settings.onboardingStep;
      if (settings.deviceId !== undefined) valueBucket['device_id'] = settings.deviceId;
      if (settings.deviceName !== undefined) valueBucket['device_name'] = settings.deviceName;
      if (settings.deviceType !== undefined) valueBucket['device_type'] = settings.deviceType;
      if (settings.syncEnabled !== undefined) valueBucket['sync_enabled'] = settings.syncEnabled;
      if (settings.autoBackup !== undefined) valueBucket['auto_backup'] = settings.autoBackup;
      if (settings.lastBackupAt !== undefined) valueBucket['last_backup_at'] = settings.lastBackupAt;
      if (settings.lastSessionId !== undefined) valueBucket['last_session_id'] = settings.lastSessionId;
      if (settings.aiQuotaDate !== undefined) valueBucket['ai_quota_date'] = settings.aiQuotaDate;
      if (settings.aiQuotaUsed !== undefined) valueBucket['ai_quota_used'] = settings.aiQuotaUsed;
      if (settings.fsrsParams !== undefined) valueBucket['fsrs_params'] = settings.fsrsParams;
      
      valueBucket['updated_at'] = TimeUtil.now();

      const predicates = new relationalStore.RdbPredicates(SettingsDao.TABLE_NAME);
      predicates.equalTo('id', 1);
      
      const rows = await store.update(valueBucket, predicates);
      return Result.success(rows);
    } catch (e) {
      LogUtil.e(SettingsDao.TAG, '更新设置失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '设置保存失败');
    }
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): UserSettingsEntity[] {
    const list: UserSettingsEntity[] = [];
    while (resultSet.goToNextRow()) {
      list.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        dailyMinutes: resultSet.getLong(resultSet.getColumnIndex('daily_minutes')),
        desiredRetention: resultSet.getDouble(resultSet.getColumnIndex('desired_retention')),
        newLimit: resultSet.getLong(resultSet.getColumnIndex('new_limit')),
        reminderEnabled: resultSet.getLong(resultSet.getColumnIndex('reminder_enabled')),
        reminderTime: resultSet.getString(resultSet.getColumnIndex('reminder_time')),
        reminderDismissed: resultSet.getLong(resultSet.getColumnIndex('reminder_dismissed')),
        gestureMode: resultSet.getLong(resultSet.getColumnIndex('gesture_mode')),
        handedness: resultSet.getString(resultSet.getColumnIndex('handedness')),
        fontScale: resultSet.getString(resultSet.getColumnIndex('font_scale')),
        readAloud: resultSet.getLong(resultSet.getColumnIndex('read_aloud')),
        leftHanded: resultSet.getLong(resultSet.getColumnIndex('left_handed')),
        onboardingDone: resultSet.getLong(resultSet.getColumnIndex('onboarding_done')),
        onboardingStep: resultSet.getLong(resultSet.getColumnIndex('onboarding_step')),
        deviceId: resultSet.getString(resultSet.getColumnIndex('device_id')),
        deviceName: resultSet.getString(resultSet.getColumnIndex('device_name')),
        deviceType: resultSet.getString(resultSet.getColumnIndex('device_type')),
        syncEnabled: resultSet.getLong(resultSet.getColumnIndex('sync_enabled')),
        autoBackup: resultSet.getLong(resultSet.getColumnIndex('auto_backup')),
        lastBackupAt: resultSet.getLong(resultSet.getColumnIndex('last_backup_at')),
        lastSessionId: resultSet.getString(resultSet.getColumnIndex('last_session_id')),
        aiQuotaDate: resultSet.getString(resultSet.getColumnIndex('ai_quota_date')),
        aiQuotaUsed: resultSet.getLong(resultSet.getColumnIndex('ai_quota_used')),
        fsrsParams: resultSet.getString(resultSet.getColumnIndex('fsrs_params')),
        schemaVersion: resultSet.getLong(resultSet.getColumnIndex('schema_version')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
        updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
      });
    }
    return list;
  }
}
