import { Rating } from '../../domain/scheduler/FsrsScheduler';

/**
 * 评分条组件
 * 
 * 实现要求：
 *   2x2 布局便于单手操作
 *   文案固定：再来一次 / 有点难 / 记得 / 太简单
 */
@Component
export struct RatingBar {
  /** 评分回调 */
  onRate: (rating: Rating) => void = () => {};

  /** 是否为左撇子模式 */
  @Prop isLeftHanded: boolean = false;

  build() {
    Grid() {
      // 第一行：左撇子模式下交换位置
      GridItem() {
        if (this.isLeftHanded) {
          this.RatingButton(Rating.Hard, '有点难', '#FF9800')
        } else {
          this.RatingButton(Rating.Again, '再来一次', '#F44336')
        }
      }
      GridItem() {
        if (this.isLeftHanded) {
          this.RatingButton(Rating.Again, '再来一次', '#F44336')
        } else {
          this.RatingButton(Rating.Hard, '有点难', '#FF9800')
        }
      }
      
      // 第二行：左撇子模式下交换位置
      GridItem() {
        if (this.isLeftHanded) {
          this.RatingButton(Rating.Easy, '太简单', '#2196F3')
        } else {
          this.RatingButton(Rating.Good, '记得', '#4CAF50')
        }
      }
      GridItem() {
        if (this.isLeftHanded) {
          this.RatingButton(Rating.Good, '记得', '#4CAF50')
        } else {
          this.RatingButton(Rating.Easy, '太简单', '#2196F3')
        }
      }
    }
    .columnsTemplate('1fr 1fr')
    .rowsTemplate('1fr 1fr')
    .columnsGap(12)
    .rowsGap(12)
    .width('100%')
    .height(140)
    .padding(16)
  }

  @Builder
  RatingButton(rating: Rating, label: string, color: string) {
    Button() {
      Text(label)
        .fontSize(16)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(color)
    .borderRadius(12)
    .onClick(() => {
      this.onRate(rating);
    })
  }
}
