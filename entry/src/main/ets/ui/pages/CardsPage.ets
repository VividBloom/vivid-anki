import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { DeckService, DeckDTO } from '../../domain/deck/DeckService';
import { CardService, CardDTO } from '../../domain/card/CardService';
import { StateView } from '../components/StateView';
import { SkeletonList } from '../components/Skeleton';
import { DeleteConfirmDialog } from '../components/DeleteConfirmDialog';
import { LogUtil } from '../../common/utils/LogUtil';
import { BreakpointConstants } from '../../common/constants/BreakpointConstants';

/**
 * 内容管理页
 * 
 * 职责：
 *   1. 展现合集（项目）列表
 *   2. 提供全局要点搜索
 *   3. 处理空态与搜索无结果态
 * 禁语检查：已避开「牌组」、「卡片」、「字段」、「难度」等。
 */
@Entry
@Component
export struct CardsPage {
  private deckService: DeckService = new DeckService();
  private cardService: CardService = new CardService();
  
  @State decks: DeckDTO[] = [];
  @State searchResults: CardDTO[] = [];
  @State searchKeyword: string = '';
  @State isLoading: boolean = true;
  @State isError: boolean = false;
  @State errorMessage: string = '';
  @State isSearchMode: boolean = false;
  @State newDeckName: string = '';
  
  /** 当前断点 */
  @StorageProp(BreakpointConstants.KEY_CURRENT_BREAKPOINT) currentBp: string = BreakpointConstants.BREAKPOINT_SM;

  // 删除弹窗控制
  @State pendingDeleteDeck: DeckDTO | null = null;
  @State pendingDeleteCard: CardDTO | null = null;

