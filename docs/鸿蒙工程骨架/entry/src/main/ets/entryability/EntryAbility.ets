/**
 * 应用入口
 *
 * 职责刻意保持最小：只做三件事。
 * 任何业务逻辑都不应写在这里 —— 那会让它变成第二个 DbHelper。
 */

import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { StartupTasks } from '../domain/maintenance/StartupTasks';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    hilog.info(0x0000, 'EntryAbility', 'onCreate');

    // 启动期维护任务：不 await，避免阻塞首屏。
    // 内部自己 try/catch，失败不影响启动。
    StartupTasks.runAll(this.context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'EntryAbility', 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'EntryAbility', '加载页面失败: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, 'EntryAbility', '页面加载完成');
    });
  }

  onDestroy(): void {
    hilog.info(0x0000, 'EntryAbility', 'onDestroy');
  }
}
