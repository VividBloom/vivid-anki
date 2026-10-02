/**
 * 日志工具 —— 发布前必须关闭调试级别
 * 发布 Checklist 中有对应检查项：「调试日志已关闭」
 */

export class LogUtil {
  /** 发布版置 false。可通过构建参数注入 */
  private static DEBUG: boolean = true;
  private static TAG_PREFIX = '[Memo]';

  static setDebug(on: boolean): void {
    LogUtil.DEBUG = on;
  }

  static d(tag: string, msg: string): void {
    if (LogUtil.DEBUG) {
      console.debug(LogUtil.TAG_PREFIX + tag + ' ' + msg);
    }
  }

  static i(tag: string, msg: string): void {
    console.info(LogUtil.TAG_PREFIX + tag + ' ' + msg);
  }

  static w(tag: string, msg: string): void {
    console.warn(LogUtil.TAG_PREFIX + tag + ' ' + msg);
  }

  static e(tag: string, msg: string): void {
    console.error(LogUtil.TAG_PREFIX + tag + ' ' + msg);
  }
}
