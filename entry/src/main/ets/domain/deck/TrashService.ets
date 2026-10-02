import { common } from '@kit.AbilityKit';
import { DbHelper } from '../../data/db/DbHelper';
import DeckDao from '../../data/dao/DeckDao';
import CardDao from '../../data/dao/CardDao';
import { DeckLifecycleService, RETENTION_DAYS } from './DeckLifecycleService';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 回收站项目 DTO
 */
export interface TrashItemDTO {
  id: number;
  name: string;
  type: 'deck' | 'card';
  deletedAt: number;
  remainingDays: number;
}

/**
 * 回收站业务服务
 * 
 * 职责：
 *   1. 查询 30 天内可恢复的合集与要点
 *   2. 执行恢复与彻底删除操作
 */
export class TrashService {
  private static readonly TAG = 'TrashService';
  private deckDao = new DeckDao();
  private cardDao = new CardDao();

  /**
   * 获取回收站列表，按剩余天数分组
   */
  async getTrashItems(ctx: common.UIAbilityContext): Promise<TrashItemDTO[]> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const now = TimeUtil.now();
      
      // 1. 获取已删除合集
      const decksRes = await this.deckDao.listDeleted(store);
      const deckItems: TrashItemDTO[] = (decksRes.data || []).map(d => ({
        id: d.id!,
        name: d.name,
        type: 'deck',
        deletedAt: d.deletedAt!,
        remainingDays: this.calculateRemainingDays(d.deletedAt!, now)
      }));

      // 2. 获取独立删除的要点
      const cardsRes = await this.cardDao.listDeletedIndividually(store);
      const cardItems: TrashItemDTO[] = (cardsRes.data || []).map(c => ({
        id: c.id!,
        name: c.front,
        type: 'card',
        deletedAt: c.deletedAt!,
        remainingDays: this.calculateRemainingDays(c.deletedAt!, now)
      }));

      // 合并并按删除时间降序排列
      return [...deckItems, ...cardItems].sort((a, b) => b.deletedAt - a.deletedAt);
    } catch (e) {
      LogUtil.e(TrashService.TAG, '获取回收站列表失败: ' + JSON.stringify(e));
      return [];
    }
  }

  /**
   * 恢复项目
   */
  async restoreItem(ctx: common.UIAbilityContext, id: number, type: 'deck' | 'card'): Promise<boolean> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const lifecycleSvc = new DeckLifecycleService(store);
      
      if (type === 'deck') {
        await lifecycleSvc.restoreDeck(id);
      } else {
        await lifecycleSvc.restoreCard(id);
      }
      return true;
    } catch (e) {
      LogUtil.e(TrashService.TAG, '恢复项目失败: ' + JSON.stringify(e));
      return false;
    }
  }

  /**
   * 彻底删除项目
   */
  async hardDeleteItem(ctx: common.UIAbilityContext, id: number, type: 'deck' | 'card'): Promise<boolean> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const lifecycleSvc = new DeckLifecycleService(store);
      
      if (type === 'deck') {
        await lifecycleSvc.hardDeleteDeck(id);
      } else {
        await lifecycleSvc.hardDeleteCard(id);
      }
      return true;
    } catch (e) {
      LogUtil.e(TrashService.TAG, '彻底删除失败: ' + JSON.stringify(e));
      return false;
    }
  }

  private calculateRemainingDays(deletedAt: number, now: number): number {
    const elapsedMs = now - deletedAt;
    const elapsedDays = Math.floor(elapsedMs / (24 * 60 * 60 * 1000));
    return Math.max(0, RETENTION_DAYS - elapsedDays);
  }
}
