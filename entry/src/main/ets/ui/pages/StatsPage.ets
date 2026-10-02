import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { StatsService, StatsDTO } from '../../domain/stats/StatsService';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 学习成就页（统计页）
 * 
 * 职责：展示核心学习数据，提供正向反馈。
 * 禁语检查：已避开「卡片」、「牌组」、「错误率」、「逾期」、「难度」等敏感词。
 * 实现要求：只放四项核心指标，秒开加载。
 */
@Entry
@Component
struct StatsPage {
  private statsService: StatsService = new StatsService();
  
  @State stats: StatsDTO = {
    streakDays: 0,
    todayDone: 0,
    dailyGoal: 20,
    forecast: [0, 0, 0, 0, 0, 0, 0],
    heatmap: []
  };
  
  @State isLoading: boolean = true;

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.refreshData(ctx);
  }

  private async refreshData(ctx: common.UIAbilityContext) {
    this.isLoading = true;
    try {
      this.stats = await this.statsService.getStats(ctx);
    } catch (e) {
      LogUtil.e('StatsPage', '刷新统计数据失败: ' + JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(24)
          .height(24)
          .onClick(() => router.back())
        
        Text('学习成就')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        
        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      if (this.isLoading) {
        LoadingProgress().width(48).height(48).margin({ top: 100 })
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // 1. 连续学习天数 (Streak)
            this.StreakSection()

            // 2. 今日完成情况 (Progress Ring)
            this.TodayProgressSection()

            // 3. 未来 7 天计划 (Forecast Bar)
            this.ForecastSection()

            // 4. 近期活跃度 (Heatmap)
            this.HeatmapSection()
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
  }

  @Builder
  StreakSection() {
    Column() {
      Row() {
        Image($r('app.media.ic_public_flash_light')) // 假设火苗图标，实际应为火苗
          .width(32)
          .height(32)
          .margin({ right: 8 })
          .fillColor('#FF4500')
        
        Text('连续学习')
          .fontSize(16)
          .fontColor('#666666')
      }
      
      Text(this.stats.streakDays.toString())
        .fontSize(64)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 8 })
      
      Text('天')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#666666')
    }
    .width('100%')
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TodayProgressSection() {
    Column() {
      Text('今日完成情况')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 20 })

      Stack() {
        DataPanel({
          values: [Math.min(this.stats.todayDone, this.stats.dailyGoal)],
          max: this.stats.dailyGoal,
          type: DataPanelType.Circle
        })
          .width(140)
          .height(140)
        
        Column() {
          Text(this.stats.todayDone.toString())
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
          Text(`目标 ${this.stats.dailyGoal}`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(24)
  }

  @Builder
  ForecastSection() {
    Column() {
      Text('未来 7 天计划')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 20 })

      Row() {
        ForEach(this.stats.forecast, (count: number, index: number) => {
          Column() {
            Rect()
              .width(12)
              .height(Math.max(4, Math.min(60, count * 1.5)))
              .radius(6)
              .fill(count > 0 ? '#007DFF' : '#F0F0F0')
            
            Text(count.toString())
              .fontSize(10)
              .margin({ top: 8 })
            
            Text(this.getDayLabel(index))
              .fontSize(10)
              .fontColor('#999999')
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(24)
  }

  @Builder
  HeatmapSection() {
    Column() {
      Text('近 30 天活跃度')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 20 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.generateHeatmapData(), (val: number, index: number) => {
          Rect()
            .width(24)
            .height(24)
            .radius(4)
            .fill(this.getHeatmapColor(val))
            .margin(3)
        })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(24)
  }

  private generateHeatmapData(): number[] {
    // 将 heatmap 数据对齐到最近 30 天的网格
    const data = new Array(30).fill(0);
    const now = new Date();
    
    this.stats.heatmap.forEach(item => {
      const itemDate = new Date(item.date);
      const diffDays = Math.floor((now.getTime() - itemDate.getTime()) / (24 * 60 * 60 * 1000));
      if (diffDays >= 0 && diffDays < 30) {
        data[29 - diffDays] = item.count;
      }
    });
    
    return data;
  }

  private getHeatmapColor(count: number): string {
    if (count === 0) return '#F5F5F5';
    if (count < 5) return '#D5E8FF';
    if (count < 20) return '#80BFFF';
    if (count < 50) return '#3399FF';
    return '#007DFF';
  }

  private getDayLabel(offset: number): string {
    const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    const date = new Date();
    date.setDate(date.getDate() + offset + 1);
    return days[date.getDay()];
  }
}
