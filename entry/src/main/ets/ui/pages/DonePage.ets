import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { ReviewService, CompletionSummary } from '../../domain/review/ReviewService';

/**
 * 复习完成收尾页
 * 
 * 职责：展示今日学习成果，提供正向反馈，引导自然收尾。
 * 禁语检查：已避开「错误率」、「正确率」、「牌组」、「卡片」等负面词汇。
 */
@Entry
@Component
struct DonePage {
  private reviewService: ReviewService = new ReviewService();
  
  @State summary: CompletionSummary = {
    todayCount: 0,
    streakDays: 0,
    tomorrowCount: 0
  };
  
  @State isLoading: boolean = true;

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      this.summary = await this.reviewService.getCompletionSummary(ctx);
    } catch (e) {
      // 保持默认值
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 顶部留白
      Blank().height('15%')

      // 核心反馈图标（可选，此处用文字代替）
      Column() {
        Text('已全部完成')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 8 })
        
        Text('今天的任务已顺利结束')
          .fontSize(16)
          .fontColor(Color.Gray)
      }
      .margin({ bottom: 60 })

      // 数据统计区域
      Row() {
        this.StatItem('今日已学', this.summary.todayCount.toString())
        this.StatItem('连续天数', this.summary.streakDays.toString())
        this.StatItem('明日预告', this.summary.tomorrowCount.toString())
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceAround)
      .backgroundColor(Color.White)
      .borderRadius(20)
      .padding({ top: 24, bottom: 24 })
      .shadow({ radius: 15, color: '#0A000000', offsetX: 0, offsetY: 4 })

      Blank()

      // 底部收尾按钮
      Button('完成')
        .width('80%')
        .height(50)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(Color.Black)
        .fontColor(Color.White)
        .borderRadius(25)
        .margin({ bottom: 60 })
        .onClick(() => {
          router.replaceUrl({ url: 'pages/Index' });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
  }

  @Builder
  StatItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 4 })
      
      Text(label)
        .fontSize(12)
        .fontColor(Color.Gray)
    }
    .alignItems(HorizontalAlign.Center)
  }
}
