/**
 * 启动期维护任务（todo T1-15）
 *
 * 为什么单独建这个文件：
 *   DbHelper 属 data 层，若在其中调用 DeckLifecycleService（domain 层）
 *   就形成 data → domain 的反向依赖，会被 scripts/check_deps.py 拦下。
 *   因此维护动作统一收到 domain 层，由 EntryAbility 在 onCreate 中调用。
 *
 * 调用方式（未来写入 EntryAbility.ets）：
 *   StartupTasks.runAll(this.context);   // 不 await，避免阻塞首屏
 */

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DbHelper } from '../../data/db/DbHelper';
import { DeckLifecycleService, PurgeResult } from '../deck/DeckLifecycleService';
import { ReminderService } from '../reminder/ReminderService';
import { BackupService } from './BackupService';
import { AnalyticsService } from '../analytics/AnalyticsService';
import { Analytics } from '../../common/utils/Analytics';
import { LogUtil } from '../../common/utils/LogUtil';

export class StartupTasks {
  /**
   * 执行全部启动任务。
   *
   * 三条约束：
   *   1. 不阻塞首屏 —— 调用方不应 await 本方法
   *   2. 单项失败不影响其他项 —— 各自 try/catch
   *   3. 失败不弹错 —— 维护动作失败只意味着这次没做，下次启动会重试
   */
  static async runAll(ctx: common.UIAbilityContext): Promise<void> {
    await StartupTasks.initAnalytics(ctx);
    await StartupTasks.purgeRecycleBin(ctx);
    await StartupTasks.syncReminders(ctx);
    await StartupTasks.checkAutoBackup(ctx);
  }

  /**
   * 初始化埋点系统并记录启动事件
   */
  private static async initAnalytics(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const analyticsSvc = new AnalyticsService();
      await analyticsSvc.init(ctx);
      Analytics.logEvent(Analytics.EVENT_APP_LAUNCH);
    } catch (e) {
      LogUtil.e('StartupTasks', '埋点系统初始化失败: ' + JSON.stringify(e as object));
    }
  }

  /**
   * 检查并执行每日自动备份
   */
  private static async checkAutoBackup(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const backupSvc = new BackupService();
      await backupSvc.checkAutoBackup(ctx);
    } catch (e) {
      LogUtil.w('StartupTasks', '自动备份检查失败: ' + JSON.stringify(e as object));
    }
  }

  /**
   * 清理回收站中超过 30 天的牌组与卡片。
   */
  private static async purgeRecycleBin(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance(ctx);
      const svc = new DeckLifecycleService(store);
      const r: PurgeResult = await svc.purgeExpired();
      if (r.deletedCards > 0 || r.deletedDecks > 0) {
        LogUtil.i('StartupTasks',
          '回收站清理：卡片 ' + r.deletedCards + ' 张，牌组 ' + r.deletedDecks + ' 个');
      }
    } catch (e) {
      // 清理失败不阻断启动：下次启动会重试。
      LogUtil.w('StartupTasks', '回收站清理失败，下次启动重试: ' + JSON.stringify(e as object));
    }
  }

  /**
   * 同步提醒设置到系统代理
   */
  private static async syncReminders(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const reminderSvc = new ReminderService();
      await reminderSvc.applyReminder(ctx);
    } catch (e) {
      LogUtil.w('StartupTasks', '同步提醒失败: ' + JSON.stringify(e as object));
    }
  }
}
