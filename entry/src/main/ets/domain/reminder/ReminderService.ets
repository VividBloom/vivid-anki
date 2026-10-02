import { common } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.AbilityKit';
import { DbHelper } from '../../data/db/DbHelper';
import SettingsDao, { UserSettingsEntity } from '../../data/dao/SettingsDao';
import { ReviewService } from '../review/ReviewService';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 提醒业务服务
 * 
 * 职责：
 *   1. 管理系统代理提醒（闹钟类）
 *   2. 处理提醒的开启、关闭与时间设置
 *   禁语检查：文案统一为「今天的 N 张已就绪」，严禁出现「逾期」。
 */
export class ReminderService {
  private static readonly TAG = 'ReminderService';
  private settingsDao = new SettingsDao();
  private reviewService = new ReviewService();

  /**
   * 应用提醒设置（发布或取消系统提醒）
   */
  async applyReminder(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const settingsRes = await this.settingsDao.query(store);
      
      if (!settingsRes.ok) return;
      const settings = settingsRes.data;

      // 1. 先取消所有已存在的提醒，防止重复
      await this.cancelAllReminders();

      // 2. 如果开启了提醒，则发布新的
      if (settings.reminderEnabled === 1) {
        await this.publishDailyReminder(ctx, settings);
      }
    } catch (e) {
      LogUtil.e(ReminderService.TAG, '应用提醒设置失败: ' + JSON.stringify(e));
    }
  }

  /**
   * 取消所有系统提醒
   */
  private async cancelAllReminders(): Promise<void> {
    try {
      const reminders = await reminderAgentManager.getValidReminders();
      for (const r of reminders) {
        await reminderAgentManager.cancelReminder(r.reminderId);
      }
    } catch (e) {
      LogUtil.e(ReminderService.TAG, '取消提醒失败: ' + JSON.stringify(e));
    }
  }

  /**
   * 发布每日定时提醒
   */
  private async publishDailyReminder(ctx: common.UIAbilityContext, settings: UserSettingsEntity): Promise<void> {
    try {
      // 获取今日要点数
      const summary = await this.reviewService.getTodaySummary(ctx);
      const count = summary.cards.length;
      
      // 解析时间 (HH:mm)
      const timeParts = settings.reminderTime.split(':');
      const hour = parseInt(timeParts[0]) || 9;
      const minute = parseInt(timeParts[1]) || 0;

      const reminderRequest: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: hour,
        minute: minute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // 每天
        title: '瞄一眼',
        content: `今天的 ${count} 张已就绪`,
        ringDuration: 5,
        slotType: reminderAgentManager.SlotType.SOCIAL_COMMUNICATION,
        wantAgent: {
          pkgName: ctx.abilityInfo.bundleName,
          abilityName: ctx.abilityInfo.name
        }
      };

      const reminderId = await reminderAgentManager.publishReminder(reminderRequest);
      LogUtil.i(ReminderService.TAG, `已发布提醒: ID=${reminderId}, Time=${hour}:${minute}`);
    } catch (e) {
      LogUtil.e(ReminderService.TAG, '发布提醒失败: ' + JSON.stringify(e));
    }
  }

  /**
   * 更新提醒设置并立即应用
   */
  async updateReminderSettings(ctx: common.UIAbilityContext, enabled: boolean, time: string): Promise<void> {
    const store = await DbHelper.getInstance(ctx);
    await this.settingsDao.update(store, {
      reminderEnabled: enabled ? 1 : 0,
      reminderTime: time
    });
    await this.applyReminder(ctx);
  }
}
