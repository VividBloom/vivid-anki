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

/**
 * 牌组与卡片生命周期服务层
 * 
 * 核心职责：处理合集（Deck）与要点（Card）的删除、恢复及自动清理逻辑。
 * 设计准则：
 * 1. 软删除策略：遵循 PRD 6.2 要求，所有删除操作仅标记 `deleted_at`，支持 30 天内恢复。
 * 2. 事务一致性：批量操作（如删除合集）必须在事务中完成，确保数据完整性。
 * 3. 统计解耦：删除/恢复后自动触发合集计数更新，确保 UI 层数据的实时准确。
 */
export class DeckLifecycleService {
  private store: relationalStore.RdbStore;

  /**
   * 构造函数
   * @param store 注入 RdbStore 数据库实例
   */
  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  /**
   * 软删除单张卡片（要点）
   * 
   * 逻辑说明：
   * 1. 设置 `deleted_at` 为当前时间戳。
   * 2. 显式设置 `deleted_by_deck = 0`，标记为用户独立删除，而非随合集被动删除。
   * 3. 触发所属合集的计数重算。
   * 
   * @param cardId 卡片唯一标识
   * @param nowTs 当前时间戳，缺省为系统时间
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
   * 软删除整个合集及其下属所有要点
   * 
   * 逻辑流程：
   * 1. 开启数据库事务。
   * 2. 统计当前合集内未删除的卡片总数。
   * 3. 批量更新卡片：标记 `deleted_at` 并设置 `deleted_by_deck = 1`。
   * 4. 更新合集：标记 `deleted_at` 并清空实时计数。
   * 5. 提交事务。
   * 
   * @param deckId 合集唯一标识
   * @param nowTs 当前时间戳
   * @returns 被影响（移入回收站）的卡片总数
   */
  async softDeleteDeck(deckId: number, nowTs: number = TimeUtil.now()): Promise<number> {
    return await this.runInTransaction(async () => {
      // 查询受影响的卡片数量，用于 UI 反馈
      const rs = await this.store.querySql(
        'SELECT COUNT(*) AS c FROM card WHERE deck_id = ? AND deleted_at IS NULL',
        [deckId] as Array<relationalStore.ValueType>
      );
      let affected = 0;
      if (rs.goToFirstRow()) {
        affected = rs.getLong(rs.getColumnIndex('c'));
      }
      rs.close();

      // 级联标记卡片为“随合集删除”
      await this.store.executeSql(
        'UPDATE card SET deleted_at = ?, deleted_by_deck = 1, updated_at = ? ' +
        'WHERE deck_id = ? AND deleted_at IS NULL',
        [nowTs, nowTs, deckId] as Array<relationalStore.ValueType>
      );

      // 标记合集本身已删除
      await this.store.executeSql(
        'UPDATE deck SET deleted_at = ?, card_count = 0, due_count = 0, updated_at = ? ' +
        'WHERE id = ? AND deleted_at IS NULL',
        [nowTs, nowTs, deckId] as Array<relationalStore.ValueType>
      );

      LogUtil.i('DeckLifecycle', '牌组 ' + deckId + ' 已软删，涉及卡片 ' + affected + ' 张');
      return affected;
    });
  }

  /**
   * 从回收站恢复合集
   * 
   * 核心逻辑：
   * 1. 校验合集状态：必须处于已删除状态。
   * 2. 精确匹配恢复：仅恢复那些 `deleted_at` 与合集删除时间一致且标记为 `deleted_by_deck = 1` 的卡片。
   * 3. 排除项：用户在合集删除前手动删除的卡片不会被恢复。
   * 
   * @param deckId 合集唯一标识
   * @param nowTs 当前时间戳
   * @returns 成功恢复的卡片数量
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

      // 恢复符合条件的卡片状态
      await this.store.executeSql(
        'UPDATE card SET deleted_at = NULL, deleted_by_deck = 0, updated_at = ? ' +
        'WHERE deck_id = ? AND deleted_at = ? AND deleted_by_deck = 1',
        [nowTs, deckId, deletedAt] as Array<relationalStore.ValueType>
      );

      // 恢复合集状态
      await this.store.executeSql(
        'UPDATE deck SET deleted_at = NULL, updated_at = ? WHERE id = ?',
        [nowTs, deckId] as Array<relationalStore.ValueType>
      );

      // 必须重新触发计数计算
      await this.recalcDeckCounts(deckId, nowTs);
      LogUtil.i('DeckLifecycle', '牌组 ' + deckId + ' 已恢复，卡片 ' + affected + ' 张');
      return affected;
    });
  }

  /**
   * 物理删除合集（不可逆）
   * 
   * 安全红线：物理删除仅针对已在回收站中的条目。
   * 逻辑：删除卡片记录 -> 删除合集记录。
   * 注意：复习记录 (revlog) 由于无外键约束，将永久保留以支持 FSRS 算法。
   * 
   * @param deckId 合集唯一标识
   */
  async hardDeleteDeck(deckId: number): Promise<void> {
    await this.runInTransaction(async () => {
      await this.store.executeSql(
        'DELETE FROM card WHERE deck_id = ? AND deleted_at IS NOT NULL',
        [deckId] as Array<relationalStore.ValueType>
      );
      
      await this.store.executeSql(
        'DELETE FROM deck WHERE id = ? AND deleted_at IS NOT NULL',
        [deckId] as Array<relationalStore.ValueType>
      );
      
      LogUtil.i('DeckLifecycle', '牌组 ' + deckId + ' 已彻底删除');
    });
  }

  /**
   * 从回收站恢复单张卡片
   */
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

  /**
   * 物理删除单张卡片
   */
  async hardDeleteCard(cardId: number): Promise<void> {
    await this.store.executeSql(
      'DELETE FROM card WHERE id = ? AND deleted_at IS NOT NULL',
      [cardId] as Array<relationalStore.ValueType>
    );
    LogUtil.i('DeckLifecycle', '卡片 ' + cardId + ' 已彻底删除');
  }

  /**
   * 自动清理过期数据
   * 
   * 运行机制：
   * 1. 查找所有 `deleted_at` 早于截止时间（当前 - 30天）的记录。
   * 2. 先硬删过期卡片。
   * 3. 后硬删过期合集（前提是名下已无任何存活卡片）。
   * 
   * @param nowTs 参考时间戳
   * @param retentionDays 保留天数，缺省为 30 天
   * @returns 清理结果摘要
   */
  async purgeExpired(nowTs: number = TimeUtil.now(),
                     retentionDays: number = RETENTION_DAYS): Promise<PurgeResult> {
    const cutoff = nowTs - retentionDays * 24 * 60 * 60 * 1000;

    return await this.runInTransaction(async () => {
      // 步骤 1: 清理过期卡片
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

      // 步骤 2: 清理空过期合集
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

  /**
   * 内部方法：重算合集的冗余计数（总卡片数、今日待复习数）
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

  /**
   * 事务执行包装器
   * @param fn 需在事务中执行的异步函数
   */
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
