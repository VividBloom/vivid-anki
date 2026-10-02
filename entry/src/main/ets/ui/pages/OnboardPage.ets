import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { OnboardingService } from '../../domain/onboarding/OnboardingService';

/**
 * 新用户引导页
 * 
 * 职责：引导新用户完成初始设置，建立正确的心理模型
 * 约束：严禁使用「牌组」、「卡片」、「逾期」、「错误率」等负面或术语化词汇
 */
@Entry
@Component
struct OnboardPage {
  private onboardingService: OnboardingService = new OnboardingService();
  
  @State selectedTime: number = 15;
  @State isLoading: boolean = false;

  private async finishOnboarding(minutes: number) {
    this.isLoading = true;
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      await this.onboardingService.updateDailyMinutes(ctx, minutes);
      await this.onboardingService.finish(ctx);
      router.replaceUrl({ url: 'pages/Index' });
    } catch (e) {
      LogUtil.e('OnboardPage', '完成引导失败: ' + JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Stack() {
      Column() {
        // 简约进度条（仅一个阶段）
        Rect()
          .width('90%')
          .height(4)
          .radius(2)
          .fill('#007DFF')
          .margin({ top: 20, bottom: 60 })

        Column() {
          Text('设定你的目标')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 12 })
          
          Text('每天花一点时间，积攒巨大的进步')
            .fontSize(16)
            .fontColor('#666666')
            .margin({ bottom: 48 })

          this.TimeOption(5, '利用碎片时间')
          this.TimeOption(15, '高效专注模式')
          this.TimeOption(30, '深度沉浸学习')

          Text('随时可以在设置中修改')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 32 })
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 24, right: 24 })
        .layoutWeight(1)

        Text('科学复习 · 对抗遗忘')
          .fontSize(12)
          .fontColor('#CCCCCC')
          .margin({ bottom: 40 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(48).height(48)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80FFFFFF')
        .justifyContent(FlexAlign.Center)
      }
    }
  }

  @Builder
  TimeOption(min: number, sub: string) {
    const isSelected = this.selectedTime === min;
    Row() {
      Text(`${min} 分钟`)
        .fontSize(20)
        .fontWeight(isSelected ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(isSelected ? '#007DFF' : Color.Black)
      
      Blank()
      
      Text(sub)
        .fontSize(14)
        .fontColor(isSelected ? '#007DFF' : '#999999')
    }
    .width('100%')
    .padding(24)
    .margin({ bottom: 16 })
    .backgroundColor(isSelected ? '#F0F7FF' : '#F9F9F9')
    .border({ width: 2, color: isSelected ? '#007DFF' : Color.Transparent })
    .borderRadius(16)
    .onClick(() => {
      this.selectedTime = min;
      this.finishOnboarding(min);
    })
  }
}
