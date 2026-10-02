import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 学习项目实体（Deck Entity）
 * 对应数据库 deck 表。
 * 
 * 术语对齐：UI 展现为「项目」，内部代码使用 Deck。
 */
export interface DeckEntity {
  id?: number;
  name: string;
  cover?: string;
  isPreset: number;
  newLimit: number;
  sortOrder: number;
  cardCount: number;
  dueCount: number;
  suspended: number;
  batchOffset: number;
  deletedAt?: number;
  lastStudiedAt?: number;
  createdAt: number;
  updatedAt: number;
}

export default class DeckDao {
  private static readonly TAG = 'DeckDao';
  private static readonly TABLE_NAME = 'deck';

  /**
   * 新建项目
   */
  async insert(store: relationalStore.RdbStore, deck: Partial<DeckEntity>): Promise<Result<number>> {
    try {
      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'name': deck.name || '',
        'cover': deck.cover || null,
        'is_preset': deck.isPreset || 0,
        'new_limit': deck.newLimit || 20,
        'sort_order': deck.sortOrder || 0,
        'card_count': 0,
        'due_count': 0,
        'suspended': 0,
        'batch_offset': 0,
        'created_at': now,
        'updated_at': now
      };
      const rowId = await store.insert(DeckDao.TABLE_NAME, valueBucket);
      return Result.success(rowId);
    } catch (e) {
      LogUtil.e(DeckDao.TAG, '插入项目失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法创建新项目');
    }
  }

  /**
   * 获取所有有效项目（未删除）
   * 按 sort_order 升序，然后按创建时间降序
   */
  async listAll(store: relationalStore.RdbStore): Promise<Result<DeckEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(DeckDao.TABLE_NAME);
      predicates
        .isNull('deleted_at')
        .orderByAsc('sort_order')
        .orderByDesc('created_at');

      const resultSet = await store.query(predicates);
      const decks = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(decks);
    } catch (e) {
      LogUtil.e(DeckDao.TAG, '查询项目列表失败: ' + JSON.stringify(e));
      return Result.success([]);
    }
  }

  /**
   * 根据 ID 查询
   */
  async queryById(store: relationalStore.RdbStore, id: number): Promise<Result<DeckEntity | null>> {
    try {
      const predicates = new relationalStore.RdbPredicates(DeckDao.TABLE_NAME);
      predicates.equalTo('id', id).isNull('deleted_at');
      const resultSet = await store.query(predicates);
      const decks = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(decks.length > 0 ? decks[0] : null);
    } catch (e) {
      LogUtil.e(DeckDao.TAG, '查询项目 ID 失败: ' + JSON.stringify(e));
      return Result.success(null);
    }
  }

  /**
   * 更新项目基本信息或冗余计数
   */
  async update(store: relationalStore.RdbStore, id: number, deck: Partial<DeckEntity>): Promise<Result<number>> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {};
      if (deck.name !== undefined) valueBucket['name'] = deck.name;
      if (deck.cover !== undefined) valueBucket['cover'] = deck.cover;
      if (deck.newLimit !== undefined) valueBucket['new_limit'] = deck.newLimit;
      if (deck.sortOrder !== undefined) valueBucket['sort_order'] = deck.sortOrder;
      if (deck.cardCount !== undefined) valueBucket['card_count'] = deck.cardCount;
      if (deck.dueCount !== undefined) valueBucket['due_count'] = deck.dueCount;
      if (deck.suspended !== undefined) valueBucket['suspended'] = deck.suspended;
      if (deck.lastStudiedAt !== undefined) valueBucket['last_studied_at'] = deck.lastStudiedAt;
      if (deck.batchOffset !== undefined) valueBucket['batch_offset'] = deck.batchOffset;
      
      valueBucket['updated_at'] = TimeUtil.now();

      const predicates = new relationalStore.RdbPredicates(DeckDao.TABLE_NAME);
      predicates.equalTo('id', id).isNull('deleted_at');
      
      const rows = await store.update(valueBucket, predicates);
      return Result.success(rows);
    } catch (e) {
      LogUtil.e(DeckDao.TAG, '更新项目失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '更新项目失败');
    }
  }

  /**
   * 软删除项目
   * 注意：业务逻辑中删除项目通常需要同时软删除其下的所有要点，
   * 该原子操作应在 DeckLifecycleService 中通过事务完成。
   */
  async softDelete(store: relationalStore.RdbStore, id: number): Promise<Result<number>> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'deleted_at': TimeUtil.now(),
        'card_count': 0, // 删除后计数归零，符合验收标准
        'due_count': 0,
        'updated_at': TimeUtil.now()
      };
      const predicates = new relationalStore.RdbPredicates(DeckDao.TABLE_NAME);
      predicates.equalTo('id', id).isNull('deleted_at');
      const rows = await store.update(valueBucket, predicates);
      return Result.success(rows);
    } catch (e) {
      LogUtil.e(DeckDao.TAG, '软删除项目失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法移除该项目');
    }
  }

  /**
   * 获取所有软删除的项目
   */
  async listDeleted(store: relationalStore.RdbStore): Promise<Result<DeckEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(DeckDao.TABLE_NAME);
      predicates
        .isNotNull('deleted_at')
        .orderByDesc('deleted_at');

      const resultSet = await store.query(predicates);
      const decks = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(decks);
    } catch (e) {
      LogUtil.e(DeckDao.TAG, '查询删除项目列表失败: ' + JSON.stringify(e));
      return Result.success([]);
    }
  }

  /**
   * 低频重算计数（从 card 表统计）
   */
  async recalcCounts(store: relationalStore.RdbStore, deckId: number, nowTs: number): Promise<Result<void>> {
    try {
      // 1. 计算总数
      const sqlTotal = `UPDATE deck SET card_count = (SELECT count(*) FROM card WHERE deck_id = ? AND deleted_at IS NULL) WHERE id = ? AND deleted_at IS NULL`;
      await store.executeSql(sqlTotal, [deckId, deckId]);

      // 2. 计算到期数
      const sqlDue = `UPDATE deck SET due_count = (SELECT count(*) FROM card WHERE deck_id = ? AND due <= ? AND suspended = 0 AND deleted_at IS NULL) WHERE id = ? AND deleted_at IS NULL`;
      await store.executeSql(sqlDue, [deckId, nowTs, deckId]);

      return Result.success(undefined);
    } catch (e) {
      LogUtil.e(DeckDao.TAG, '重算项目计数失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '重算计数失败');
    }
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): DeckEntity[] {
    const decks: DeckEntity[] = [];
    while (resultSet.goToNextRow()) {
      decks.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        name: resultSet.getString(resultSet.getColumnIndex('name')),
        cover: resultSet.getString(resultSet.getColumnIndex('cover')),
        isPreset: resultSet.getLong(resultSet.getColumnIndex('is_preset')),
        newLimit: resultSet.getLong(resultSet.getColumnIndex('new_limit')),
        sortOrder: resultSet.getLong(resultSet.getColumnIndex('sort_order')),
        cardCount: resultSet.getLong(resultSet.getColumnIndex('card_count')),
        dueCount: resultSet.getLong(resultSet.getColumnIndex('due_count')),
        suspended: resultSet.getLong(resultSet.getColumnIndex('suspended')),
        batchOffset: resultSet.getLong(resultSet.getColumnIndex('batch_offset')),
        deletedAt: resultSet.getLong(resultSet.getColumnIndex('deleted_at')),
        lastStudiedAt: resultSet.getLong(resultSet.getColumnIndex('last_studied_at')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
        updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
      });
    }
    return decks;
  }
}
