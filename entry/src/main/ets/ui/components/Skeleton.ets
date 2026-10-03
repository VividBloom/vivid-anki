/**
 * 骨架屏组件库
 * 
 * 职责：提供与真实内容形状对应的加载占位图。
 */
@Component
export struct SkeletonCard {
  @Prop height: number = 200;
  
  build() {
    Column()
      .width('90%')
      .height(this.height)
      .backgroundColor($r('app.color.skeleton_color'))
      .borderRadius(24)
      .margin({ bottom: 20 })
  }
}

@Component
export struct SkeletonList {
  @Prop count: number = 5;
  
  build() {
    Column() {
      ForEach(new Array(this.count).fill(0), () => {
        Row() {
          Rect().width(48).height(48).radius(8).fill($r('app.color.skeleton_color'))
          Column() {
            Rect().width('60%').height(16).radius(4).fill($r('app.color.skeleton_color')).margin({ bottom: 8 })
            Rect().width('40%').height(12).radius(4).fill($r('app.color.skeleton_color'))
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .margin({ bottom: 1 })
      })
    }
  }
}

@Component
export struct SkeletonText {
  @Prop width: string | number = '100%';
  @Prop height: number = 20;
  
  build() {
    Rect()
      .width(this.width)
      .height(this.height)
      .radius(this.height / 2)
      .fill($r('app.color.skeleton_color'))
  }
}
