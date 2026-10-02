import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { ReturnService } from '../../domain/review/ReturnService';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 回归引导页（断卡回来）
 * 
 * 职责：平滑引导长期未使用的用户回归，消除心理压力。
 * 禁语检查：严禁出现「逾期」、「积压」、「欠账」等词汇。
 */
@Entry
@Component
struct BackPage {
  private returnService: ReturnService = new ReturnService();
  
  @State quota: number = 0;
  @State days: number = 0;
  @State isLoading: boolean = true;

  async aboutToAppear(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.loadReturnInfo(ctx);
  }

  private async loadReturnInfo(ctx: common.UIAbilityContext) {
    this.isLoading = true;
    try {
      const info = await this.returnService.getReturnInfo(ctx);
      this.quota = info.quota;
      this.days = info.days;
    } catch (e) {
      LogUtil.e('BackPage', '加载回归信息失败: ' + JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  private async startLearning() {
    const ctx = getContext(this) as common.UIAbilityContext;
    const result = await this.returnService.getReturnQueue(ctx, this.quota);
    
    if (result.cards.length > 0) {
      router.replaceUrl({
        url: 'ui/pages/ReviewPage',
        params: { queue: result.cards }
      });
    } else {
      router.back();
    }
  }

  build() {
    Column() {
      Blank().layoutWeight(1)
      
      // 欢迎文案
      Column({ space: 16 }) {
        Text('欢迎回来！')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        
        Text(`先来 ${this.quota} 个要点热热身？`)
          .fontSize(20)
          .fontColor('#666666')
      }
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 40 })

      // 减压提示
      Column({ space: 12 }) {
        Row() {
          Image($r('app.media.ic_public_ok'))
            .width(20)
            .height(20)
            .fillColor('#2ECC71')
            .margin({ right: 8 })
          Text('不催你，也不显示积压数字')
            .fontSize(16)
            .fontColor('#999999')
        }
        
        Row() {
          Image($r('app.media.ic_public_ok'))
            .width(20)
            .height(20)
            .fillColor('#2ECC71')
            .margin({ right: 8 })
          Text(`接下来的 ${this.days} 天我们将分批为你安排复习`)
            .fontSize(16)
            .fontColor('#999999')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 40, right: 40 })
      .margin({ bottom: 60 })

      if (this.isLoading) {
        LoadingProgress().width(48).height(48)
      } else {
        Button('开始热身')
          .width(200)
          .height(56)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#007DFF')
          .borderRadius(28)
          .onClick(() => this.startLearning())
        
        Text('稍后再说')
          .fontSize(16)
          .fontColor('#999999')
          .margin({ top: 24 })
          .onClick(() => router.back())
      }

      Blank().layoutWeight(1.5)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
