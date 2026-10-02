/**
 * 牌组与卡片的生命周期（删除 / 恢复 / 清理）
 *
 * 存在意义（审查报告 N-01）：
 *   原 card.deck_id 带 ON DELETE CASCADE，而 DbHelper 已开启 PRAGMA foreign_keys，
 *   导致「删除牌组」会绕过软删除，把卡片连同复习日志一起物理删除 ——
 *   PRD 6.2 承诺的「删除后 30 天可恢复」完全失效。
 *
 * 现在的策略（方案 A）：
 *   1. 数据层去掉 CASCADE，数据库不再自动级联删除
 *   2. 删除牌组时，应用层显式把卡片置 deleted_at（软删），并标记 deleted_by_deck=1
 *   3. 到期后由 purgeExpired() 统一硬删
 *
 * 为什么不只去掉 CASCADE 就完事：
 *   那样删牌组后卡片 deck_id 会悬空，变成谁也找不到的游离卡片，
 *   比直接删掉更难解释。必须配套本文件的软删流程。
 *
 * 依赖方向：domain → common。不引用 data / ui，便于单测。
 */

import { relationalStore } from '@kit.ArkData';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/** 软删除保留期（天）。与 PRD 6.2「30 天内可恢复」一致 */
export const RETENTION_DAYS = 30;

/** 一次清理操作的产出，用于埋点与日志 */
export class PurgeResult {
  /** 硬删的卡片数 */
  deletedCards: number;
  /** 硬删的牌组数 */
  deletedDecks: number;

  constructor(deletedCards: number, deletedDecks: number) {
    this.deletedCards = deletedCards;
    this.deletedDecks = deletedDecks;
  }
}

export class DeckLifecycleService {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  // ============================================================
  // 删除
  // ============================================================

  /**
   * 软删单张卡片（用户主动删除）。
   *
   * 必须显式写 deleted_by_deck = 0：这样它在将来「恢复牌组」时不会被误恢复。
   */
  async softDeleteCard(cardId: number, nowTs: number = TimeUtil.now()): Promise<void> {
    await this.store.executeSql(
      'UPDATE card SET deleted_at = ?, deleted_by_deck = 0, updated_at = ? ' +
      'WHERE id = ? AND deleted_at IS NULL',
      [nowTs, nowTs, cardId] as Array<relationalStore.ValueType>
    );
    const deckId = await this.findDeckIdOfCard(cardId);
    if (deckId > 0) {
      await this.recalcDeckCounts(deckId, nowTs);
    }
  }

  /**
   * 软删整个牌组：牌组自身与其下所有卡片一并进入 30 天可恢复状态。
   *
   * 事务内完成，任一步失败整体回滚，不会出现「牌组没了但卡片还在」的中间态。
   *
   * @returns 被软删的卡片数（用于结果页文案，例如「已移到回收站，30 天内可恢复」）
   */
  async softDeleteDeck(deckId: number, nowTs: number = TimeUtil.now()): Promise<number> {
    return await this.runInTransaction(async () => {
      // 只软删尚未删除的卡片；已单独删除的卡片不改动，
      // 避免把用户主动删除的记录也标成「随牌组删除」。
      const rs = await this.store.querySql(
        'SELECT COUNT(*) AS c FROM card WHERE deck_id = ? AND deleted_at IS NULL',
        [deckId] as Array<relationalStore.ValueType>
      );
      let affected = 0;
      if (rs.goToFirstRow()) {
        affected = rs.getLong(rs.getColumnIndex('c'));
      }
      rs.close();

      await this.store.executeSql(
        'UPDATE card SET deleted_at = ?, deleted_by_deck = 1, updated_at = ? ' +
        'WHERE deck_id = ? AND deleted_at IS NULL',
        [nowTs, nowTs, deckId] as Array<relationalStore.ValueType>
      );

      await this.store.executeSql(
        'UPDATE deck SET deleted_at = ?, card_count = 0, due_count = 0, updated_at = ? ' +
        'WHERE id = ? AND deleted_at IS NULL',
        [nowTs, nowTs, deckId] as Array<relationalStore.ValueType>
      );

      LogUtil.i('DeckLifecycle', '牌组 ' + deckId + ' 已软删，涉及卡片 ' + affected + ' 张');
      return affected;
    });
  }

