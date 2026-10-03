import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { CardService, CardDTO } from '../../domain/card/CardService';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 要点编辑页
 * 
 * 职责：修改现有要点内容，支持移入回收站。
 * 禁语检查：避开「卡片」、「逾期」、「难度」等敏感词汇。
 */
@Entry
@Component
struct CardEditPage {
  private cardService: CardService = new CardService();
  
  @State cardId: number = 0;
  @State frontText: string = '';
  @State backText: string = '';
  @State extraInfo: string = '';
  @State isSaving: boolean = false;

  // 删除弹窗控制
  deleteCardDialog: CustomDialogController = new CustomDialogController({
    builder: DeleteConfirmDialog({
      itemName: this.frontText,
      itemType: 'card',
      onConfirm: () => {
        this.handleDelete();
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params.card) {
      const card = params.card as CardDTO;
      this.cardId = card.id;
      this.frontText = card.front;
      this.backText = card.back;
      this.extraInfo = card.extra || '';
    } else {
      promptAction.showToast({ message: '数据加载异常' });
      router.back();
    }
  }

  private async handleSave() {
    // 实际开发中需在 CardService 增加 updateCard 方法
    // 这里为了演示删除流程，暂不实现完整的更新逻辑
    promptAction.showToast({ message: '更新功能即将上线' });
  }

  private async handleDelete() {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      await this.cardService.softDeleteCard(ctx, this.cardId);
      promptAction.showToast({ message: '要点已移入回收站' });
      router.back();
    } catch (e) {
      LogUtil.e('CardEditPage', '删除失败: ' + JSON.stringify(e));
      promptAction.showToast({ message: '操作失败' });
    }
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        
        Text('编辑要点')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
        
        Blank()
        
        Text('保存')
          .fontSize(16)
          .fontColor(this.frontText.trim() ? $r('app.color.primary_color') : $r('app.color.text_tertiary'))
          .onClick(() => this.handleSave())
      }
      .width('100%')
      .minHeight(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))

      Scroll() {
        Column() {
          this.InputBox('正面', this.frontText, (v: string) => this.frontText = v)
          this.InputBox('背面', this.backText, (v: string) => this.backText = v)
          
          TextArea({ placeholder: '补充说明...', text: this.extraInfo })
            .minHeight(100)
            .backgroundColor($r('app.color.card_background'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .borderRadius(12)
            .padding(12)
            .margin({ top: 12 })
            .onChange((v: string) => this.extraInfo = v)

          // 危险操作区
          Button('移入回收站')
            .width('100%')
            .minHeight(50)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.error_color'))
            .border({ width: 1, color: $r('app.color.error_color') })
            .borderRadius(25)
            .margin({ top: 60, bottom: 40 })
            .onClick(() => {
              this.deleteCardDialog.open();
            })
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
      
      TextArea({ placeholder: `请输入${label}内容`, text: text })
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
}
