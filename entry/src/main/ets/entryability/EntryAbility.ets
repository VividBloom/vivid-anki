import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';
import { StartupTasks } from '../domain/maintenance/StartupTasks';
import { Analytics } from '../common/utils/Analytics';
import { BreakpointConstants } from '../common/constants/BreakpointConstants';

const DOMAIN = 0x0000;

/**
 * 应用入口 Ability，负责生命周期管理、启动任务调度及全局 UI 适配
 */
export default class EntryAbility extends UIAbility {
  /**
   * 路由目标页面（由外部 Want 传入，如卡片跳转）
   */
  private targetPage: string = '';

  /**
   * Ability 创建回调，初始化应用环境与异步任务
   * @param want 启动参数
   * @param launchParam 启动类型
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      // 初始化深色模式策略（默认遵循系统设置）
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    
    // 解析跳转参数
    this.checkTargetPage(want);
    
    // 执行静默启动任务（数据库初始化、冷启动内容注入、埋点初始化等）
    // 此任务不阻塞主线程渲染
    StartupTasks.runAll(this.context);
  }

  /**
   * Ability 已存在时的启动回调（单实例模式下的热启动）
   * @param want 新的启动参数
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.checkTargetPage(want);
    if (this.targetPage) {
      // 更新全局跳转目标，Index 页面会监听此状态并执行路由
      AppStorage.setOrCreate('targetPage', this.targetPage);
    }
  }

  /**
   * 校验并提取 Want 中的业务参数
   * @param want 启动意图数据
   */
  private checkTargetPage(want: Want): void {
    // 提取跳转目标页面路径
    if (want.parameters && want.parameters.targetPage) {
      this.targetPage = want.parameters.targetPage as string;
    }
    
    // 埋点记录唤起来源，用于分析各入口（桌面卡片/系统通知）的使用频次
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

  /**
   * 窗口舞台创建回调，负责 UI 加载与响应式布局初始化
   * @param windowStage 窗口舞台对象
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    
    // 全局持久化 windowStage 引用，方便在非 UI 上下文（如弹窗释放）中获取窗口实例
    AppStorage.setOrCreate('windowStage', windowStage);

    if (this.targetPage) {
      AppStorage.setOrCreate('targetPage', this.targetPage);
    }

    const mainWindow = windowStage.getMainWindowSync();
    
    // 初始化首帧断点，确保启动即显示正确的响应式布局
    this.updateBreakpoint(mainWindow);

    // 监听窗口尺寸变化，实现手机/折叠屏/平板的无缝切换适配
    mainWindow.on('windowSizeChange', (size) => {
      this.updateBreakpoint(mainWindow);
    });

    // 加载根路由页面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  /**
   * 根据当前窗口尺寸更新全局断点状态
   * 遵循 600vp (md) 和 840vp (lg) 的标准响应式阈值
   * @param mainWindow 主窗口实例
   */
  private updateBreakpoint(mainWindow: window.Window): void {
    const properties = mainWindow.getWindowProperties();
    const widthPx = properties.windowRect.width;
    const heightPx = properties.windowRect.height;
    
    // 逻辑像素转换：将物理像素 (px) 转换为与密度无关的像素 (vp)
    const density = display.getDefaultDisplaySync().densityPixels;
    const widthVp = widthPx / density;
    const heightVp = heightPx / density;

    // 断点判定逻辑
    let bp: string = BreakpointConstants.BREAKPOINT_SM;
    if (widthVp >= BreakpointConstants.RANGE_LG) {
      bp = BreakpointConstants.BREAKPOINT_LG;
    } else if (widthVp >= BreakpointConstants.RANGE_MD) {
      bp = BreakpointConstants.BREAKPOINT_MD;
    }

    // 更新全局状态，UI 组件通过 @StorageLink(bp) 自动触发重绘
    AppStorage.setOrCreate(BreakpointConstants.KEY_CURRENT_BREAKPOINT, bp);
    AppStorage.setOrCreate(BreakpointConstants.KEY_WINDOW_WIDTH, widthVp);
    AppStorage.setOrCreate(BreakpointConstants.KEY_WINDOW_HEIGHT, heightVp);
    
    hilog.info(DOMAIN, 'EntryAbility', 'Window size updated: %{public}d x %{public}d (vp), BP: %{public}s', 
      widthVp, heightVp, bp);
  }

  /**
   * 窗口舞台销毁回调，清理全局监听以预防内存泄漏
   */
  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    try {
      const windowStage = AppStorage.get<window.WindowStage>('windowStage');
      if (windowStage) {
        const mainWindow = windowStage.getMainWindowSync();
        // 关键：解绑 windowSizeChange 监听，防止闭包导致 Ability 无法回收
        mainWindow.off('windowSizeChange');
      }
    } catch (err) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to release window listener: %{public}s', JSON.stringify(err));
    }
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}