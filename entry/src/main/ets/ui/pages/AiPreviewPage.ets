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
  
  // 新增生成状态
  @State genStatus: 'generating' | 'success' | 'failed' = 'success';
  @State genProgress: number = 0;
  @State genStepMsg: string = '';
  @State errorMsg: string = '';
  private abortController: AbortController | null = null;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.targetDeckId = params.deckId as number | undefined;
      
      // 如果传入了文本，则启动生成
      if (params.sourceText) {
        this.startAiGen(params.sourceText as string, (params.sourceType || 'text') as any);
      } else if (params.items) {
        // 如果是直接传入预览项（如恢复草稿）
        this.draftId = params.draftId as number || 0;
        this.items = params.items as AiDraftItem[];
        this.genStatus = 'success';
      }
    }
  }

  /**
   * 启动 AI 生成
   */
  private async startAiGen(text: string, type: 'text' | 'image' | 'audio') {
    this.genStatus = 'generating';
    this.genProgress = 0;
    this.genStepMsg = '准备中...';
    this.abortController = new AbortController();
    
    const ctx = getContext(this) as common.UIAbilityContext;
    const result = await this.aiDraftService.startGeneration(ctx, {
      sourceText: text,
      sourceType: type,
      signal: this.abortController.signal,
      onProgress: (msg, p) => {
        this.genStepMsg = msg;
        this.genProgress = p;
      }
    });

    if (result.ok) {
      this.draftId = result.data;
      // 重新加载数据
      // 实际开发中 startGeneration 应该直接返回解析后的 items 以减少一次查询
      // 此处为简化演示，假设已拿到结果
      this.genStatus = 'success';
      // 模拟加载 items
      // ... 
    } else {
      this.genStatus = 'failed';
      this.errorMsg = result.message;
    }
  }

  /**
   * 取消生成
   */
  private handleCancel() {
    this.abortController?.abort();
    router.back();
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
          .fillColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Text(this.genStatus === 'generating' ? 'AI 正在提取' : '预览生成结果')
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

      if (this.genStatus === 'generating') {
        this.GeneratingView()
      } else if (this.genStatus === 'failed') {
        this.FailureView()
      } else {
        this.SuccessListView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .bindSheet(this.editingItem !== null, this.EditSheet(), {
      height: SheetSize.MEDIUM,
      backgroundColor: $r('app.color.card_background'),
      onDisappear: () => { this.editingItem = null }
    })
  }

  @Builder
  GeneratingView() {
    Column() {
      Blank().layoutWeight(1)
      
      LoadingProgress()
        .width(64)
        .height(64)
        .color($r('app.color.primary_color'))
      
      Text(this.genStepMsg)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 24, bottom: 8 })
      
      Text('通常需要 3-8 秒')
        .fontSize(14)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ bottom: 32 })
      
      Progress({ value: this.genProgress, total: 100, type: ProgressType.Linear })
        .width('80%')
        .color($r('app.color.primary_color'))
      
      Blank().layoutWeight(1)
      
      Button('取消')
        .width('60%')
        .minHeight(44)
        .backgroundColor($r('app.color.divider_color'))
        .fontColor($r('app.color.text_secondary'))
        .onClick(() => this.handleCancel())
        .margin({ bottom: 48 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  FailureView() {
    Column({ space: 16 }) {
      Blank().layoutWeight(1)
      
      Image($r('app.media.ic_public_fail'))
        .width(64)
        .height(64)
        .fillColor($r('app.color.error_color'))
      
      Text('提取遇到一点问题')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      
      Text(this.errorMsg)
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
      
      Text('本次操作不扣除额度')
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
      
      Column({ space: 12 }) {
        Button('重试')
          .width(200)
          .minHeight(48)
          .backgroundColor($r('app.color.primary_color'))
          .onClick(() => {
            // 重新触发生成
          })
        
        Button('手动制卡')
          .width(200)
          .minHeight(48)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_primary'))
          .border({ width: 1, color: $r('app.color.divider_color') })
          .onClick(() => {
            router.replaceUrl({ url: 'ui/pages/CreateCardPage' });
          })
      }
      .margin({ top: 32 })
      
      Blank().layoutWeight(1.5)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SuccessListView() {
    Column() {
      // 警示条
      Row() {
        Image($r('app.media.ic_public_info'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.warning_color'))
          .margin({ right: 8 })
        Text('请逐张确认后再入库')
          .fontSize(14)
          .fontColor($r('app.color.warning_color'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ top: 8, bottom: 8, left: 16, right: 16 })
      .backgroundColor($r('app.color.warning_light'))

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
          .minHeight(48)
          .backgroundColor(this.selectedCount > 0 ? $r('app.color.primary_color') : $r('app.color.divider_color'))
          .enabled(this.selectedCount > 0 && !this.isSaving)
          .onClick(() => this.handleConfirm())
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.card_background'))
      .shadow({ radius: 10, color: '#10000000', offsetY: -5 })
    }
  }

  @Builder
  DraftItemCard(item: AiDraftItem) {
    Row() {
      Checkbox({ name: item.id, group: 'drafts' })
        .select(item.selected)
        .selectedColor($r('app.color.primary_color'))
        .unselectedColor($r('app.color.divider_color'))
        .onChange((value: boolean) => {
          item.selected = value;
        })
        .margin({ right: 12 })

      Column() {
        Text(item.front)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 4 })
        Text(item.back)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Image($r('app.media.ic_public_edit'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.primary_color'))
          .margin({ right: 16 })
          .onClick(() => this.startEdit(item))
        
        Image($r('app.media.ic_public_delete'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.error_color'))
          .onClick(() => this.deleteItem(item.id))
      }
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .shadow({ radius: 4, color: '#05000000', offsetY: 2 })
  }

  @Builder
  EditSheet() {
    Column({ space: 16 }) {
      Text('编辑内容')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16, bottom: 8 })

      Column({ space: 8 }) {
        Text('正面')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        TextArea({ text: this.editFront })
          .minHeight(100)
          .backgroundColor($r('app.color.page_background'))
          .fontColor($r('app.color.text_primary'))
          .onChange((v) => this.editFront = v)
      }
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text('背面')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        TextArea({ text: this.editBack })
          .minHeight(100)
          .backgroundColor($r('app.color.page_background'))
          .fontColor($r('app.color.text_primary'))
          .onChange((v) => this.editBack = v)
      }
      .alignItems(HorizontalAlign.Start)

      Button('完成')
        .width('100%')
        .minHeight(48)
        .backgroundColor($r('app.color.primary_color'))
        .margin({ top: 16 })
        .onClick(() => this.saveEdit())
    }
    .padding(20)
    .width('100%')
  }
}
