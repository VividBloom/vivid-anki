import { LogUtil } from './LogUtil';

/**
 * 埋点统计工具 (V1.0 本地版)
 * 
 * 职责：
 *   1. 定义全量 22 个埋点事件常量（PRD 第十一章一致）
 *   2. 提供统一的埋点触发入口
 *   3. 维持架构分层，通过 delegate 模式解耦持久化逻辑
 * 
 * 分层约束：
 *   属于 common 层，不得引用 data/domain/ui。
 */
export class Analytics {
  // --- 激活漏斗 (Activation Funnel) - 8 个 ---
  /** 应用首次冷启动 */
  static readonly EVENT_APP_LAUNCH = 'app_launch';
  /** 进入新手引导流程 */
  static readonly EVENT_ONBOARDING_START = 'onboarding_start';
  /** 完成引导第 1 步（选择起点/预置合集） */
  static readonly EVENT_ONBOARDING_STEP_1 = 'onboarding_step_1';
  /** 完成引导第 2 步（导入或输入初始内容） */
  static readonly EVENT_ONBOARDING_STEP_2 = 'onboarding_step_2';
  /** 完成引导第 3 步（设定每日复习时长） */
  static readonly EVENT_ONBOARDING_STEP_3 = 'onboarding_step_3';
  /** 完成引导第 4 步（阅读原理说明） */
  static readonly EVENT_ONBOARDING_STEP_4 = 'onboarding_step_4';
  /** 完成全部引导流程，进入首页 */
  static readonly EVENT_ONBOARDING_COMPLETE = 'onboarding_complete';
  /** 用户成功创建并入库了第一张要点 */
  static readonly EVENT_FIRST_CARD_CREATED = 'first_card_created';

  // --- 核心行为 (Core Behavior) - 8 个 ---
  /** 点击「开始复习」按钮进入复习流 */
  static readonly EVENT_REVIEW_START = 'review_start';
  /** 在复习页执行翻卡操作 */
  static readonly EVENT_CARD_FLIP = 'card_flip';
  /** 执行评分操作（点击四档按钮之一） */
  static readonly EVENT_CARD_RATE = 'card_rate';
  /** 完成今日复习计划并进入结算页。参数：total(总数), deck_id(合集ID, 0为混合) */
  static readonly EVENT_SESSION_COMPLETE = 'session_complete';
  /** 启动 AI 提取/制卡请求。参数：source_type(来源类型) */
  static readonly EVENT_AI_GEN_START = 'ai_gen_start';
  /** 用户在预览页确认并采纳了 AI 生成的内容。参数：kept_count(保留数), generated_count(生成总数) */
  static readonly EVENT_AI_GEN_CONFIRM = 'ai_gen_confirm';
  /** 用户手动保存了一张新创建的要点 */
  static readonly EVENT_MANUAL_CREATE = 'manual_create';
  /** 用户成功执行了导出再导入或外部格式导入 */
  static readonly EVENT_DECK_IMPORT = 'deck_import';

  // --- 留存与流失 (Retention/Churn) - 6 个 ---
  /** 在复习过程中点击「撤销」评分。参数：card_id, rating(被撤销的评分) */
  static readonly EVENT_UNDO_ACTION = 'undo_action';
  /** 触发中断恢复逻辑，从上次退出的位置继续复习 */
  static readonly EVENT_SESSION_RESUME = 'session_resume';
  /** 断卡 3 天及以上用户重新回归时，触发「回归模式」引导 */
  static readonly EVENT_RETURN_MODE_TRIGGER = 'return_mode_trigger';
  /** 用户通过鸿蒙桌面服务卡片点击进入 App */
  static readonly EVENT_WIDGET_ACTIVE = 'widget_active';
  /** 用户点击系统代理的每日复习提醒 */
  static readonly EVENT_NOTIFICATION_CLICK = 'notification_click';
  /** 用户执行了数据导出操作（JSON/APKG/CSV） */
  static readonly EVENT_DATA_EXPORT = 'data_export';

  private static delegate: (eventName: string, params?: Record<string, string | number | boolean>) => void = () => {};

  /**
   * 注入埋点持久化实现
   * 通常在应用启动时（StartupTasks）或数据初始化后注入
   */
  static setDelegate(delegate: (eventName: string, params?: Record<string, string | number | boolean>) => void): void {
    Analytics.delegate = delegate;
  }

  /**
   * 记录埋点事件
   * 
   * @param eventName 事件名
   * @param params 扩展属性（键值对）
   */
  static logEvent(eventName: string, params?: Record<string, string | number | boolean>): void {
    LogUtil.d('Analytics', `LogEvent: ${eventName} ${params ? JSON.stringify(params) : ''}`);
    
    if (Analytics.delegate) {
      try {
        Analytics.delegate(eventName, params);
      } catch (e) {
        LogUtil.e('Analytics', 'Delegate execution failed: ' + JSON.stringify(e));
      }
    }
  }
}