  // ============================================================
  // 恢复
  // ============================================================

  /**
   * 恢复牌组。
   *
   * 只恢复 deleted_by_deck = 1 且 deleted_at 等于牌组删除时刻的卡片 ——
   * 这两个条件缺一不可：
   *   · deleted_by_deck=1 排除用户主动删除的卡片（那不该被牌组恢复捞回来）
   *   · deleted_at 相等排除「恢复后又单独删除」的旧记录
   */
  async restoreDeck(deckId: number, nowTs: number = TimeUtil.now()): Promise<number> {
    return await this.runInTransaction(async () => {
      const deletedAt = await this.getDeckDeletedAt(deckId);
      if (deletedAt <= 0) {
        LogUtil.w('DeckLifecycle', '牌组 ' + deckId + ' 未处于删除态，跳过恢复');
        return 0;
      }

      const rs = await this.store.querySql(
        'SELECT COUNT(*) AS c FROM card ' +
        'WHERE deck_id = ? AND deleted_at = ? AND deleted_by_deck = 1',
        [deckId, deletedAt] as Array<relationalStore.ValueType>
      );
      let affected = 0;
      if (rs.goToFirstRow()) {
        affected = rs.getLong(rs.getColumnIndex('c'));
      }
      rs.close();

      await this.store.executeSql(
        'UPDATE card SET deleted_at = NULL, deleted_by_deck = 0, updated_at = ? ' +
        'WHERE deck_id = ? AND deleted_at = ? AND deleted_by_deck = 1',
        [nowTs, deckId, deletedAt] as Array<relationalStore.ValueType>
      );

      await this.store.executeSql(
        'UPDATE deck SET deleted_at = NULL, updated_at = ? WHERE id = ?',
        [nowTs, deckId] as Array<relationalStore.ValueType>
      );

      await this.recalcDeckCounts(deckId, nowTs);
      LogUtil.i('DeckLifecycle', '牌组 ' + deckId + ' 已恢复，卡片 ' + affected + ' 张');
      return affected;
    });
  }

  /** 恢复单张卡片（不论来源） */
  async restoreCard(cardId: number, nowTs: number = TimeUtil.now()): Promise<void> {
    await this.store.executeSql(
      'UPDATE card SET deleted_at = NULL, deleted_by_deck = 0, updated_at = ? ' +
      'WHERE id = ? AND deleted_at IS NOT NULL',
      [nowTs, cardId] as Array<relationalStore.ValueType>
    );
    const deckId = await this.findDeckIdOfCard(cardId);
    if (deckId > 0) {
      await this.recalcDeckCounts(deckId, nowTs);
    }
  }

  // ============================================================
  // 清理
  // ============================================================

