import { common } from '@kit.AbilityKit';
import { DbHelper } from '../../data/db/DbHelper';
import DailyStatsDao, { DailyStatsEntity } from '../../data/dao/DailyStatsDao';
import CardDao from '../../data/dao/CardDao';
import SettingsDao from '../../data/dao/SettingsDao';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 统计数据 DTO
 */
export interface StatsDTO {
  /** 连续学习天数 */
  streakDays: number;
  /** 今日已学要点数 */
  todayDone: number;
  /** 今日目标总数（默认为设置中的每日限额） */
  dailyGoal: number;
  /** 未来 7 天每日预计复习数 */
  forecast: number[];
  /** 最近 31 天的活跃数据（用于热力图） */
  heatmap: { date: string, count: number }[];
}

/**
 * 统计业务服务
 * 
 * 职责：
 *   1. 聚合每日统计冗余表数据，实现秒开统计页
 *   2. 计算连续天数与未来预测
 *   禁语检查：已避开「卡片」、「牌组」、「错误率」、「逾期」等敏感词。
 */
export class StatsService {
  private statsDao = new DailyStatsDao();
  private cardDao = new CardDao();
  private settingsDao = new SettingsDao();

  /**
   * 获取统计页核心数据
   */
  async getStats(ctx: common.UIAbilityContext): Promise<StatsDTO> {
    try {
      const store = await DbHelper.getInstance(ctx);
      
      // 1. 获取基础统计与设置
      const today = TimeUtil.todayKey();
      const todayStats = await this.statsDao.queryByDate(store, today);
      const settingsRes = await this.settingsDao.query(store);
      
      const todayDone = todayStats.ok && todayStats.data ? todayStats.data.reviewCount : 0;
      const dailyGoal = settingsRes.ok ? settingsRes.data.newLimit : 20;

      // 2. 获取数据用于热力图 (31天) 与 Streak 计算 (365天)
      const recentStats = await this.statsDao.queryRecent(store, 365);
      const allStats = recentStats.ok ? recentStats.data : [];
      
      // 计算连续天数
      const streakDays = this.calculateStreak(allStats);
      
      // 构建热力图数据 (仅取最近 31 天)
      const heatmap = this.buildHeatmap(allStats.slice(0, 31));

      // 3. 获取未来 7 天预测
      const forecast = await this.getForecast(store);

      return {
        streakDays,
        todayDone,
        dailyGoal,
        forecast,
        heatmap
      };
    } catch (e) {
      LogUtil.e('StatsService', '获取统计数据失败: ' + JSON.stringify(e));
      return {
        streakDays: 0,
        todayDone: 0,
        dailyGoal: 20,
        forecast: [0, 0, 0, 0, 0, 0, 0],
        heatmap: []
      };
    }
  }

  /**
   * 计算连续天数 (Streak)
   * 
   * 逻辑：
   * 1. 如果今天学了，从今天开始往回数。
   * 2. 如果今天没学，但昨天学了，从昨天开始往回数（保持火苗不灭）。
   * 3. 否则连续天数为 0。
   */
  public calculateStreak(stats: DailyStatsEntity[]): number {
    if (stats.length === 0) return 0;
    
    const studyDates = new Set(stats.filter(s => s.reviewCount > 0).map(s => s.date));
    let streak = 0;
    let checkDate = new Date();
    const today = TimeUtil.todayKey(checkDate.getTime());
    
    // 如果今天没学，检查昨天是否学了
    if (!studyDates.has(today)) {
      checkDate.setDate(checkDate.getDate() - 1);
      const yesterday = TimeUtil.todayKey(checkDate.getTime());
      if (!studyDates.has(yesterday)) {
        return 0; // 昨天也没学，断了
      }
    }
    
    // 从 checkDate (可能是今天或昨天) 开始往前追溯
    while (studyDates.has(TimeUtil.todayKey(checkDate.getTime()))) {
      streak++;
      checkDate.setDate(checkDate.getDate() - 1);
      // 保护：如果数据量不足以支撑计算到的天数，则停止
      if (streak > stats.length + 1) break;
    }
    
    return streak;
  }

  /**
   * 构建热力图所需数据
   */
  private buildHeatmap(stats: DailyStatsEntity[]): { date: string, count: number }[] {
    // 简单映射，前端根据 count 渲染颜色深浅
    return stats.map(s => ({
      date: s.date,
      count: s.reviewCount
    }));
  }

  /**
   * 获取未来 7 天复习预测
   */
  private async getForecast(store: any): Promise<number[]> {
    const forecast: number[] = [];
    const oneDayMs = 24 * 60 * 60 * 1000;
    let startTs = TimeUtil.startOfTomorrow();
    
    for (let i = 0; i < 7; i++) {
      const endTs = startTs + oneDayMs;
      const countRes = await this.cardDao.countDueInRange(store, startTs, endTs);
      forecast.push(countRes.ok ? countRes.data : 0);
      startTs = endTs;
    }
    
    return forecast;
  }
}
