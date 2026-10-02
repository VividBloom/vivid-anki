import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { ReviewService } from '../../domain/review/ReviewService';
import { ResumeService } from '../../domain/session/ResumeService';
import { QueueResult } from '../../common/types/ReviewTypes';

/**
 * 今日任务概览页
 * 
 * 职责：展示今日待学习的汇总信息
 * 禁语检查：已避开「牌组」、「卡片」、「逾期」、「积压」等负面词汇
 */
@Component
export struct TodayPage {
  private reviewService: ReviewService = new ReviewService();
  private resumeService: ResumeService = new ResumeService();
  
  @State summary: QueueResult = {
    cards: [],
    newCount: 0,
    reviewCount: 0,
    estimatedMinutes: 0
  };
  
  @State isLoading: boolean = true;

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      this.summary = await this.reviewService.getTodaySummary(ctx);
      
      // 检测活跃会话
      const activeSession = await this.resumeService.checkActiveSession(ctx);
      if (activeSession && activeSession.completed > 0) {
        this.showResumeDialog(ctx, activeSession.sessionId, activeSession.completed);
      }
    } catch (e) {
      // 失败保持默认空态
    } finally {
      this.isLoading = false;
    }
  }

  private showResumeDialog(ctx: common.UIAbilityContext, sessionId: string, completed: number) {
    promptAction.showDialog({
      title: '继续之前的学习？',
      message: `已完成 ${completed} 个要点，进度已保存。`,
      buttons: [
        {
          text: '今天先到这里',
          color: '#666666'
        },
        {
          text: '继续学习',
          color: '#007DFF'
        }
      ]
    }).then((data) => {
      if (data.index === 1) {
        // 继续学习
        router.pushUrl({
          url: 'ui/pages/ReviewPage',
          params: {
            queue: this.summary.cards,
            sessionId: sessionId,
            startIndex: completed
          }
        });
      } else {
        // 放弃会话
        this.resumeService.abandonSession(ctx, sessionId);
      }
    });
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('瞄一眼')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16 })
      .backgroundColor(Color.White)

      // 主内容区
      Column() {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
            Text('正在同步任务进度...')
              .fontSize(14)
              .fontColor(Color.Gray)
              .margin({ top: 12 })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        } else if (this.summary.cards.length === 0) {
          // 空态（原型 P02c）
          Column() {
            Image($r('app.media.app_icon')) // 暂用图标替代插画
              .width(120)
              .height(120)
              .opacity(0.3)
            Text('今日任务已全部达成')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .margin({ top: 24 })
            Text('或者去「项目」中添加一些新内容')
              .fontSize(14)
              .fontColor(Color.Gray)
              .margin({ top: 8 })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        } else {
          // 汇总信息
          Column() {
            Text('今日待复习')
              .fontSize(16)
              .fontColor(Color.Gray)
            
            Text(`${this.summary.cards.length}`)
              .fontSize(80)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .margin({ top: 16, bottom: 8 })
            
            Row() {
              Text(`预计耗时 `)
                .fontSize(14)
                .fontColor(Color.Gray)
              Text(`${this.summary.estimatedMinutes}`)
                .fontSize(14)
                .fontColor(Color.Blue)
                .fontWeight(FontWeight.Medium)
              Text(` 分钟`)
                .fontSize(14)
                .fontColor(Color.Gray)
            }
            
            Button('开始今日复习')
              .width('80%')
              .height(50)
              .margin({ top: 60 })
              .backgroundColor(Color.Blue)
              .onClick(() => {
                router.pushUrl({
                  url: 'ui/pages/ReviewPage',
                  params: {
                    queue: this.summary.cards
                  }
                });
              })
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F7F7F7')

      // 底部导航占位
      Row() {
        this.TabItem('主页', true)
        this.TabItem('项目', false)
        this.TabItem('我的', false)
      }
      .width('100%')
      .height(64)
      .backgroundColor(Color.White)
      .border({ width: { top: 0.5 }, color: '#E5E5E5' })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TabItem(label: string, isActive: boolean) {
    Column() {
      SymbolGlyph($r('sys.symbol.house')) // 占位图标
        .fontSize(24)
        .fontColor([isActive ? Color.Blue : Color.Gray])
      Text(label)
        .fontSize(10)
        .fontColor(isActive ? Color.Blue : Color.Gray)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }
}
