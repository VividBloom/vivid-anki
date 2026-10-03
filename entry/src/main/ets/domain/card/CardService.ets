import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import CardDao, { CardEntity } from '../../data/dao/CardDao';
import DeckDao, { DeckEntity } from '../../data/dao/DeckDao';
import { MediaService } from './MediaService';
import { DeckLifecycleService } from '../deck/DeckLifecycleService';
import { Analytics } from '../../common/utils/Analytics';
import { Result, ErrorCode } from '../../common/utils/Result';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { ParsedItem } from './CardParseService';

/**
 * 要点 DTO
 */
export interface CardDTO {
  id: number;
  front: string;
  back: string;
  cardType: string;
  extra?: string;
}

/**
 * 记忆要点业务服务
 * 
 * 职责：
 *   1. 处理要点的创建逻辑（含默认项目维护）
 *   2. 处理复杂制卡逻辑（Cloze、反向卡等）
 */
export class CardService {
  private cardDao = new CardDao();
  private deckDao = new DeckDao();
  private mediaService = new MediaService();

  /**
   * 创建新要点
   * 
   * @param ctx UI 上下文
   * @param front 正面内容
   * @param back 背面内容
   * @param options 附加选项（项目ID、类型、补充说明等）
   */
  async createCard(ctx: common.UIAbilityContext, front: string, back: string, options?: {
    deckId?: number,
    cardType?: string,
    extra?: string,
    mediaIds?: number[]
  }): Promise<Result<number>> {
    const store = await DbHelper.getInstance(ctx);
    
    return await DbHelper.inTransaction(store, async (): Promise<Result<number>> => {
      let deckId = options?.deckId;
      
      // 1. 如果没有指定项目，确保存在一个默认项目
      if (!deckId) {
        const defaultDeckResult = await this.ensureDefaultDeck(store);
        if (!defaultDeckResult.ok) {
          throw new Error('无法获取或创建默认合集');
        }
        deckId = defaultDeckResult.data;
      }

      // 2. 插入卡片
      // 检查是否是第一张卡片
      const countRes = await this.cardDao.countAll(store);
      const isFirst = countRes.ok && countRes.data === 0;

      const cardResult = await this.cardDao.insert(store, {
        deckId: deckId,
        front: front,
        back: back,
        cardType: options?.cardType || 'basic',
        extra: options?.extra,
        due: TimeUtil.now() // 新卡立即进入复习队列
      });

      if (!cardResult.ok) {
        throw new Error(cardResult.message);
      }
      
      const cardId = cardResult.data;

      // 埋点
      Analytics.logEvent(Analytics.EVENT_MANUAL_CREATE);
      if (isFirst) {
        Analytics.logEvent(Analytics.EVENT_FIRST_CARD_CREATED);
      }

      // 3. 处理媒体引用
      if (options?.mediaIds && options.mediaIds.length > 0) {
        const mediaRes = await this.mediaService.syncCardMediaRefs(store, cardId, options.mediaIds);
        if (!mediaRes.ok) throw new Error(mediaRes.message);
      }

      // 4. 更新项目的计数冗余字段
      await this.deckDao.recalcCounts(store, deckId, TimeUtil.now());

      return cardResult;
    });
  }

  /**
   * 批量创建要点
   * 
   * @param ctx UI 上下文
   * @param items 待解析出的要点列表
   * @param deckId 目标项目ID
   */
  async createCards(ctx: common.UIAbilityContext, items: ParsedItem[], deckId?: number): Promise<Result<number>> {
    const store = await DbHelper.getInstance(ctx);
    
    return await DbHelper.inTransaction(store, async (): Promise<Result<number>> => {
      let targetDeckId = deckId;
      
      // 1. 确保项目存在
      if (!targetDeckId) {
        const defaultDeckResult = await this.ensureDefaultDeck(store);
        if (!defaultDeckResult.ok) throw new Error('无法获取或创建默认合集');
        targetDeckId = defaultDeckResult.data;
      }

      const now = TimeUtil.now();
      let successCount = 0;

      // 2. 批量插入
      for (const item of items) {
        if (!item.front.trim()) continue;
        
        const res = await this.cardDao.insert(store, {
          deckId: targetDeckId,
          front: item.front,
          back: item.back,
          cardType: 'basic',
          due: now
        });
        if (res.ok) successCount++;
      }

      // 3. 统一重算计数
      await this.deckDao.recalcCounts(store, targetDeckId, now);

      return Result.success(successCount);
    });
  }

  /**
   * 搜索要点
   */
  async searchCards(ctx: common.UIAbilityContext, keyword: string): Promise<Result<CardDTO[]>> {
    const store = await DbHelper.getInstance(ctx);
    const res = await this.cardDao.search(store, keyword);
    if (res.ok) {
      return Result.success(res.data.map(c => ({
        id: c.id!,
        front: c.front,
        back: c.back,
        cardType: c.cardType,
        extra: c.extra
      })));
    }
    return Result.fail(res.message);
  }

  /**
   * 软删除要点
   */
  async softDeleteCard(ctx: common.UIAbilityContext, cardId: number): Promise<void> {
    const store = await DbHelper.getInstance(ctx);
    const lifecycleSvc = new DeckLifecycleService(store);
    await lifecycleSvc.softDeleteCard(cardId);
  }

  /**
   * 确保存在默认项目，返回其 ID
   */
  private async ensureDefaultDeck(store: relationalStore.RdbStore): Promise<Result<number>> {
    const decksResult = await this.deckDao.listAll(store);
    if (decksResult.ok && decksResult.data.length > 0) {
      // 优先寻找名为「默认合集」的项目，找不到则取第一个
      const found = decksResult.data.find((d: DeckEntity): boolean => d.name === '默认合集');
      return Result.success(found ? found.id! : decksResult.data[0].id!);
    }
    
    // 如果没有任何项目，创建一个名为「默认合集」的预设项目
    return await this.deckDao.insert(store, {
      name: '默认合集',
      isPreset: 1
    });
  }
}
