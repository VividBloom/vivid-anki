import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { TrashService, TrashItemDTO } from '../../domain/deck/TrashService';
import { StateView } from '../components/StateView';
import { SkeletonList } from '../components/Skeleton';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 回收站页面
 * 
 * 职责：展示 30 天内可恢复的合集与要点，提供恢复与彻底删除功能。
 * 禁语检查：已避开「牌组」、「卡片」、「字段」、「难度」等敏感词汇。
 */
@Entry
@Component
struct TrashPage {
  private trashService: TrashService = new TrashService();
  
  @State items: TrashItemDTO[] = [];
  @State isLoading: boolean = true;
  @State isError: boolean = false;

  async aboutToAppear() {
    await this.refreshData();
  }

  private async refreshData() {
    this.isLoading = true;
    this.isError = false;
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      this.items = await this.trashService.getTrashItems(ctx);
    } catch (e) {
      LogUtil.e('TrashPage', '加载数据失败: ' + JSON.stringify(e));
      this.isError = true;
    } finally {
      this.isLoading = false;
    }
  }

  private async handleRestore(item: TrashItemDTO) {
    const ctx = getContext(this) as common.UIAbilityContext;
    const success = await this.trashService.restoreItem(ctx, item.id, item.type);
    if (success) {
      promptAction.showToast({ message: '已恢复' });
      await this.refreshData();
    } else {
      promptAction.showToast({ message: '恢复失败' });
    }
  }

  private async handleHardDelete(item: TrashItemDTO) {
    AlertDialog.show({
      title: '彻底删除',
      message: `确定要永久删除「${item.name}」吗？此操作不可逆。`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '彻底删除',
        fontColor: '#FF4D4F',
        action: async () => {
          const ctx = getContext(this) as common.UIAbilityContext;
          const success = await this.trashService.hardDeleteItem(ctx, item.id, item.type);
          if (success) {
            promptAction.showToast({ message: '已永久删除' });
            await this.refreshData();
          } else {
            promptAction.showToast({ message: '操作失败' });
          }
        }
      }
    })
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(24)
          .height(24)
          .onClick(() => router.back())
        
        Text('回收站')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        
        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      // 顶部提示条
      Row() {
        Image($r('app.media.ic_public_info'))
          .width(16)
          .height(16)
          .fillColor('#666666')
          .margin({ right: 8 })
        Text('到期清理后复习记录会保留')
          .fontSize(14)
          .fontColor('#666666')
      }
      .width('100%')
      .padding({ top: 12, bottom: 12, left: 16, right: 16 })
      .backgroundColor('#F0F0F0')

      if (this.isLoading) {
        SkeletonList({ count: 8 }).margin({ top: 12 })
      } else if (this.isError) {
        StateView({
          type: 'error',
          title: '加载失败',
          onAction: () => this.refreshData()
        })
      } else if (this.items.length === 0) {
        StateView({
          type: 'empty',
          title: '回收站是空的',
          message: '最近删除的内容会在这里保留 30 天'
        })
      } else {
        List({ space: 12 }) {
          ForEach(this.items, (item: TrashItemDTO) => {
            ListItem() {
              this.TrashItemCard(item)
            }
          }, (item: TrashItemDTO) => `${item.type}_${item.id}`)
          
          ListItem() {
            Text('恢复合集不会捞回你单独删除的要点')
              .fontSize(12)
              .fontColor('#BBBBBB')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 20, bottom: 40 })
          }
        }
        .padding(16)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
  }

  @Builder
  TrashItemCard(item: TrashItemDTO) {
    Row() {
      Column() {
        Text(item.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        
        Row() {
          Text(item.type === 'deck' ? '合集' : '要点')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ right: 8 })
          
          Text(`还剩 ${item.remainingDays} 天`)
            .fontSize(12)
            .fontColor(item.remainingDays <= 7 ? '#E67E22' : '#999999')
        }
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 16 }) {
        Text('恢复')
          .fontSize(14)
          .fontColor('#007DFF')
          .fontWeight(FontWeight.Medium)
          .onClick(() => this.handleRestore(item))
        
        Text('彻底删除')
          .fontSize(14)
          .fontColor('#999999')
          .onClick(() => this.handleHardDelete(item))
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
  }
}
