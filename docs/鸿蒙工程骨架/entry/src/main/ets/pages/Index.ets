/**
 * 首页占位（M1 阶段）
 *
 * 存在的唯一理由：main_pages.json 指向本文件，缺失会导致工程编译失败。
 * 真正的 P02「今天」页面在 M2 阶段实现，届时替换本文件的 build 内容。
 *
 * 当前只用于验证：工程可编译 → 数据库可初始化 → 调度器可调用。
 */

import { common } from '@kit.AbilityKit';
import { DbHelper } from '../data/db/DbHelper';
import { FsrsScheduler, MemoryState } from '../domain/scheduler/FsrsScheduler';

@Entry
@Component
struct Index {
  @State message: string = '瞄一眼';
  @State dbReady: string = '初始化中…';

  aboutToAppear(): void {
    this.checkDb();
  }

  private async checkDb(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await DbHelper.getInstance(ctx);
      // 冒烟：新卡评「记得」应得到正的间隔
      const r = new FsrsScheduler().nextIntervalDays(new MemoryState(), 0, 3);
      this.dbReady = '数据库就绪 · 新卡首评间隔 ' + r + ' 天';
    } catch (e) {
      this.dbReady = '初始化失败：' + JSON.stringify(e);
    }
  }

  build() {
    Column() {
      Text(this.message)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
      Text(this.dbReady)
        .fontSize(14)
        .margin({ top: 12 })
        .fontColor('#6B7280')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
