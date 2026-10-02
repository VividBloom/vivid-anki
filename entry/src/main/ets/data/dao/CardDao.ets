import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { QueueCard } from '../../common/types/ReviewTypes';

/**
 * 记忆要点实体（Card Entity）
 * 对应数据库 card 表，严格遵循 Schema.ets 定义。
 * 
 * 术语对齐：此处内部使用 Card，但 UI 统一展现为「要点」或「学习项」。
 */
export interface CardEntity {
  id?: number;
  deckId: number;
  cardType: string;
  front: string;
  back: string;
  extra?: string;
  mediaRefs?: string;
  source: string;
  sourceRef?: string;
  state: string;
  stability: number;
  difficulty: number;
  due: number;
  lastReview?: number;
  reps: number;
  lapses: number;
  lastRevlogId?: number;
  suspended: number;
  deletedAt?: number;
  deletedByDeck: number;
  createdAt: number;
  updatedAt: number;
}

export default class CardDao {
  private static readonly TAG = 'CardDao';
  private static readonly TABLE_NAME = 'card';

  /**
   * 插入新要点
   * 默认状态为 'new'，稳定性与难度为 0。
   */
  async insert(store: relationalStore.RdbStore, card: Partial<CardEntity>): Promise<Result<number>> {
    try {
      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'deck_id': card.deckId,
        'card_type': card.cardType || 'basic',
        'front': card.front,
        'back': card.back,
        'extra': card.extra || null,
        'media_refs': card.mediaRefs || null,
        'source': card.source || 'manual',
        'source_ref': card.sourceRef || null,
        'state': 'new',
        'stability': 0,
        'difficulty': 0,
        'due': card.due || 0,
        'reps': 0,
        'lapses': 0,
        'suspended': 0,
        'deleted_by_deck': 0,
        'created_at': now,
        'updated_at': now
      };
      const rowId = await store.insert(CardDao.TABLE_NAME, valueBucket);
      return Result.success(rowId);
    } catch (e) {
      LogUtil.e(CardDao.TAG, '插入失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法保存新的学习要点');
    }
  }

  /**
   * 查找到期要点
   * 必须命中 idx_card_due (due) WHERE deleted_at IS NULL
   */
  async queryDue(store: relationalStore.RdbStore, nowTs: number, limit: number): Promise<Result<CardEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      predicates
        .lessThanOrEqualTo('due', nowTs)
        .isNull('deleted_at')
        .equalTo('suspended', 0)
        .orderByAsc('due')
        .limitAs(limit);

      const resultSet = await store.query(predicates);
      const cards = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(cards);
    } catch (e) {
      LogUtil.e(CardDao.TAG, '查询到期要点失败: ' + JSON.stringify(e));
      return Result.success([]); // 失败返回空列表，不中断主流程
    }
  }

  /**
   * 查找复习候选集（含到期卡与新卡）
   * 
   * @param tomorrowTs 次日零点时间戳
   * @param newLimit   新卡上限（防止一次性拉取过多新卡）
   */
  async queryReviewCandidates(store: relationalStore.RdbStore, tomorrowTs: number, newLimit: number): Promise<Result<CardEntity[]>> {
    try {
      // 1. 获取到期卡（无上限限制，由 ReviewQueue 内部做 reviewLimit 截断）
      const duePredicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      duePredicates
        .isNull('deleted_at')
        .equalTo('suspended', 0)
        .notEqualTo('state', 'new')
        .lessThan('due', tomorrowTs)
        .orderByAsc('due');
      
      const dueResultSet = await store.query(duePredicates);
      const dueCards = this.parseResultSet(dueResultSet);
      dueResultSet.close();

      // 2. 获取新卡（受 newLimit 约束）
      const newPredicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      newPredicates
        .isNull('deleted_at')
        .equalTo('suspended', 0)
        .equalTo('state', 'new')
        .orderByAsc('id') // 按创建顺序
        .limitAs(newLimit);
      
      const newResultSet = await store.query(newPredicates);
      const newCards = this.parseResultSet(newResultSet);
      newResultSet.close();

      return Result.success(dueCards.concat(newCards));
    } catch (e) {
      LogUtil.e(CardDao.TAG, '查询复习候选集失败: ' + JSON.stringify(e));
      return Result.success([]);
    }
  }

  /**
   * 获取指定项目下的所有有效要点
   */
  async queryByDeck(store: relationalStore.RdbStore, deckId: number): Promise<Result<CardEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      predicates
        .equalTo('deck_id', deckId)
        .isNull('deleted_at')
        .orderByDesc('created_at');

      const resultSet = await store.query(predicates);
      const cards = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(cards);
    } catch (e) {
      LogUtil.e(CardDao.TAG, '查询项目要点失败: ' + JSON.stringify(e));
      return Result.success([]);
    }
  }

  /**
   * 根据 ID 查询
   */
  async queryById(store: relationalStore.RdbStore, id: number): Promise<Result<CardEntity | null>> {
    try {
      const predicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      predicates.equalTo('id', id).isNull('deleted_at');
      const resultSet = await store.query(predicates);
      const cards = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(cards.length > 0 ? cards[0] : null);
    } catch (e) {
      LogUtil.e(CardDao.TAG, '查询 ID 失败: ' + JSON.stringify(e));
      return Result.success(null);
    }
  }

  /**
   * 更新要点
   * 自动同步 updated_at
   */
  async update(store: relationalStore.RdbStore, id: number, card: Partial<CardEntity>): Promise<Result<number>> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {};
      if (card.deckId !== undefined) valueBucket['deck_id'] = card.deckId;
      if (card.front !== undefined) valueBucket['front'] = card.front;
      if (card.back !== undefined) valueBucket['back'] = card.back;
      if (card.extra !== undefined) valueBucket['extra'] = card.extra;
      if (card.state !== undefined) valueBucket['state'] = card.state;
      if (card.stability !== undefined) valueBucket['stability'] = card.stability;
      if (card.difficulty !== undefined) valueBucket['difficulty'] = card.difficulty;
      if (card.due !== undefined) valueBucket['due'] = card.due;
      if (card.lastReview !== undefined) valueBucket['last_review'] = card.lastReview;
      if (card.reps !== undefined) valueBucket['reps'] = card.reps;
      if (card.lapses !== undefined) valueBucket['lapses'] = card.lapses;
      if (card.lastRevlogId !== undefined) valueBucket['last_revlog_id'] = card.lastRevlogId;
      if (card.suspended !== undefined) valueBucket['suspended'] = card.suspended;
      
      valueBucket['updated_at'] = TimeUtil.now();

      const predicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      predicates.equalTo('id', id);
      
      const rows = await store.update(valueBucket, predicates);
      return Result.success(rows);
    } catch (e) {
      LogUtil.e(CardDao.TAG, '更新失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '更新保存失败');
    }
  }

  /**
   * 软删除要点
   * 置 deleted_at，30 天内可恢复
   */
  async softDelete(store: relationalStore.RdbStore, id: number): Promise<Result<number>> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'deleted_at': TimeUtil.now(),
        'deleted_by_deck': 0,
        'updated_at': TimeUtil.now()
      };
      const predicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      predicates.equalTo('id', id);
      const rows = await store.update(valueBucket, predicates);
      return Result.success(rows);
    } catch (e) {
      LogUtil.e(CardDao.TAG, '软删除失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法移除该要点');
    }
  }

  /**
   * 统计项目下的有效要点数
   */
  async countByDeck(store: relationalStore.RdbStore, deckId: number): Promise<Result<number>> {
    try {
      const predicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      predicates.equalTo('deck_id', deckId).isNull('deleted_at');
      const resultSet = await store.query(predicates);
      const count = resultSet.rowCount;
      resultSet.close();
      return Result.success(count);
    } catch (e) {
      return Result.success(0);
    }
  }

  /**
   * 查找复习候选集（轻量级，仅返回队列所需字段，以应对大数据量性能要求）
   * 
   * @param tomorrowTs 次日零点时间戳
   * @param newLimit   新卡上限
   */
  async queryReviewQueueCandidates(store: relationalStore.RdbStore, tomorrowTs: number, newLimit: number): Promise<Result<QueueCard[]>> {
    try {
      // 分两步查询，确保每一路都能命中索引且避免 OR 带来的性能抖动
      const cards: QueueCard[] = [];

      // 1. 获取到期卡
      const dueSql = `
        SELECT id, deck_id, state, stability, difficulty, last_review, due 
        FROM card 
        WHERE deleted_at IS NULL AND suspended = 0 AND state != 'new' AND due < ?
        ORDER BY due ASC
      `;
      const dueResultSet = await store.querySql(dueSql, [tomorrowTs]);
      while (dueResultSet.goToNextRow()) {
        cards.push(this.parseQueueCard(dueResultSet));
      }
      dueResultSet.close();

      // 2. 获取新卡
      const newSql = `
        SELECT id, deck_id, state, stability, difficulty, last_review, due 
        FROM card 
        WHERE deleted_at IS NULL AND suspended = 0 AND state = 'new'
        ORDER BY id ASC
        LIMIT ?
      `;
      const newResultSet = await store.querySql(newSql, [newLimit]);
      while (newResultSet.goToNextRow()) {
        cards.push(this.parseQueueCard(newResultSet));
      }
      newResultSet.close();

      return Result.success(cards);
    } catch (e) {
      LogUtil.e(CardDao.TAG, '查询复习队列候选集失败: ' + JSON.stringify(e));
      return Result.success([]);
    }
  }

  /**
   * 统计指定时间段内的到期要点数
   */
  async countDueInRange(store: relationalStore.RdbStore, startTs: number, endTs: number): Promise<Result<number>> {
    try {
      const predicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      predicates
        .greaterThanOrEqualTo('due', startTs)
        .lessThan('due', endTs)
        .isNull('deleted_at')
        .equalTo('suspended', 0);
      
      const resultSet = await store.query(predicates);
      const count = resultSet.rowCount;
      resultSet.close();
      return Result.success(count);
    } catch (e) {
      LogUtil.e(CardDao.TAG, '统计到期数失败: ' + JSON.stringify(e));
      return Result.success(0);
    }
  }

  /**
   * 搜索要点
   */
  async search(store: relationalStore.RdbStore, keyword: string): Promise<Result<CardEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(CardDao.TABLE_NAME);
      predicates
        .isNull('deleted_at')
        .beginWrap()
        .like('front', `%${keyword}%`)
        .or()
        .like('back', `%${keyword}%`)
        .endWrap()
        .orderByDesc('updated_at');

      const resultSet = await store.query(predicates);
      const cards = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(cards);
    } catch (e) {
      LogUtil.e(CardDao.TAG, '搜索失败: ' + JSON.stringify(e));
      return Result.success([]);
    }
  }

  private parseQueueCard(resultSet: relationalStore.ResultSet): QueueCard {
    const state = resultSet.getString(resultSet.getColumnIndex('state'));
    return {
      id: resultSet.getLong(resultSet.getColumnIndex('id')),
      deckId: resultSet.getLong(resultSet.getColumnIndex('deck_id')),
      isNew: state === 'new',
      stability: resultSet.getDouble(resultSet.getColumnIndex('stability')),
      difficulty: resultSet.getDouble(resultSet.getColumnIndex('difficulty')),
      lastReview: resultSet.getLong(resultSet.getColumnIndex('last_review')),
      due: resultSet.getLong(resultSet.getColumnIndex('due'))
    };
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): CardEntity[] {
    const cards: CardEntity[] = [];
    while (resultSet.goToNextRow()) {
      cards.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        deckId: resultSet.getLong(resultSet.getColumnIndex('deck_id')),
        cardType: resultSet.getString(resultSet.getColumnIndex('card_type')),
        front: resultSet.getString(resultSet.getColumnIndex('front')),
        back: resultSet.getString(resultSet.getColumnIndex('back')),
        extra: resultSet.getString(resultSet.getColumnIndex('extra')),
        mediaRefs: resultSet.getString(resultSet.getColumnIndex('media_refs')),
        source: resultSet.getString(resultSet.getColumnIndex('source')),
        sourceRef: resultSet.getString(resultSet.getColumnIndex('source_ref')),
        state: resultSet.getString(resultSet.getColumnIndex('state')),
        stability: resultSet.getDouble(resultSet.getColumnIndex('stability')),
        difficulty: resultSet.getDouble(resultSet.getColumnIndex('difficulty')),
        due: resultSet.getLong(resultSet.getColumnIndex('due')),
        lastReview: resultSet.getLong(resultSet.getColumnIndex('last_review')),
        reps: resultSet.getLong(resultSet.getColumnIndex('reps')),
        lapses: resultSet.getLong(resultSet.getColumnIndex('lapses')),
        lastRevlogId: resultSet.getLong(resultSet.getColumnIndex('last_revlog_id')),
        suspended: resultSet.getLong(resultSet.getColumnIndex('suspended')),
        deletedAt: resultSet.getLong(resultSet.getColumnIndex('deleted_at')),
        deletedByDeck: resultSet.getLong(resultSet.getColumnIndex('deleted_by_deck')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
        updatedAt: resultSet.getLong(resultSet.getColumnIndex('updated_at'))
      });
    }
    return cards;
  }
}
