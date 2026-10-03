import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { StartupTasks } from '../domain/maintenance/StartupTasks';
import { Analytics } from '../common/utils/Analytics';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private targetPage: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    this.checkTargetPage(want);
    // 执行启动任务（不阻塞主流程）
    StartupTasks.runAll(this.context);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.checkTargetPage(want);
    if (this.targetPage) {
      AppStorage.setOrCreate('targetPage', this.targetPage);
    }
  }

  private checkTargetPage(want: Want): void {
    if (want.parameters && want.parameters.targetPage) {
      this.targetPage = want.parameters.targetPage as string;
    }
    
    // 埋点记录来源
    if (want.parameters) {
      if (want.parameters.from === 'widget') {
        Analytics.logEvent(Analytics.EVENT_WIDGET_ACTIVE);
      } else if (want.parameters.from === 'notification') {
        Analytics.logEvent(Analytics.EVENT_NOTIFICATION_CLICK);
      }
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    if (this.targetPage) {
      AppStorage.setOrCreate('targetPage', this.targetPage);
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}