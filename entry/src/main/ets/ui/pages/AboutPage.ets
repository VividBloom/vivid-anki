import { router } from '@kit.ArkUI';

/**
 * 关于页
 * 
 * 职责：展示产品信息与协议说明。
 */
@Entry
@Component
struct AboutPage {
  build() {
    Column() {
      // 导航栏
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        
        Text('关于')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
        
        Blank()
      }
      .width('100%')
      .minHeight(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))

      Scroll() {
        Column() {
          Image($r('app.media.app_icon')) // 假设有图标
            .width(80)
            .height(80)
            .borderRadius(16)
            .margin({ top: 60 })
          
          Text('瞄一眼')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 16 })
          
          Text('v1.0.0')
            .fontSize(14)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 8 })

          Column() {
            Text('技术声明')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .margin({ bottom: 12 })
            
            Text('本应用核心算法采用自研 FSRS-6 + BSD-3 参数，未使用 rslib。旨在为鸿蒙用户提供极致流畅的学习体验。')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(22)
          }
          .width('90%')
          .padding(20)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(20)
          .margin({ top: 32 })

          Column() {
            Text('备案信息')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .margin({ bottom: 12 })
            
            Text('开发者：Vivid Lab')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ bottom: 8 })
            
            Text('备案号：[待填入 ICP 备案号]')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('90%')
          .padding(20)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(20)
          .margin({ top: 16 })

          Blank().layoutWeight(1)
          
          Text('Designed for HarmonyOS')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ bottom: 40, top: 40 })
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
