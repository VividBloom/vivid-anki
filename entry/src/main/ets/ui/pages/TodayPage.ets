import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { ReviewService, HomeData } from '../../domain/review/ReviewService';
import { ResumeService } from '../../domain/session/ResumeService';
import { ReturnService } from '../../domain/review/ReturnService';
import { StateView } from '../components/StateView';
import { SkeletonCard, SkeletonText } from '../components/Skeleton';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 首页：今日任务概览
 * 
 * 职责：展示核心进度、学习状态与未来预告。
 * 禁语检查：已避开「牌组」、「卡片」、「逾期」、「积压」、「错误率」等负面词汇。
 */
@Component
export struct TodayPage {
  private reviewService: ReviewService = new ReviewService();
  private resumeService: ResumeService = new ResumeService();
  private returnService: ReturnService = new ReturnService();
  
  @State homeData: HomeData = {
    summary: {
      cards: [],
      newCount: 0,
      reviewCount: 0,
      estimatedMinutes: 0
    },
    streakDays: 0,
    forecast: [0, 0, 0, 0, 0, 0, 0],
    todayDone: 0
  };
  
  @State isLoading: boolean = true;
  @State isError: boolean = false;
  @State errorMessage: string = '';

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.refreshData(ctx);
  }

  private async refreshData(ctx: common.UIAbilityContext) {
    this.isLoading = true;
    this.isError = false;
    try {
      // 1. 优先检测是否需要进入回归引导
      const returnStatus = await this.returnService.checkReturnMode(ctx);
      if (returnStatus.shouldEnter) {
        router.pushUrl({ url: 'ui/pages/BackPage' });
        return;
      }

      this.homeData = await this.reviewService.getHomeData(ctx);
      
      // 检测活跃会话
      const activeSession = await this.resumeService.checkActiveSession(ctx);
      if (activeSession && activeSession.completed > 0) {
        this.showResumeDialog(ctx, activeSession.sessionId, activeSession.completed);
      }
    } catch (e) {
      LogUtil.e('TodayPage', '刷新数据失败: ' + JSON.stringify(e));
      this.isError = true;
      this.errorMessage = '无法获取今日进度';
    } finally {
      this.isLoading = false;
    }
  }

  private showResumeDialog(ctx: common.UIAbilityContext, sessionId: string, completed: number) {
    promptAction.showDialog({
      title: '继续之前的学习？',
      message: `已完成 ${completed} 个要点，进度已保存。`,
      buttons: [
        { text: '今天先到这里', color: '#666666' },
        { text: '继续学习', color: '#007DFF' }
      ]
    }).then((data) => {
      if (data.index === 1) {
        router.pushUrl({
          url: 'ui/pages/ReviewPage',
          params: {
            queue: this.homeData.summary.cards,
            sessionId: sessionId,
            startIndex: completed
          }
        });
      } else {
        this.resumeService.abandonSession(ctx, sessionId);
      }
    });
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Scroll() {
        Column() {
          // 顶部标题
          Row() {
            Text('瞄一眼')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Image($r('app.media.ic_public_settings'))
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_primary'))
              .onClick(() => {
                router.pushUrl({ url: 'ui/pages/SettingsPage' });
              })
          }
          .width('100%')
          .minHeight(56)
          .padding({ left: 20, right: 20, top: 20, bottom: 20 })

          if (this.isLoading) {
            this.SkeletonView()
          } else if (this.isError) {
            StateView({
              type: 'error',
              title: '加载失败',
              message: this.errorMessage,
              onAction: () => {
                const ctx = getContext(this) as common.UIAbilityContext;
                this.refreshData(ctx);
              }
            })
          } else {
            // 主卡片区域 (Hero Card)
            this.HeroCard()

            // 统计数据 (Streak & Heatmap)
            this.StatsSection()

            // 未来预告 (Forecast)
            this.ForecastSection()
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .height('100%')
      .backgroundColor($r('app.color.page_background'))

      // 悬浮添加按钮 (快速制卡)
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_public_add'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
      }
      .width(56)
      .height(56)
      .margin({ right: 24, bottom: 24 })
      .backgroundColor($r('app.color.primary_color'))
      .shadow({ radius: 10, color: '#33007DFF', offsetX: 0, offsetY: 5 })
      .onClick(() => {
        router.pushUrl({ url: 'ui/pages/CreateCardPage' });
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  SkeletonView() {
    Column() {
      SkeletonCard({ height: 260 })
      SkeletonCard({ height: 80 })
      SkeletonCard({ height: 120 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 20 })
  }

  @Builder
  HeroCard() {
    const hasTask = this.homeData.summary.cards.length > 0;
    
    Column() {
      if (hasTask) {
        Text('还有')
          .fontSize(16)
          .fontColor(Color.White)
          .opacity(0.8)
        
        Text(this.homeData.summary.cards.length.toString())
          .fontSize(64)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ top: 8, bottom: 8 })
        
        Text(`约 ${this.homeData.summary.estimatedMinutes} 分钟`)
          .fontSize(16)
          .fontColor(Color.White)
          .opacity(0.8)
          .margin({ bottom: 32 })
        
        Button('开始学习')
          .width(160)
          .minHeight(48)
          .backgroundColor(Color.White)
          .fontColor(Color.Black)
          .borderRadius(24)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            router.pushUrl({
              url: 'ui/pages/ReviewPage',
              params: { queue: this.homeData.summary.cards }
            });
          })
      } else {
        // 零复习态
        Image($r('app.media.ic_public_ok'))
          .width(64)
          .height(64)
          .fillColor(Color.White)
          .margin({ bottom: 16 })
        
        Text('今天已全部完成')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ bottom: 8 })
        
        Text('休息一下，明天再见')
          .fontSize(14)
          .fontColor(Color.White)
          .opacity(0.8)
      }
    }
    .width('90%')
    .padding({ top: 48, bottom: 48 })
    .backgroundColor(hasTask ? $r('app.color.primary_color') : $r('app.color.success_color'))
    .borderRadius(32)
    .shadow({ radius: 20, color: hasTask ? '#33007DFF' : '#332ECC71', offsetX: 0, offsetY: 10 })
    .margin({ bottom: 24 })
  }

  @Builder
  StatsSection() {
    Row() {
      // 连续天数
      Column() {
        Text(this.homeData.streakDays.toString())
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('连续天数')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Divider().vertical(true).height(40).color($r('app.color.divider_color'))

      // 今日热力格
      Column() {
        Rect()
          .width(32)
          .height(32)
          .radius(6)
          .fill(this.getHeatmapColor(this.homeData.todayDone))
          .margin({ bottom: 4 })
        Text('今日成果')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('90%')
    .padding(20)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(20)
    .margin({ bottom: 24 })
  }

  @Builder
  ForecastSection() {
    Column() {
      Row() {
        Text('未来 7 天预告')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .margin({ bottom: 16 })

      Row() {
        ForEach(this.homeData.forecast, (count: number, index: number) => {
          Column() {
            // 简单的柱状示意
            Rect()
              .width(8)
              .height(Math.min(40, count * 2 + 2))
              .radius(4)
              .fill($r('app.color.divider_color'))
              .margin({ bottom: 8 })
            
            Text(count.toString())
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 4 })
            
            Text(this.getDayLabel(index))
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
          }
          .layoutWeight(1)
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Bottom)
    }
    .width('90%')
    .padding(20)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(20)
    .margin({ bottom: 40 })
  }

  private getHeatmapColor(count: number): Resource {
    if (count === 0) return $r('app.color.heatmap_level_0');
    if (count < 10) return $r('app.color.heatmap_level_1');
    if (count < 30) return $r('app.color.heatmap_level_2');
    if (count < 50) return $r('app.color.heatmap_level_3');
    return $r('app.color.heatmap_level_4');
  }

  private getDayLabel(offset: number): string {
    const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    const date = new Date();
    date.setDate(date.getDate() + offset + 1);
    return days[date.getDay()];
  }
}
