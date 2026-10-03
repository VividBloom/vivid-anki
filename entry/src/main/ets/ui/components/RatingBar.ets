import { Rating } from '../../domain/scheduler/FsrsScheduler';
import { BreakpointConstants } from '../../common/constants/BreakpointConstants';

/**
 * 评分条组件
 * 
 * 实现要求：
 *   2x2 布局便于单手操作
 *   宽屏 (lg) 下切换为 1x4 布局
 *   文案固定：再来一次 / 有点难 / 记得 / 太简单
 */
@Component
export struct RatingBar {
  /** 评分回调 */
  onRate: (rating: Rating) => void = () => {};

  /** 是否为左撇子模式 */
  @Prop isLeftHanded: boolean = false;

  /** 当前断点 */
  @StorageProp(BreakpointConstants.KEY_CURRENT_BREAKPOINT) currentBp: string = BreakpointConstants.BREAKPOINT_SM;

  build() {
    Grid() {
      if (this.currentBp === BreakpointConstants.BREAKPOINT_LG) {
        // 宽屏 1x4 布局
        GridItem() {
          this.RatingButton(Rating.Again, '再来一次', $r('app.color.rating_again'))
        }
        GridItem() {
          this.RatingButton(Rating.Hard, '有点难', $r('app.color.rating_hard'))
        }
        GridItem() {
          this.RatingButton(Rating.Good, '记得', $r('app.color.rating_good'))
        }
        GridItem() {
          this.RatingButton(Rating.Easy, '太简单', $r('app.color.rating_easy'))
        }
      } else {
        // 普通 2x2 布局
        // 第一行：左撇子模式下交换位置
        GridItem() {
          if (this.isLeftHanded) {
            this.RatingButton(Rating.Hard, '有点难', $r('app.color.rating_hard'))
          } else {
            this.RatingButton(Rating.Again, '再来一次', $r('app.color.rating_again'))
          }
        }
        GridItem() {
          if (this.isLeftHanded) {
            this.RatingButton(Rating.Again, '再来一次', $r('app.color.rating_again'))
          } else {
            this.RatingButton(Rating.Hard, '有点难', $r('app.color.rating_hard'))
          }
        }
        
        // 第二行：左撇子模式下交换位置
        GridItem() {
          if (this.isLeftHanded) {
            this.RatingButton(Rating.Easy, '太简单', $r('app.color.rating_easy'))
          } else {
            this.RatingButton(Rating.Good, '记得', $r('app.color.rating_good'))
          }
        }
        GridItem() {
          if (this.isLeftHanded) {
            this.RatingButton(Rating.Good, '记得', $r('app.color.rating_good'))
          } else {
            this.RatingButton(Rating.Easy, '太简单', $r('app.color.rating_easy'))
          }
        }
      }
    }
    .columnsTemplate(this.currentBp === BreakpointConstants.BREAKPOINT_LG ? '1fr 1fr 1fr 1fr' : '1fr 1fr')
    .rowsTemplate(this.currentBp === BreakpointConstants.BREAKPOINT_LG ? '1fr' : '1fr 1fr')
    .columnsGap(12)
    .rowsGap(12)
    .width('100%')
    .minHeight(this.currentBp === BreakpointConstants.BREAKPOINT_LG ? 80 : 160)
    .padding(16)
  }

  @Builder
  RatingButton(rating: Rating, label: string, color: Resource) {
    Button() {
      Text(label)
        .fontSize(16)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .minHeight(64)
    .backgroundColor(color)
    .borderRadius(12)
    .onClick(() => {
      this.onRate(rating);
    })
  }
}
