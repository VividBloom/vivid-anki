/**
 * 断点常量定义
 * 
 * 遵循 HarmonyOS 响应式设计标准：
 * sm (Small):  [0, 600)   vp - 手机垂直态
 * md (Medium): [600, 840) vp - 折叠屏展开态 / 手机水平态
 * lg (Large):  [840, +)   vp - 平板 / 2in1
 */
export class BreakpointConstants {
  /** 小屏断点阈值 */
  static readonly BREAKPOINT_SM: string = 'sm';
  
  /** 中屏断点阈值 */
  static readonly BREAKPOINT_MD: string = 'md';
  
  /** 大屏断点阈值 */
  static readonly BREAKPOINT_LG: string = 'lg';

  /** 阈值：中屏起始 (vp) */
  static readonly RANGE_MD: number = 600;

  /** 阈值：大屏起始 (vp) */
  static readonly RANGE_LG: number = 840;

  /** AppStorage Key: 当前断点 */
  static readonly KEY_CURRENT_BREAKPOINT: string = 'currentBreakpoint';

  /** AppStorage Key: 窗口宽度 (vp) */
  static readonly KEY_WINDOW_WIDTH: string = 'windowWidthVp';
  
  /** AppStorage Key: 窗口高度 (vp) */
  static readonly KEY_WINDOW_HEIGHT: string = 'windowHeightVp';
}
