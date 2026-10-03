/**
 * 桌面卡片 UI (2x2)
 * 
 * 职责：展示今日复习进度，提供快速复习入口。
 */
@Entry
@Component
struct WidgetCard {
  /*
   * 变量通过 formBindingData 注入
   */
  @LocalStorageProp('remaining') remaining: number = 0;
  @LocalStorageProp('progress') progress: number = 0;
  @LocalStorageProp('title') title: string = '今天还剩';
  @LocalStorageProp('unit') unit: string = '张';

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.White)
        .borderRadius(16)

      Column() {
        // 顶部文字
        Row() {
          Text(this.title)
            .fontSize(14)
            .fontColor('#666666')
          
          Text(` ${this.remaining} `)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#007DFF')

          Text(this.unit)
            .fontSize(14)
            .fontColor('#666666')
        }
        .margin({ top: 16 })

        // 进度环
        Stack() {
          DataPanel({ values: [this.progress, 100 - this.progress], max: 100, type: DataPanelType.Circle })
            .width(70)
            .height(70)
          
          Column() {
            Text(`${this.progress}%`)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
          }
        }
        .margin({ top: 12, bottom: 12 })

        // 继续复习按钮
        Button('继续复习')
          .width('80%')
          .height(32)
          .fontSize(12)
          .backgroundColor('#007DFF')
          .fontColor(Color.White)
          .borderRadius(16)
          .onClick(() => {
            postCardAction(this, {
              'action': 'router',
              'abilityName': 'EntryAbility',
              'params': {
                'targetPage': 'ReviewPage'
              }
            });
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    // 点击卡片整体也可跳转
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': {
          'targetPage': 'ReviewPage'
        }
      });
    })
  }
}
