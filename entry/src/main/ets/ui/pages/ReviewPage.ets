import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { ReviewService, ReviewCard } from '../../domain/review/ReviewService';
import { ResumeService } from '../../domain/session/ResumeService';
import { QueueCard } from '../../common/types/ReviewTypes';
import { Rating } from '../../domain/scheduler/FsrsScheduler';
import { RatingBar } from '../components/RatingBar';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 复习核心页
 * 
 * 实现要求：
 *   全屏单卡，正面问题居中大字号
 *   点卡片翻面，背面显示答案 + 四档评分
 *   顶部进度条文字：「还剩 N 张」
 */
@Entry
@Component
struct ReviewPage {
  private reviewService: ReviewService = new ReviewService();
  private resumeService: ResumeService = new ResumeService();
  
  @State queue: QueueCard[] = [];
  @State currentIndex: number = 0;
  @State currentCard: ReviewCard | null = null;
  @State isFlipped: boolean = false;
  @State isLoading: boolean = true;
  @State startTime: number = 0;
  @State isLeftHanded: boolean = false;
  @State sessionId: string = '';

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const params = router.getParams() as Record<string, Object>;
    
    try {
      // 加载用户偏好
      const settings = await this.reviewService.getSettings(ctx);
      if (settings) {
        this.isLeftHanded = settings.leftHanded === 1;
      }

      if (params && params.queue) {
        this.queue = params.queue as QueueCard[];
        this.sessionId = params.sessionId as string || '';
        this.currentIndex = params.startIndex as number || 0;
      } else {
        const summary = await this.reviewService.getTodaySummary(ctx);
        this.queue = summary.cards;
      }
      
      // 如果没有会话 ID 且队列不为空，则开启新会话
      if (!this.sessionId && this.queue.length > 0) {
        const id = await this.resumeService.startSession(ctx, this.queue.length);
        if (id) this.sessionId = id;
      }

      if (this.queue.length > 0 && this.currentIndex < this.queue.length) {
        await this.loadCard(this.queue[this.currentIndex].id);
      } else {
        router.back();
      }
    } catch (e) {
      LogUtil.e('ReviewPage', '初始化失败: ' + JSON.stringify(e));
      router.back();
    } finally {
      this.isLoading = false;
    }
  }

  async loadCard(cardId: number) {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.currentCard = await this.reviewService.getCardDetail(ctx, cardId);
    this.isFlipped = false;
    this.startTime = Date.now();
  }

  async handleRate(rating: Rating) {
    if (!this.currentCard) return;
    
    const duration = Date.now() - this.startTime;
    const ctx = getContext(this) as common.UIAbilityContext;
    
    try {
      // 评分落盘并同步更新会话进度
      await this.reviewService.rateCard(ctx, this.currentCard.id!, rating, duration, {
        sessionId: this.sessionId,
        completed: this.currentIndex + 1,
        lastPosition: this.currentIndex
      });
      
      this.currentIndex++;
      if (this.currentIndex < this.queue.length) {
        await this.loadCard(this.queue[this.currentIndex].id);
      } else {
        // 完成复习，结束会话并跳转至收尾页
        if (this.sessionId) {
          await this.resumeService.finishSession(ctx, this.sessionId);
        }
        router.replaceUrl({ url: 'ui/pages/DonePage' });
      }
    } catch (e) {
      LogUtil.e('ReviewPage', '评分落盘失败: ' + JSON.stringify(e));
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingProgress().width(48).height(48)
      } else if (this.currentCard) {
        // 顶部进度条
        Column() {
          Row() {
            Progress({ value: this.currentIndex, total: this.queue.length, type: ProgressType.Linear })
              .width('70%')
              .color(Color.Blue)
            Text(`还剩 ${this.queue.length - this.currentIndex} 张`)
              .fontSize(14)
              .fontColor(Color.Gray)
              .margin({ left: 12 })
          }
          .width('100%')
          .padding(16)
        }

        // 内容展示区域
        Stack() {
          Column() {
            if (!this.isFlipped) {
              // 正面
              Text(this.currentCard.front)
                .fontSize(32)
                .fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center)
                .padding(24)
            } else {
              // 背面
              Scroll() {
                Column() {
                  Text(this.currentCard.front)
                    .fontSize(18)
                    .fontColor(Color.Gray)
                    .margin({ bottom: 24 })
                  
                  Divider().margin({ bottom: 24 })
                  
                  Text(this.currentCard.back)
                    .fontSize(28)
                    .fontWeight(FontWeight.Medium)
                    .textAlign(TextAlign.Center)
                  
                  if (this.currentCard.extra) {
                    Text(this.currentCard.extra)
                      .fontSize(16)
                      .fontColor(Color.Gray)
                      .margin({ top: 16 })
                  }
                }
                .width('100%')
              }
              .layoutWeight(1)
              .padding(24)
            }
          }
          .width('90%')
          .height('70%')
          .backgroundColor(Color.White)
          .borderRadius(24)
          .shadow({ radius: 20, color: '#1A000000', offsetX: 0, offsetY: 8 })
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.flipCard();
          })
          .gesture(
            GestureGroup(GestureMode.Parallel,
              // 上滑翻面
              SwipeGesture({ direction: SwipeDirection.Up })
                .onAction(() => {
                  this.flipCard();
                }),
              // 左右滑 = 再来一次
              SwipeGesture({ direction: SwipeDirection.Horizontal })
                .onAction(() => {
                  this.handleRate(Rating.Again);
                })
            )
          )
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)

        // 底部评分栏
        if (this.isFlipped) {
          RatingBar({
            onRate: (rating: Rating) => this.handleRate(rating),
            isLeftHanded: this.isLeftHanded
          })
          .transition({ type: TransitionType.Insert, translate: { y: 100 } })
        } else {
          Text('点击屏幕或上滑查看答案')
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ bottom: 40 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
  }

  private flipCard() {
    if (!this.isFlipped) {
      animateTo({ duration: 300 }, () => {
        this.isFlipped = true;
      });
    }
  }
}
