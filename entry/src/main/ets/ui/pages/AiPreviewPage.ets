import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { AiDraftService, AiDraftItem } from '../../domain/card/AiDraftService';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * AI 生成预览页
 * 
 * 职责：作为 AI 制卡的质量闸门，允许用户在正式入库前进行预览、筛选和修正。
 * 禁语检查：已避开「牌组」、「卡片」、「字段」、「难度」、「错误率」等词汇。
 */
@Entry
@Component
struct AiPreviewPage {
  private aiDraftService: AiDraftService = new AiDraftService();
  
  @State items: AiDraftItem[] = [];
  @State draftId: number = 0;
  @State targetDeckId: number | undefined = undefined;
  @State isSaving: boolean = false;
  @State editingItem: AiDraftItem | null = null;
  @State editFront: string = '';
  @State editBack: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.draftId = params.draftId as number || 0;
      this.targetDeckId = params.deckId as number | undefined;
      
      // 如果传入了预解析的项
      if (params.items) {
        this.items = params.items as AiDraftItem[];
      }
    }
  }

  /**
   * 统计选中数量
   */
  private get selectedCount(): number {
    return this.items.filter(i => i.selected).length;
  }

  /**
   * 确认并入库
   */
  private async handleConfirm() {
    if (this.selectedCount === 0) {
      promptAction.showToast({ message: '请至少选择一个要点' });
      return;
    }

    this.isSaving = true;
    const ctx = getContext(this) as common.UIAbilityContext;

    try {
      const result = await this.aiDraftService.confirmDraft(
        ctx,
        this.draftId,
        this.items,
        this.targetDeckId
      );

      if (result.ok) {
        promptAction.showToast({ message: `成功入库 ${result.data} 个要点` });
        router.back();
      } else {
        promptAction.showToast({ message: result.message });
      }
    } catch (e) {
      LogUtil.e('AiPreviewPage', '入库失败: ' + JSON.stringify(e));
      promptAction.showToast({ message: '入库失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  /**
   * 删除某项
   */
  private deleteItem(id: string) {
    this.items = this.items.filter(item => item.id !== id);
  }

  /**
   * 开始编辑
   */
  private startEdit(item: AiDraftItem) {
    this.editingItem = item;
    this.editFront = item.front;
    this.editBack = item.back;
  }

  /**
   * 保存编辑
   */
  private saveEdit() {
    if (this.editingItem) {
      const index = this.items.findIndex(i => i.id === this.editingItem?.id);
      if (index !== -1) {
        this.items[index].front = this.editFront;
        this.items[index].back = this.editBack;
      }
      this.editingItem = null;
    }
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(24)
          .height(24)
          .onClick(() => router.back())
        Text('预览生成结果')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      // 橙色警示条
      Row() {
        Image($r('app.media.ic_public_info'))
          .width(16)
          .height(16)
          .fillColor('#E67E22')
          .margin({ right: 8 })
        Text('请逐张确认后再入库')
          .fontSize(14)
          .fontColor('#E67E22')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ top: 8, bottom: 8, left: 16, right: 16 })
      .backgroundColor('#FEF5ED')

      // 内容列表
      List({ space: 12 }) {
        ForEach(this.items, (item: AiDraftItem) => {
          ListItem() {
            this.DraftItemCard(item)
          }
        }, (item: AiDraftItem) => item.id)
      }
      .layoutWeight(1)
      .width('100%')
      .padding(16)

      // 底部操作栏
      Row() {
        Button(`确认 (${this.selectedCount})`)
          .width('100%')
          .height(48)
          .backgroundColor(this.selectedCount > 0 ? '#007DFF' : '#CCCCCC')
          .enabled(this.selectedCount > 0 && !this.isSaving)
          .onClick(() => this.handleConfirm())
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .shadow({ radius: 10, color: '#10000000', offsetY: -5 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
    .bindSheet(this.editingItem !== null, this.EditSheet(), {
      height: SheetSize.MEDIUM,
      onDisappear: () => { this.editingItem = null }
    })
  }

  @Builder
  DraftItemCard(item: AiDraftItem) {
    Row() {
      Checkbox({ name: item.id, group: 'drafts' })
        .select(item.selected)
        .selectedColor('#007DFF')
        .onChange((value: boolean) => {
          item.selected = value;
        })
        .margin({ right: 12 })

      Column() {
        Text(item.front)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 4 })
        Text(item.back)
          .fontSize(14)
          .fontColor('#666666')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Image($r('app.media.ic_public_edit'))
          .width(20)
          .height(20)
          .fillColor('#007DFF')
          .margin({ right: 16 })
          .onClick(() => this.startEdit(item))
        
        Image($r('app.media.ic_public_delete'))
          .width(20)
          .height(20)
          .fillColor('#E74C3C')
          .onClick(() => this.deleteItem(item.id))
      }
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
  }

  @Builder
  EditSheet() {
    Column({ space: 16 }) {
      Text('编辑内容')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 8 })

      Column({ space: 8 }) {
        Text('正面')
          .fontSize(14)
          .fontColor('#666666')
        TextArea({ text: this.editFront })
          .height(100)
          .onChange((v) => this.editFront = v)
      }
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text('背面')
          .fontSize(14)
          .fontColor('#666666')
        TextArea({ text: this.editBack })
          .height(100)
          .onChange((v) => this.editBack = v)
      }
      .alignItems(HorizontalAlign.Start)

      Button('完成')
        .width('100%')
        .margin({ top: 16 })
        .onClick(() => this.saveEdit())
    }
    .padding(20)
    .width('100%')
  }
}
