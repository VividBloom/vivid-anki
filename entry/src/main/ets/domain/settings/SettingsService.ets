import { common } from '@kit.AbilityKit';
import { DbHelper } from '../../data/db/DbHelper';
import SettingsDao, { UserSettingsEntity } from '../../data/dao/SettingsDao';
import { Result } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 用户偏好设置 DTO
 */
export interface SettingsDTO {
  /** 每日新要点上限 */
  newLimit: number;
  /** 是否开启每日提醒 */
  reminderEnabled: boolean;
  /** 是否开启左撇子模式 */
  leftHanded: boolean;
  /** 是否开启自动朗读 */
  readAloud: boolean;
  /** 是否开启自动备份 */
  autoBackup: boolean;
  /** 是否开启多端同步 */
  syncEnabled: boolean;
}

/**
 * 设置业务服务
 * 
 * 职责：
 *   1. 隔离 UI 层与 Data 层实体
 *   2. 处理设置的持久化与业务逻辑
 */
export class SettingsService {
  private settingsDao = new SettingsDao();

  /**
   * 获取当前设置
   */
  async getSettings(ctx: common.UIAbilityContext): Promise<SettingsDTO> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const res = await this.settingsDao.query(store);
      
      if (res.ok) {
        const s = res.data;
        return {
          newLimit: s.newLimit,
          reminderEnabled: s.reminderEnabled === 1,
          leftHanded: s.leftHanded === 1,
          readAloud: s.readAloud === 1,
          autoBackup: s.autoBackup === 1,
          syncEnabled: s.syncEnabled === 1
        };
      }
    } catch (e) {
      LogUtil.e('SettingsService', '获取设置失败: ' + JSON.stringify(e));
    }
    
    // 返回默认值
    return {
      newLimit: 20,
      reminderEnabled: false,
      leftHanded: false,
      readAloud: false,
      autoBackup: true,
      syncEnabled: false
    };
  }

  /**
   * 更新设置项
   */
  async updateSetting(ctx: common.UIAbilityContext, patch: Partial<SettingsDTO>): Promise<boolean> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const updateData: Partial<UserSettingsEntity> = {};
      
      if (patch.newLimit !== undefined) updateData.newLimit = patch.newLimit;
      if (patch.reminderEnabled !== undefined) updateData.reminderEnabled = patch.reminderEnabled ? 1 : 0;
      if (patch.leftHanded !== undefined) updateData.leftHanded = patch.leftHanded ? 1 : 0;
      if (patch.readAloud !== undefined) updateData.readAloud = patch.readAloud ? 1 : 0;
      if (patch.autoBackup !== undefined) updateData.autoBackup = patch.autoBackup ? 1 : 0;
      if (patch.syncEnabled !== undefined) updateData.syncEnabled = patch.syncEnabled ? 1 : 0;
      
      const res = await this.settingsDao.update(store, updateData);
      return res.ok;
    } catch (e) {
      LogUtil.e('SettingsService', '更新设置失败: ' + JSON.stringify(e));
      return false;
    }
  }
}
