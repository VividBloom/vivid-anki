import { router } from '@kit.ArkUI';

/**
 * 删除确认弹窗
 * 
 * 职责：引导用户进行软删除操作，并清晰说明影响。
 * 禁语检查：不使用「删除后无法恢复」，改用「移入回收站」。
 */
@CustomDialog
export struct DeleteConfirmDialog {
  /** 控制器 */
  controller: CustomDialogController;
  /** 项目名称 */
  @Prop itemName: string = '';
  /** 类型：合集(deck) 或 要点(card) */
  @Prop itemType: 'deck' | 'card' = 'card';
  /** 合集内的要点数量（仅类型为 deck 时有效） */
  @Prop cardCount: number = 0;
  /** 确认回调 */
  onConfirm?: () => void;

  build() {
    Column() {
      // 头部
      Text(this.itemType === 'deck' ? '移除合集' : '移除要点')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 16 })

      // 内容描述
      Column({ space: 8 }) {
        Text() {
          Span('确定要将 ')
          Span(`「${this.itemName}」`)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Span(' 移入回收站吗？')
        }
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)

        if (this.itemType === 'deck' && this.cardCount > 0) {
          Text(`合集内的 ${this.cardCount} 个要点会一起移入`)
            .fontSize(14)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 20 })

      // 绿色正面提示
      Row() {
        Image($r('app.media.ic_public_info'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.success_color'))
          .margin({ right: 6 })
        Text('复习记录不会丢失')
          .fontSize(14)
          .fontColor($r('app.color.success_color'))
      }
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.success_light'))
      .borderRadius(8)
      .margin({ bottom: 32 })

      // 按钮组
      Row({ space: 16 }) {
        Button('取消')
          .layoutWeight(1)
          .minHeight(48)
          .backgroundColor($r('app.color.divider_color'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.controller.close();
          })

        Button('移入回收站')
          .layoutWeight(1)
          .minHeight(48)
          .backgroundColor($r('app.color.error_color'))
          .fontColor(Color.White)
          .onClick(() => {
            if (this.onActionConfirm()) {
              this.controller.close();
            }
          })
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(24)
    .width('90%')
  }

  private onActionConfirm(): boolean {
    if (this.onConfirm) {
      this.onConfirm();
      return true;
    }
    return false;
  }
}