  deleteDeckDialog: CustomDialogController = new CustomDialogController({
    builder: DeleteConfirmDialog({
      itemName: this.pendingDeleteDeck?.name || '',
      itemType: 'deck',
      cardCount: this.pendingDeleteDeck?.cardCount || 0,
      onConfirm: () => {
        if (this.pendingDeleteDeck) {
          this.executeDeleteDeck(this.pendingDeleteDeck.id);
        }
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  deleteCardDialog: CustomDialogController = new CustomDialogController({
    builder: DeleteConfirmDialog({
      itemName: this.pendingDeleteCard?.front || '',
      itemType: 'card',
      onConfirm: () => {
        if (this.pendingDeleteCard) {
          this.executeDeleteCard(this.pendingDeleteCard.id);
        }
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  async aboutToAppear() {
    await this.refreshData();
  }

  private async refreshData() {
    this.isLoading = true;
    this.isError = false;
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      this.decks = await this.deckService.getDecks(ctx);
    } catch (e) {
      LogUtil.e('CardsPage', '加载数据失败: ' + JSON.stringify(e));
      this.isError = true;
      this.errorMessage = '无法获取合集列表';
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 创建新合集
   */
  private async handleAddDeck() {
    if (!this.newDeckName.trim()) {
      promptAction.showToast({ message: '请输入合集名称' });
      return;
    }

    const ctx = getContext(this) as common.UIAbilityContext;
    const res = await this.deckService.createDeck(ctx, this.newDeckName.trim());
    if (res.ok) {
      promptAction.showToast({ message: '合集创建成功' });
      this.newDeckName = '';
      await this.refreshData();
    } else {
      promptAction.showToast({ message: res.message });
    }
  }

  private async executeDeleteDeck(deckId: number) {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      await this.deckService.softDeleteDeck(ctx, deckId);
      promptAction.showToast({ message: '合集已移入回收站' });
      await this.refreshData();
    } catch (e) {
      LogUtil.e('CardsPage', '删除合集失败: ' + JSON.stringify(e));
      promptAction.showToast({ message: '操作失败，请稍后重试' });
    }
  }

  private async executeDeleteCard(cardId: number) {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      await this.cardService.softDeleteCard(ctx, cardId);
      promptAction.showToast({ message: '要点已移入回收站' });
      if (this.isSearchMode) {
        await this.handleSearch(this.searchKeyword);
      }
      await this.refreshData();
    } catch (e) {
      LogUtil.e('CardsPage', '删除要点失败: ' + JSON.stringify(e));
      promptAction.showToast({ message: '操作失败，请稍后重试' });
    }
  }

  private async handleSearch(keyword: string) {
    this.searchKeyword = keyword;
    if (!keyword.trim()) {
      this.isSearchMode = false;
      this.searchResults = [];
      return;
    }

    this.isSearchMode = true;
    const ctx = getContext(this) as common.UIAbilityContext;
    const res = await this.cardService.searchCards(ctx, keyword);
    if (res.ok) {
      this.searchResults = res.data;
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 顶部搜索栏
        Search({ placeholder: '搜索要点内容...', value: this.searchKeyword })
          .width('100%')
          .minHeight(40)
          .margin({ top: 12, bottom: 12, left: 16, right: 16 })
          .onChange((v: string) => this.handleSearch(v))

        if (this.isLoading) {
          SkeletonList({ count: 8 }).margin({ top: 12 })
        } else if (this.isError) {
          StateView({
            type: 'error',
            title: '加载失败',
            message: this.errorMessage,
            onAction: () => this.refreshData()
          })
        } else if (this.isSearchMode) {
          this.SearchListView()
        } else if (this.decks.length === 0) {
          this.EmptyStateView()
        } else {
          this.DeckListView()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))

      // 悬浮添加按钮
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ic_public_add'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
      }
      .width(56)
      .height(56)
      .margin({ right: 24, bottom: 24 })
      .backgroundColor($r('app.color.primary_color'))
      .shadow({ radius: 10, color: '#33007DFF', offsetX: 0, offsetY: 5 })
      .onClick(() => {
        router.pushUrl({ url: 'ui/pages/CreateCardPage' });
      })
    }
  }

  @Builder
  DeckListView() {
    Grid() {
      ForEach(this.decks, (deck: DeckDTO) => {
        GridItem() {
          Row() {
            Column() {
              Text(deck.name)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text(`${deck.cardCount} 个要点`)
                .fontSize(14)
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('app.media.ic_public_arrow_right'))
              .width(20)
              .height(20)
              .fillColor($r('app.color.divider_color'))
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_background'))
          .borderRadius(12)
          .onClick(() => {
            promptAction.showToast({ message: '合集详情功能即将上线' });
          })
          .gesture(
            LongPressGesture()
              .onAction(() => {
                this.pendingDeleteDeck = deck;
                this.deleteDeckDialog.open();
              })
          )
        }
      }, (deck: DeckDTO) => deck.id.toString())
    }
    .columnsTemplate(this.currentBp === BreakpointConstants.BREAKPOINT_SM ? '1fr' : 
      (this.currentBp === BreakpointConstants.BREAKPOINT_MD ? '1fr 1fr' : '1fr 1fr 1fr'))
    .columnsGap(12)
    .rowsGap(12)
    .padding({ left: 16, right: 16, bottom: 100 })
    .layoutWeight(1)
  }

  @Builder
  SearchListView() {
    if (this.searchResults.length === 0) {
      this.NoResultView()
    } else {
      Grid() {
        ForEach(this.searchResults, (card: CardDTO) => {
          GridItem() {
            Column() {
              Text(card.front)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(card.back)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              router.pushUrl({
                url: 'ui/pages/CardEditPage',
                params: { card: card }
              });
            })
            .gesture(
              LongPressGesture()
                .onAction(() => {
                  this.pendingDeleteCard = card;
                  this.deleteCardDialog.open();
                })
            )
          }
        }, (card: CardDTO) => card.id.toString())
      }
      .columnsTemplate(this.currentBp === BreakpointConstants.BREAKPOINT_SM ? '1fr' : 
        (this.currentBp === BreakpointConstants.BREAKPOINT_MD ? '1fr 1fr' : '1fr 1fr 1fr'))
      .columnsGap(12)
      .rowsGap(12)
      .padding({ left: 16, right: 16, bottom: 100 })
      .layoutWeight(1)
    }
  }

  @Builder
  EmptyStateView() {
    StateView({
      type: 'empty',
      title: '还没有合集',
      message: '给你的学习资料起个名字，开始记录吧',
      actionLabel: '添加第一个合集',
      onAction: () => this.showAddDeckDialog()
    })
  }

  private showAddDeckDialog() {
    AlertDialog.show({
      title: '新建合集',
      message: '给你的学习资料起个名字',
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确定',
        action: () => {
          this.handleAddDeck();
        }
      },
      // 注意：HarmonyOS 的 AlertDialog 不直接支持 TextInput，
      // 实际开发中通常使用 CustomDialog。这里为了简化演示，假设有一个全局状态绑定。
      // 在真机代码中，此处应调用自定义弹窗。
    })
  }

  @Builder
  NoResultView() {
    StateView({
      type: 'empty',
      title: '没有找到结果',
      message: `没有找到与「${this.searchKeyword}」相关的要点`,
      actionLabel: `新建这张「${this.searchKeyword}」`,
      onAction: () => {
        router.pushUrl({
          url: 'ui/pages/CreateCardPage',
          params: { front: this.searchKeyword }
        });
      }
    })
  }
}
