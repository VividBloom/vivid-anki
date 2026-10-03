import { relationalStore } from '@kit.ArkData';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * AI 草稿实体（AiDraft Entity）
 * 用于存放 AI 自动生成的学习项预览，待用户确认后才转入正式表。
 */
export interface AiDraftEntity {
  id?: number;
  sourceText: string;
  sourceType: string; // 'text', 'image', 'audio'
  cardsJson?: string; // 生成的学习项 JSON 数组
  status: string; // 'pending', 'confirmed', 'discarded'
  generatedCount: number;
  keptCount: number;
  errorCode?: string;
  quotaCharged: number; // 0 或 1
  createdAt: number;
  confirmedAt?: number;
}

export default class AiDraftDao {
  private static readonly TAG = 'AiDraftDao';
  private static readonly TABLE_NAME = 'ai_draft';

  /**
   * 创建 AI 生成草稿
   */
  async insert(store: relationalStore.RdbStore, draft: Partial<AiDraftEntity>): Promise<Result<number>> {
    try {
      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'source_text': draft.sourceText || '',
        'source_type': draft.sourceType || 'text',
        'cards_json': draft.cardsJson || null,
        'status': 'pending',
        'generated_count': draft.generatedCount || 0,
        'kept_count': 0,
        'error_code': draft.errorCode || null,
        'quota_charged': draft.quotaCharged || 0,
        'created_at': now
      };
      const rowId = await store.insert(AiDraftDao.TABLE_NAME, valueBucket);
      return Result.success(rowId);
    } catch (e) {
      LogUtil.e(AiDraftDao.TAG, '创建 AI 草稿失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '无法保存 AI 生成结果');
    }
  }

  /**
   * 按 ID 查询
   */
  async queryById(store: relationalStore.RdbStore, id: number): Promise<Result<AiDraftEntity | null>> {
    try {
      const predicates = new relationalStore.RdbPredicates(AiDraftDao.TABLE_NAME);
      predicates.equalTo('id', id);
      const resultSet = await store.query(predicates);
      const list = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(list.length > 0 ? list[0] : null);
    } catch (e) {
      return Result.failure(ErrorCode.DB_QUERY, '查询 AI 草稿失败');
    }
  }

  /**
   * 确认草稿（用户选择保留某些生成项）
   * 失败或未生成时不应扣除额度，由业务层控制，此处仅负责持久化。
   */
  async confirm(store: relationalStore.RdbStore, id: number, keptCount: number): Promise<Result<void>> {
    try {
      const now = TimeUtil.now();
      const valueBucket: relationalStore.ValuesBucket = {
        'status': 'confirmed',
        'kept_count': keptCount,
        'confirmed_at': now
      };
      const predicates = new relationalStore.RdbPredicates(AiDraftDao.TABLE_NAME);
      predicates.equalTo('id', id);
      await store.update(valueBucket, predicates);
      return Result.success(undefined);
    } catch (e) {
      return Result.failure(ErrorCode.DB_WRITE, '确认 AI 生成结果失败');
    }
  }

  /**
   * 标记生成失败（不扣除额度）
   */
  async markFailed(store: relationalStore.RdbStore, id: number, errorCode: string): Promise<Result<void>> {
    try {
      const valueBucket: relationalStore.ValuesBucket = {
        'status': 'failed',
        'error_code': errorCode,
        'quota_charged': 0 // 失败强制不计费
      };
      const predicates = new relationalStore.RdbPredicates(AiDraftDao.TABLE_NAME);
      predicates.equalTo('id', id);
      await store.update(valueBucket, predicates);
      return Result.success(undefined);
    } catch (e) {
      return Result.failure(ErrorCode.DB_WRITE, '更新 AI 状态失败');
    }
  }

  /**
   * 查询最近的草稿
   */
  async queryRecent(store: relationalStore.RdbStore, limit: number): Promise<Result<AiDraftEntity[]>> {
    try {
      const predicates = new relationalStore.RdbPredicates(AiDraftDao.TABLE_NAME);
      predicates.orderByDesc('created_at').limitAs(limit);
      const resultSet = await store.query(predicates);
      const list = this.parseResultSet(resultSet);
      resultSet.close();
      return Result.success(list);
    } catch (e) {
      return Result.success([]);
    }
  }

  private parseResultSet(resultSet: relationalStore.ResultSet): AiDraftEntity[] {
    const list: AiDraftEntity[] = [];
    while (resultSet.goToNextRow()) {
      list.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        sourceText: resultSet.getString(resultSet.getColumnIndex('source_text')),
        sourceType: resultSet.getString(resultSet.getColumnIndex('source_type')),
        cardsJson: resultSet.getString(resultSet.getColumnIndex('cards_json')),
        status: resultSet.getString(resultSet.getColumnIndex('status')),
        generatedCount: resultSet.getLong(resultSet.getColumnIndex('generated_count')),
        keptCount: resultSet.getLong(resultSet.getColumnIndex('kept_count')),
        errorCode: resultSet.getString(resultSet.getColumnIndex('error_code')),
        quotaCharged: resultSet.getLong(resultSet.getColumnIndex('quota_charged')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at')),
        confirmedAt: resultSet.getLong(resultSet.getColumnIndex('confirmed_at'))
      });
    }
    return list;
  }
}
