import { common } from '@kit.AbilityKit';
import { DbHelper } from '../../data/db/DbHelper';
import SettingsDao, { UserSettingsEntity } from '../../data/dao/SettingsDao';
import { Result } from '../../common/utils/Result';

/**
 * 引导业务服务
 * 
 * 职责：管理新用户引导流程的状态同步
 */
export class OnboardingService {
  private settingsDao: SettingsDao = new SettingsDao();

  /**
   * 获取当前引导进度
   */
  async getStep(ctx: common.UIAbilityContext): Promise<number> {
    const store = await DbHelper.getInstance(ctx);
    const result = await this.settingsDao.query(store);
    return result.ok ? result.data.onboardingStep : 0;
  }

  /**
   * 更新引导进度
   */
  async updateStep(ctx: common.UIAbilityContext, step: number): Promise<void> {
    const store = await DbHelper.getInstance(ctx);
    await this.settingsDao.update(store, { onboardingStep: step });
  }

  /**
   * 完成引导
   */
  async finish(ctx: common.UIAbilityContext): Promise<void> {
    const store = await DbHelper.getInstance(ctx);
    await this.settingsDao.update(store, { 
      onboardingDone: 1,
      onboardingStep: 4
    });
  }

  /**
   * 更新每日时长设置
   */
  async updateDailyMinutes(ctx: common.UIAbilityContext, minutes: number): Promise<void> {
    const store = await DbHelper.getInstance(ctx);
    await this.settingsDao.update(store, { dailyMinutes: minutes });
  }
}