  /**
   * 清理超过保留期的软删数据。建议启动时调用一次。
   *
   * 顺序不能颠倒：
   *   1. 先硬删过期卡片（revlog 无外键，会完整保留，不影响 FSRS 训练）
   *   2. 再硬删过期且「名下已无任何卡片」的牌组
   *
   * 第 2 步的 COUNT(*)=0 是硬约束：若牌组下还有未过期的软删卡片就删牌组，
   * 那些卡片将来恢复时会失去归属，变成游离卡片。
   */
  async purgeExpired(nowTs: number = TimeUtil.now(),
                     retentionDays: number = RETENTION_DAYS): Promise<PurgeResult> {
    const cutoff = nowTs - retentionDays * 24 * 60 * 60 * 1000;

    return await this.runInTransaction(async () => {
      // 1) 过期卡片
      const rs1 = await this.store.querySql(
        'SELECT COUNT(*) AS c FROM card WHERE deleted_at IS NOT NULL AND deleted_at < ?',
        [cutoff] as Array<relationalStore.ValueType>
      );
      let cardCount = 0;
      if (rs1.goToFirstRow()) {
        cardCount = rs1.getLong(rs1.getColumnIndex('c'));
      }
      rs1.close();

      await this.store.executeSql(
        'DELETE FROM card WHERE deleted_at IS NOT NULL AND deleted_at < ?',
        [cutoff] as Array<relationalStore.ValueType>
      );

      // 2) 过期牌组，且名下无任何卡片
      const rs2 = await this.store.querySql(
        'SELECT COUNT(*) AS c FROM deck d ' +
        'WHERE d.deleted_at IS NOT NULL AND d.deleted_at < ? ' +
        'AND NOT EXISTS (SELECT 1 FROM card c WHERE c.deck_id = d.id)',
        [cutoff] as Array<relationalStore.ValueType>
      );
      let deckCount = 0;
      if (rs2.goToFirstRow()) {
        deckCount = rs2.getLong(rs2.getColumnIndex('c'));
      }
      rs2.close();

      // 注意：SQLite 的 DELETE 不支持表别名（DELETE FROM deck d 会语法错误），
      // 因此外层不加别名，相关子查询里直接用 deck.id 引用外层表。
      await this.store.executeSql(
        'DELETE FROM deck ' +
        'WHERE deleted_at IS NOT NULL AND deleted_at < ? ' +
        'AND NOT EXISTS (SELECT 1 FROM card c WHERE c.deck_id = deck.id)',
        [cutoff] as Array<relationalStore.ValueType>
      );

      if (cardCount > 0 || deckCount > 0) {
        LogUtil.i('DeckLifecycle', '清理完成：卡片 ' + cardCount + ' 张，牌组 ' + deckCount + ' 个');
      }
      return new PurgeResult(cardCount, deckCount);
    });
  }

  // ============================================================
  // 内部工具
  // ============================================================

  /**
   * 重算牌组的冗余计数。
   *
   * 这里用 COUNT 是刻意的：删除 / 恢复是低频操作，
   * 用 COUNT 重算比手动加减更不容易漂移。
   * PRD 禁止的是「列表页每次渲染都 COUNT」，与本方法不冲突。
   */
  private async recalcDeckCounts(deckId: number, nowTs: number): Promise<void> {
    await this.store.executeSql(
      'UPDATE deck SET ' +
      '  card_count = (SELECT COUNT(*) FROM card ' +
      '                WHERE deck_id = ? AND deleted_at IS NULL), ' +
      '  due_count  = (SELECT COUNT(*) FROM card ' +
      '                WHERE deck_id = ? AND deleted_at IS NULL ' +
      '                AND suspended = 0 AND state <> \'new\' AND due <= ?), ' +
      '  updated_at = ? ' +
      'WHERE id = ? AND deleted_at IS NULL',
      [deckId, deckId, nowTs, nowTs, deckId] as Array<relationalStore.ValueType>
    );
  }

  private async getDeckDeletedAt(deckId: number): Promise<number> {
    const rs = await this.store.querySql(
      'SELECT deleted_at FROM deck WHERE id = ?',
      [deckId] as Array<relationalStore.ValueType>
    );
    let v = 0;
    if (rs.goToFirstRow()) {
      const idx = rs.getColumnIndex('deleted_at');
      if (!rs.isColumnNull(idx)) {
        v = rs.getLong(idx);
      }
    }
    rs.close();
    return v;
  }

  private async findDeckIdOfCard(cardId: number): Promise<number> {
    const rs = await this.store.querySql(
      'SELECT deck_id FROM card WHERE id = ?',
      [cardId] as Array<relationalStore.ValueType>
    );
    let v = 0;
    if (rs.goToFirstRow()) {
      v = rs.getLong(rs.getColumnIndex('deck_id'));
    }
    rs.close();
    return v;
  }

  private async runInTransaction<T>(fn: () => Promise<T>): Promise<T> {
    await this.store.beginTransaction();
    try {
      const r = await fn();
      await this.store.commit();
      return r;
    } catch (e) {
      await this.store.rollBack();
      LogUtil.e('DeckLifecycle', '事务回滚: ' + JSON.stringify(e as object));
      throw new Error(JSON.stringify(e as object));
    }
  }
}
