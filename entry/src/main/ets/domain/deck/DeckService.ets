import { common } from '@kit.AbilityKit';
import { DbHelper } from '../../data/db/DbHelper';
import DeckDao from '../../data/dao/DeckDao';
import { DeckLifecycleService } from './DeckLifecycleService';
import { Result } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 合集 DTO
 */
export interface DeckDTO {
  id: number;
  name: string;
  cardCount: number;
  dueCount: number;
}

/**
 * 合集（项目）业务服务
 * 
 * 职责：
 *   1. 提供合集列表与搜索
 *   2. 管理合集基本信息
 *   术语：UI 使用「合集」，内部代码使用 Deck。
 */
export class DeckService {
  private deckDao = new DeckDao();

  /**
   * 获取所有有效合集
   */
  async getDecks(ctx: common.UIAbilityContext): Promise<DeckDTO[]> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const res = await this.deckDao.listAll(store);
      if (res.ok) {
        return res.data.map(d => ({
          id: d.id!,
          name: d.name,
          cardCount: d.cardCount,
          dueCount: d.dueCount
        }));
      }
      return [];
    } catch (e) {
      LogUtil.e('DeckService', '获取合集列表失败: ' + JSON.stringify(e));
      return [];
    }
  }

  /**
   * 搜索合集（按名称）
   */
  async searchDecks(ctx: common.UIAbilityContext, keyword: string): Promise<DeckDTO[]> {
    try {
      const allDecks = await this.getDecks(ctx);
      return allDecks.filter(d => d.name.toLowerCase().includes(keyword.toLowerCase()));
    } catch (e) {
      return [];
    }
  }

  /**
   * 创建新合集
   */
  async createDeck(ctx: common.UIAbilityContext, name: string): Promise<Result<number>> {
    const store = await DbHelper.getInstance(ctx);
    return await this.deckDao.insert(store, { name });
  }

  /**
   * 软删除合集
   */
  async softDeleteDeck(ctx: common.UIAbilityContext, deckId: number): Promise<void> {
    const store = await DbHelper.getInstance(ctx);
    const lifecycleSvc = new DeckLifecycleService(store);
    await lifecycleSvc.softDeleteDeck(deckId);
  }
}
