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
  
  @State currentStep: number = 0; // 0 to 3
  @State selectedStarter: string = '';
  @State selectedTime: number = 15;

  async aboutToAppear() {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.currentStep = await this.onboardingService.getStep(ctx);
    if (this.currentStep >= 4) {
      this.goHome();
    }
  }

  private async nextStep() {
    const ctx = getContext(this) as common.UIAbilityContext;
    if (this.currentStep < 3) {
      this.currentStep++;
      await this.onboardingService.updateStep(ctx, this.currentStep);
    } else {
      await this.onboardingService.finish(ctx);
      this.goHome();
    }
  }

  private goHome() {
    router.replaceUrl({ url: 'pages/Index' });
  }

  build() {
    Column() {
      // 顶部进度条
      Row({ space: 8 }) {
        ForEach([0, 1, 2, 3], (item: number) => {
          Rect()
            .width('22%')
            .height(4)
            .radius(2)
            .fill(item <= this.currentStep ? '#007DFF' : '#E5E5E5')
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 40 })

      // 内容区域
      Column() {
        if (this.currentStep === 0) {
          this.Step1Starter()
        } else if (this.currentStep === 1) {
          this.Step2Content()
        } else if (this.currentStep === 2) {
          this.Step3Time()
        } else if (this.currentStep === 3) {
          this.Step4Principle()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 24, right: 24 })

      // 底部按钮 (Step 1/2/3 某些选项会自动触发 next，Step 4 需要手动确认)
      if (this.currentStep === 3) {
        Button('开始我的第一课')
          .width('80%')
          .height(56)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 40 })
          .onClick(() => this.nextStep())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  Step1Starter() {
    Column() {
      Text('选个感兴趣的起点')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })
      
      Text('我们将为你准备好第一批要点')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 48 })

      this.StarterOption('日常口语', '常用交流，即学即用')
      this.StarterOption('职场英语', '会议汇报，从容应对')
      this.StarterOption('代码面试', '核心算法，深度复习')
      this.StarterOption('我自己有内容', '导入已有素材', true)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StarterOption(title: string, sub: string, isGhost: boolean = false) {
    Row() {
      Column() {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Text(sub)
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      
      Blank()
      
      Image($r('app.media.ic_public_arrow_right'))
        .width(20)
        .height(20)
        .opacity(0.3)
    }
    .width('100%')
    .padding(20)
    .margin({ bottom: 16 })
    .backgroundColor(isGhost ? '#F9F9F9' : '#F0F7FF')
    .borderRadius(16)
    .onClick(() => {
      this.selectedStarter = title;
      this.nextStep();
    })
  }

  @Builder
  Step2Content() {
    Column() {
      Text('丢进内容')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })
      
      Text('只需一步，将素材变为你的记忆资产')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 48 })

      Row({ space: 16 }) {
        this.ContentEntry('拍照', $r('app.media.ic_public_camera'), '#4CAF50')
        this.ContentEntry('粘贴', $r('app.media.ic_public_paste'), '#2196F3')
        this.ContentEntry('文档', $r('app.media.ic_public_documents'), '#FF9800')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      
      Text('或者跳过，稍后再说')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 60 })
        .onClick(() => this.nextStep())
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ContentEntry(label: string, icon: Resource, color: string) {
    Column() {
      Circle()
        .width(64)
        .height(64)
        .fill(color)
        .opacity(0.1)
        .overlay(
          Image(icon)
            .width(32)
            .height(32)
            .fillColor(color)
        )
      Text(label)
        .fontSize(16)
        .margin({ top: 12 })
    }
    .layoutWeight(1)
    .onClick(() => this.nextStep())
  }

  @Builder
  Step3Time() {
    Column() {
      Text('定个时间')
        .fontSize(28)
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
    .onClick(async () => {
      this.selectedTime = min;
      const ctx = getContext(this) as common.UIAbilityContext;
      await this.onboardingService.updateDailyMinutes(ctx, min);
      // 给一点反馈再跳
      setTimeout(() => this.nextStep(), 300);
    })
  }

  @Builder
  Step4Principle() {
    Column() {
      Text('讲清原理')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })
      
      Text('科学复习，对抗遗忘')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 32 })

      // 遗忘曲线示意图 (简约 UI)
      Column() {
        Stack() {
          // 背景网格线
          Column({ space: 20 }) {
            Divider().color('#F0F0F0')
            Divider().color('#F0F0F0')
            Divider().color('#F0F0F0')
          }.width('100%')
          
          // 曲线示意 (用 Path 或简单的绘制)
          Text('遗忘曲线')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .position({ x: 10, y: 10 })
            
          // 用简单的图形模拟曲线
          Row() {
            // 这里可以用 Shape 或简单的图片占位
            // 为了演示，我们用一段文字和简单的布局
            Text('记忆力')
              .fontSize(10)
              .fontColor('#999999')
              .rotate({ angle: -90 })
              .position({ x: -10, y: 40 })
          }
        }
        .width('100%')
        .height(120)
        .backgroundColor('#FDFDFD')
        .borderRadius(8)
        .border({ width: 1, color: '#EEEEEE' })
        
        Text('今天只给你 12 个要点')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 40, bottom: 8 })
        
        Text('这不是少，是刚刚好')
          .fontSize(16)
          .fontColor('#007DFF')
          .fontWeight(FontWeight.Medium)
        
        Text('循序渐进是长期坚持的秘密')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 12 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .alignItems(HorizontalAlign.Start)
  }
}
