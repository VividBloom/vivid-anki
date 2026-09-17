/**
 * 时间工具
 *
 * 全局约定（PRD 6.x）：
 *   - 数据库存 UTC 毫秒（INTEGER）
 *   - 所有「天」的计算按本地时区的自然日，不用 UTC 日期
 *   - 跨零点时连续天数才能算对，这是最容易出 bug 的地方
 */

const MS_PER_DAY = 24 * 60 * 60 * 1000;

export class TimeUtil {
  static now(): number {
    return Date.now();
  }

  /**
   * 本地时区的日期字符串 yyyy-MM-dd
   * 不要用 toISOString() 再截取 —— 那得到的是 UTC 日期，跨零点会错
   */
  static todayKey(ts: number = Date.now()): string {
    const d = new Date(ts);
    const y = d.getFullYear();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return y + '-' + m + '-' + day;
  }

  /** 本地时区当天 00:00 的时间戳 */
  static startOfToday(ts: number = Date.now()): number {
    const d = new Date(ts);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  /**
   * 本地时区次日 00:00，用于「今天到期」的上界。
   *
   * 必须用日历运算（setDate +1）而不是 startOfToday + 86400000：
   * 夏令时切换日一天只有 23 或 25 小时，固定加 24 小时会得到错误的零点，
   * 从而与 elapsedDays 的自然日语义不一致，导致「今天到期」的判断差一整天。
   * 中国大陆目前无夏令时，但面向海外时这是真实 bug。
   */
  static startOfTomorrow(ts: number = Date.now()): number {
    const d = new Date(ts);
    d.setDate(d.getDate() + 1);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  /**
   * 两个时间戳之间相差的「自然日」数。
   * 用于 FSRS 的 elapsed_days —— 必须是自然日而非 24 小时整除，
   * 否则晚上复习和早上复习会得到不同结果。
   */
  static elapsedDays(fromTs: number, toTs: number = Date.now()): number {
    if (fromTs <= 0) {
      return 0;
    }
    const a = TimeUtil.startOfToday(fromTs);
    const b = TimeUtil.startOfToday(toTs);
    return Math.max(0, Math.round((b - a) / MS_PER_DAY));
  }

  /** 把间隔天数换算成到期时间戳 */
  static dueFromInterval(intervalDays: number, fromTs: number = Date.now()): number {
    if (intervalDays < 1) {
      // 不足 1 天：加入当日队列，10 分钟后再出现
      return fromTs + 10 * 60 * 1000;
    }
    return TimeUtil.startOfToday(fromTs) + Math.round(intervalDays) * MS_PER_DAY;
  }

  /** 是否在同一自然日 */
  static isSameDay(a: number, b: number): boolean {
    return TimeUtil.todayKey(a) === TimeUtil.todayKey(b);
  }
}
