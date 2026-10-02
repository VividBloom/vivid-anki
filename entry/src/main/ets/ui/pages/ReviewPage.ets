import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { ReviewService, ReviewCard } from '../../domain/review/ReviewService';
import { ResumeService } from '../../domain/session/ResumeService';
import { UndoService } from '../../domain/review/UndoService';
import { QueueCard } from '../../common/types/ReviewTypes';
import { Rating } from '../../domain/scheduler/FsrsScheduler';
import { RatingBar } from '../components/RatingBar';
import { CardTypeService, RenderedContent } from '../../domain/card/CardTypeService';
import { MediaService } from '../../domain/card/MediaService';
import { StateView } from '../components/StateView';
import { SkeletonCard, SkeletonText } from '../components/Skeleton';
import { LogUtil } from '../../common/utils/LogUtil';
import { media } from '@kit.MediaKit';

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
  private undoService: UndoService = new UndoService();
  private typeService: CardTypeService = new CardTypeService();
  private mediaService: MediaService = new MediaService();
  
  @State queue: QueueCard[] = [];
  @State currentIndex: number = 0;
  @State currentCard: ReviewCard | null = null;
  @State isFlipped: boolean = false;
  @State isLoading: boolean = true;
  @State isError: boolean = false;
  @State errorMessage: string = '';
  @State startTime: number = 0;
  @State isLeftHanded: boolean = false;
  @State sessionId: string = '';
  @State showUndoSnackbar: boolean = false;
  @State snackbarText: string = '';
  @State snackbarAction: string = '';
  @State audioPlayer: media.AVPlayer | null = null;
  @State mediaDetails: Map<number, string> = new Map(); // id -> absPath
  private snackbarTimer: number = 0;
  private lastRating: Rating | null = null;
  private lastDuration: number = 0;

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const params = router.getParams() as Record<string, Object>;
    
    this.isLoading = true;
    this.isError = false;
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
      } else if (this.queue.length === 0) {
        this.isError = true;
        this.errorMessage = '今日已无待学习要点';
      } else {
        router.back();
      }
    } catch (e) {
      LogUtil.e('ReviewPage', '初始化失败: ' + JSON.stringify(e));
      this.isError = true;
      this.errorMessage = '复习队列加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  async aboutToDisappear() {
    if (this.audioPlayer) {
      await this.audioPlayer.release();
    }
  }

  private async playAudio(path: string) {
    try {
      if (!this.audioPlayer) {
        this.audioPlayer = await media.createAVPlayer();
      } else {
        await this.audioPlayer.reset();
      }
      
      this.audioPlayer.url = `file://${path}`;
      this.audioPlayer.on('stateChange', (state) => {
        if (state === 'initialized') {
          this.audioPlayer?.prepare();
        } else if (state === 'prepared') {
          this.audioPlayer?.play();
        }
      });
    } catch (e) {
      LogUtil.e('ReviewPage', '播放音频失败: ' + JSON.stringify(e));
    }
  }

  @Builder
  MediaSection(mediaIds: number[]) {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(mediaIds, (id: number) => {
        if (this.mediaDetails.has(id)) {
          this.MediaItem(id, this.mediaDetails.get(id)!)
        }
      }, (id: number) => id.toString())
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  MediaItem(id: number, path: string) {
    if (path.endsWith('.mp3') || path.endsWith('.wav') || path.endsWith('.m4a')) {
      Button() {
        Image($r('app.media.ic_public_sound'))
          .width(24)
          .height(24)
      }
      .variant(ButtonVariant.Circle)
      .backgroundColor('#E3F2FD')
      .margin(4)
      .onClick((e) => {
        e.stopPropagation();
        this.playAudio(path);
      })
    } else {
      Image(`file://${path}`)
        .width(100)
        .height(100)
        .objectFit(ImageFit.Contain)
        .borderRadius(8)
        .margin(4)
        .onClick((e) => {
          e.stopPropagation();
          // 可以做大图预览
        })
    }
  }

  @Builder
  SkeletonView() {
    Column() {
      SkeletonText({ width: '40%', height: 16 }).margin({ bottom: 40 })
      SkeletonCard({ height: 400 })
      SkeletonText({ width: '60%', height: 20 }).margin({ top: 40 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding(24)
  }

  async loadCard(cardId: number) {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.currentCard = await this.reviewService.getCardDetail(ctx, cardId);
    this.isFlipped = false;
    this.startTime = Date.now();
    
    // 加载媒体详情
    if (this.currentCard?.mediaRefs && this.currentCard.mediaRefs.length > 0) {
      const details = await this.reviewService.getMediaDetails(ctx, this.currentCard.mediaRefs);
      this.mediaDetails.clear();
      details.forEach(m => {
        this.mediaDetails.set(m.id!, this.mediaService.getAbsPath(ctx, m.localPath));
      });
    }
  }

  async handleRate(rating: Rating) {
    if (!this.currentCard) return;
    
    const duration = Date.now() - this.startTime;
    const ctx = getContext(this) as common.UIAbilityContext;
    
    try {
      this.lastRating = rating;
      this.lastDuration = duration;

      // 评分落盘并同步更新会话进度
      await this.reviewService.rateCard(ctx, this.currentCard.id!, rating, duration, {
        sessionId: this.sessionId,
        completed: this.currentIndex + 1,
        lastPosition: this.currentIndex
      });
      
      this.currentIndex++;
      this.showSnackbar('已评分', '撤销');

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

  async handleUndo() {
    if (this.currentIndex <= 0) return;
    
    const ctx = getContext(this) as common.UIAbilityContext;
    const lastCardId = this.queue[this.currentIndex - 1].id;
    
    try {
      const result = await this.undoService.undo(ctx, lastCardId);
      if (result.ok) {
        this.currentIndex--;
        // 同步更新会话进度
        await this.resumeService.updateProgress(ctx, this.sessionId, this.currentIndex, 
          this.currentIndex > 0 ? this.queue[this.currentIndex-1].id : 0, 
          Math.max(0, this.currentIndex - 1));
          
        await this.loadCard(this.queue[this.currentIndex].id);
        this.showSnackbar('已撤销', '重做');
      }
    } catch (e) {
      LogUtil.e('ReviewPage', '撤销失败: ' + JSON.stringify(e));
    }
  }

  private showSnackbar(text: string, action: string) {
    this.snackbarText = text;
    this.snackbarAction = action;
    this.showUndoSnackbar = true;
    
    if (this.snackbarTimer) {
      clearTimeout(this.snackbarTimer);
    }
    this.snackbarTimer = setTimeout(() => {
      this.showUndoSnackbar = false;
    }, 4000);
  }

  build() {
    Column() {
      if (this.isLoading) {
        this.SkeletonView()
      } else if (this.isError) {
        StateView({
          type: this.errorMessage.includes('无') ? 'empty' : 'error',
          title: this.isError ? '提示' : '出错了',
          message: this.errorMessage,
          actionLabel: '返回首页',
          onAction: () => router.back()
        })
      } else if (this.currentCard) {
        // 顶部进度条
        Column() {
          Row() {
            Progress({ value: this.currentIndex, total: this.queue.length, type: ProgressType.Linear })
              .layoutWeight(1)
              .color(Color.Blue)
            
            Text(`还剩 ${this.queue.length - this.currentIndex} 张`)
              .fontSize(14)
              .fontColor(Color.Gray)
              .margin({ left: 12, right: 12 })

            Button() {
              Image($r('app.media.ic_public_undo'))
                .width(20)
                .height(20)
                .fillColor(this.currentIndex > 0 ? Color.Black : Color.Gray)
            }
            .variant(ButtonVariant.Plain)
            .enabled(this.currentIndex > 0)
            .onClick(() => {
              this.handleUndo();
            })
          }
          .width('100%')
          .padding(16)
        }

        // 内容展示区域
        Stack() {
          Column() {
            if (!this.isFlipped) {
              // 正面
              Text(this.typeService.getRenderedContent(this.currentCard.front, this.currentCard.back, this.currentCard.cardType, false).question)
                    .fontSize(32)
                    .fontWeight(FontWeight.Bold)
                    .textAlign(TextAlign.Center)
                    .padding(24)
                  
                  if (this.currentCard.mediaRefs && this.currentCard.mediaRefs.length > 0) {
                    this.MediaSection(this.currentCard.mediaRefs)
                  }
            } else {
              // 背面
              Scroll() {
                Column() {
                  Text(this.typeService.getRenderedContent(this.currentCard.front, this.currentCard.back, this.currentCard.cardType, true).question)
                    .fontSize(24)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.Gray)
                    .margin({ bottom: 20 })
                  
                  Divider().color('#EEEEEE').margin({ bottom: 20 })
                  
                  Text(this.typeService.getRenderedContent(this.currentCard.front, this.currentCard.back, this.currentCard.cardType, true).answer)
                    .fontSize(32)
                    .fontWeight(FontWeight.Bold)
                    .textAlign(TextAlign.Center)
                  
                  if (this.currentCard.extra) {
                    Text(this.currentCard.extra)
                      .fontSize(16)
                      .fontColor(Color.Gray)
                      .margin({ top: 24 })
                      .fontStyle(FontStyle.Italic)
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

        // Snackbar
        if (this.showUndoSnackbar) {
          Row() {
            Text(this.snackbarText)
              .fontColor(Color.White)
              .fontSize(14)
            
            Blank()
            
            Text(this.snackbarAction)
              .fontColor('#007DFF')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                if (this.snackbarAction === '撤销') {
                  this.handleUndo();
                } else if (this.snackbarAction === '重做' && this.lastRating !== null) {
                  this.handleRate(this.lastRating);
                }
                this.showUndoSnackbar = false;
              })
          }
          .width('90%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .backgroundColor('#333333')
          .borderRadius(8)
          .position({ x: '5%', y: '85%' })
          .transition({ type: TransitionType.Insert, opacity: 0, translate: { y: 20 } })
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
