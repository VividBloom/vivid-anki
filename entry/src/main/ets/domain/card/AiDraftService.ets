import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import AiDraftDao, { AiDraftEntity } from '../../data/dao/AiDraftDao';
import { CardService } from './CardService';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * AI 草稿项 (DTO)
 */
export interface AiDraftItem {
  id: string; // 临时 ID，用于 UI 列表渲染
  front: string;
  back: string;
  selected: boolean;
}

/**
 * AI 草稿详情 (DTO)
 */
export interface AiDraftDetail {
  id: number;
  items: AiDraftItem[];
}

/**
 * AI 制卡业务服务
 * 
 * 职责：
 *   1. 管理 AI 生成的草稿预览
 *   2. 执行草稿转正（写入正式卡片表）
 *   3. 确保「不确认不入库」原则
 */
export class AiDraftService {
  private aiDraftDao = new AiDraftDao();
  private cardService = new CardService();

  /**
   * 从草稿实体解析出待预览的要点列表
   */
  parseItems(draft: AiDraftEntity): AiDraftItem[] {
    if (!draft.cardsJson) return [];
    try {
      const rawItems = JSON.parse(draft.cardsJson) as { front: string, back: string }[];
      return rawItems.map((item, index) => ({
        id: `draft_${index}`,
        front: item.front,
        back: item.back,
        selected: true
      }));
    } catch (e) {
      LogUtil.e('AiDraftService', '解析 AI 草稿失败: ' + JSON.stringify(e));
      return [];
    }
  }

  /**
   * 确认并入库
   * 
   * @param ctx UI 上下文
   * @param draftId 草稿记录 ID
   * @param selectedItems 用户选中的要点列表
   * @param deckId 目标合集 ID
   */
  async confirmDraft(
    ctx: common.UIAbilityContext,
    draftId: number,
    selectedItems: AiDraftItem[],
    deckId?: number
  ): Promise<Result<number>> {
    const store = await DbHelper.getInstance(ctx);

    return await DbHelper.inTransaction(store, async (): Promise<Result<number>> => {
      // 1. 过滤出选中的项
      const confirmedItems = selectedItems.filter(item => item.selected && item.front.trim().length > 0);
      
      if (confirmedItems.length === 0) {
        return Result.failure(ErrorCode.PARAM_INVALID, '请至少选择一个有效的要点');
      }

      // 2. 调用 CardService 批量创建正式卡片
      const createResult = await this.cardService.createCards(
        ctx,
        confirmedItems.map(item => ({ front: item.front, back: item.back })),
        deckId
      );

      if (!createResult.ok) {
        throw new Error(createResult.message);
      }

      // 3. 更新草稿状态为已确认，记录保留数量
      const updateResult = await this.aiDraftDao.confirm(store, draftId, confirmedItems.length);
      if (!updateResult.ok) {
        throw new Error(updateResult.message);
      }

      return createResult;
    });
  }
}
