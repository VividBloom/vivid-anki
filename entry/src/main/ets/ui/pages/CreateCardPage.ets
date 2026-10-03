import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { CardService } from '../../domain/card/CardService';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 添加要点页
 * 
 * 职责：快速制卡入口，支持富媒体辅助
 * 禁语检查：已避开「牌组」、「卡片」、「字段」、「模板」、「难度」等敏感词汇
 */
@Entry
@Component
struct CreateCardPage {
  private cardService: CardService = new CardService();
  
  @State frontText: string = '';
  @State backText: string = '';
  @State extraInfo: string = '';
  @State isSaving: boolean = false;
  @State showMoreOptions: boolean = false;
  @State isReverse: boolean = false;
  @State isCloze: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params.front) {
      this.frontText = params.front as string;
    }
  }

  /**
   * 保存操作
   * 实现要求：点击保存即完成，不强制预建项目
   */
  private async handleSave() {
    if (!this.frontText.trim()) {
      promptAction.showToast({ message: '请填写正面内容' });
      return;
    }

    this.isSaving = true;
    const ctx = getContext(this) as common.UIAbilityContext;
    
    try {
      const result = await this.cardService.createCard(ctx, this.frontText, this.backText, {
        extra: this.extraInfo,
        cardType: this.isCloze ? 'cloze' : 'basic'
      });

      if (result.ok) {
        promptAction.showToast({ message: '已保存' });
        
        // 如果开启了反向生成，则额外存一份交换正反面的要点
        if (this.isReverse && this.backText.trim()) {
          await this.cardService.createCard(ctx, this.backText, this.frontText, {
            extra: this.extraInfo
          });
        }
        
        router.back();
      } else {
        promptAction.showToast({ message: result.message });
      }
    } catch (e) {
      LogUtil.e('CreateCardPage', '制卡失败: ' + JSON.stringify(e));
      promptAction.showToast({ message: '保存失败，请稍后重试' });
    } finally {
      this.isSaving = false;
    }
  }

  build() {
    Column() {
      // 自定义导航栏
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        
        Text('添加要点')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
        
        Blank()
        
        if (this.isSaving) {
          LoadingProgress().width(24).height(24)
        } else {
          Text('保存')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.frontText.trim() ? $r('app.color.primary_color') : $r('app.color.text_tertiary'))
            .onClick(() => this.handleSave())
        }
      }
      .width('100%')
      .minHeight(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))

      Scroll() {
        Column() {
          // 正面输入区
          this.InputBox('正面', this.frontText, (v: string) => this.frontText = v)
          
          // 背面输入区
          this.InputBox('背面', this.backText, (v: string) => this.backText = v)

          // 辅助功能入口
          Row() {
            this.EntryItem('图片', $r('app.media.ic_public_picture'))
            this.EntryItem('录音', $r('app.media.ic_public_voice'))
            this.EntryItem('拍照', $r('app.media.ic_public_camera'))
            this.EntryItem('公式', $r('app.media.ic_public_formula'))
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceAround)
          .padding({ top: 12, bottom: 24 })

          // 高级选项折叠区
          Column() {
            Row() {
              Text('更多选项')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
              Image(this.showMoreOptions ? $r('app.media.ic_public_arrow_up') : $r('app.media.ic_public_arrow_down'))
                .width(16)
                .height(16)
                .fillColor($r('app.color.text_secondary'))
                .margin({ left: 4 })
            }
            .onClick(() => this.showMoreOptions = !this.showMoreOptions)
            .padding({ top: 12, bottom: 12 })

            if (this.showMoreOptions) {
              Column({ space: 12 }) {
                this.ToggleItem('生成反向要点', this.isReverse, (v: boolean) => this.isReverse = v)
                this.ToggleItem('填空模式', this.isCloze, (v: boolean) => this.isCloze = v)
                
                TextArea({ placeholder: '补充说明（如例句、来源等）...', text: this.extraInfo })
                  .minHeight(100)
                  .backgroundColor($r('app.color.page_background'))
                  .fontColor($r('app.color.text_primary'))
                  .placeholderColor($r('app.color.text_tertiary'))
                  .borderRadius(8)
                  .onChange((v: string) => this.extraInfo = v)
              }
              .width('100%')
              .transition({ type: TransitionType.Insert, opacity: 0 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  InputBox(label: string, text: string, onChange: (v: string) => void) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })
      
      TextArea({ placeholder: `点击输入${label}内容`, text: text })
        .minHeight(140)
        .backgroundColor($r('app.color.card_background'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .borderRadius(12)
        .padding(12)
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 20 })
  }

  @Builder
  EntryItem(label: string, icon: Resource) {
    Column() {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor($r('app.color.text_secondary'))
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 4 })
    }
    .onClick(() => promptAction.showToast({ message: '即将上线' }))
  }

  @Builder
  ToggleItem(label: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.primary_color'))
        .onChange(onChange)
    }
    .width('100%')
    .minHeight(48)
  }
}
