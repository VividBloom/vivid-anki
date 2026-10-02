/**
 * 通用状态视图
 * 
 * 职责：统一处理空态、错误态、无网态的 UI 展示。
 * 禁语检查：文案符合正向引导，严禁出现负面压力词汇。
 */
@Component
export struct StateView {
  /** 状态类型 */
  @Prop type: 'empty' | 'error' | 'network' = 'empty';
  /** 标题 */
  @Prop title: string = '';
  /** 描述文案 */
  @Prop message: string = '';
  /** 按钮文案 */
  @Prop actionLabel: string = '';
  /** 点击回调 */
  onAction?: () => void;

  /** 图标映射 */
  private getIcon(): Resource {
    switch (this.type) {
      case 'empty':
        return $r('app.media.ic_public_ok');
      case 'error':
        return $r('app.media.ic_public_cancel');
      case 'network':
        return $r('app.media.ic_public_settings');
      default:
        return $r('app.media.ic_public_ok');
    }
  }

  /** 默认颜色 */
  private getColor(): string {
    switch (this.type) {
      case 'empty':
        return '#2ECC71';
      case 'error':
        return '#FF4D4F';
      case 'network':
        return '#FAAD14';
      default:
        return '#2ECC71';
    }
  }

  build() {
    Column() {
      Image(this.getIcon())
        .width(80)
        .height(80)
        .fillColor(this.getColor())
        .opacity(0.8)
        .margin({ bottom: 24 })

      Text(this.title || (this.type === 'empty' ? '空空如也' : this.type === 'error' ? '出错了' : '网络连接异常'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ bottom: 12 })

      Text(this.message || (this.type === 'empty' ? '还没有内容，开始创建吧' : this.type === 'error' ? '请稍后重试' : '请检查网络设置'))
        .fontSize(14)
        .fontColor('#999999')
        .textAlign(TextAlign.Center)
        .padding({ left: 40, right: 40 })
        .margin({ bottom: 32 })

      if (this.actionLabel || this.onAction) {
        Button(this.actionLabel || (this.type === 'error' ? '重试' : '确定'))
          .width(160)
          .height(48)
          .backgroundColor(this.getColor())
          .fontColor(Color.White)
          .borderRadius(24)
          .onClick(() => {
            if (this.onAction) this.onAction();
          })
      }
    }
    .width('100%')
    .padding({ top: 100, bottom: 100 })
    .justifyContent(FlexAlign.Center)
  }
}
