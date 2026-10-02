import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import CardDao from '../../data/dao/CardDao';
import RevlogDao from '../../data/dao/RevlogDao';
import DailyStatsDao from '../../data/dao/DailyStatsDao';
import { LogUtil } from '../../common/utils/LogUtil';
import { Result, ErrorCode } from '../../common/utils/Result';
import { Rating } from '../scheduler/FsrsScheduler';
import { TimeUtil } from '../../common/utils/TimeUtil';

/**
 * 撤销服务
 * 
 * 职责：
 *   1. 查找最近的可撤销记录
 *   2. 执行回滚事务（恢复卡片状态、软删日志、更新统计）
 */
export class UndoService {
  private static readonly TAG = 'UndoService';
  private cardDao: CardDao = new CardDao();
  private revlogDao: RevlogDao = new RevlogDao();
  private statsDao: DailyStatsDao = new DailyStatsDao();

  /**
   * 撤销最后一次评分
   * 
   * @param ctx UI 上下文
   * @param cardId 可选，如果指定则撤销该卡片的最后一次；如果不传，则全局撤销最后一次有效复习（TODO）
   * 本实现聚焦于当前正在复习的卡片撤销。
   */
  async undo(ctx: common.UIAbilityContext, cardId: number): Promise<Result<void>> {
    try {
      const store = await DbHelper.getInstance(ctx);

      // 1. 找最后一条有效日志
      const lastLogResult = await this.revlogDao.findLastValid(store, cardId);
      if (!lastLogResult.ok || !lastLogResult.data) {
        return Result.failure(ErrorCode.NOT_FOUND, '找不到可撤销的记录');
      }
      const log = lastLogResult.data;

      // 2. 开启事务回滚
      return await DbHelper.inTransaction(store, async () => {
        // A. 回滚卡片状态到 before
        const rollbackResult = await this.cardDao.update(store, cardId, {
          stability: log.stabilityBefore,
          difficulty: log.difficultyBefore,
          due: log.intervalBefore ? TimeUtil.addDays(log.reviewedAt, -log.intervalBefore) : TimeUtil.now(), // 粗略回滚 due
          reps: log.repsBefore,
          lapses: log.lapsesBefore,
          state: log.stateBefore,
          lastReview: log.intervalBefore ? log.reviewedAt - (log.intervalBefore * 24 * 60 * 60 * 1000) : undefined
        });
        
        if (!rollbackResult.ok) throw new Error('回滚卡片失败');

        // B. 软删除复习日志
        const deleteLogResult = await this.revlogDao.softDelete(store, log.id!);
        if (!deleteLogResult.ok) throw new Error('软删日志失败');

        // C. 扣减每日统计，并增加撤销计数
        const statsResult = await this.statsDao.increment(store, {
          reviewCount: -1,
          newCount: log.repsBefore === 0 ? -1 : 0,
          correctCount: log.rating >= Rating.Good ? -1 : 0,
          durationMs: -(log.durationMs || 0),
          undoCount: 1
        });
        if (!statsResult.ok) throw new Error('更新统计失败');

        return Result.success(undefined);
      });
    } catch (e) {
      LogUtil.e(UndoService.TAG, '撤销操作失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.UNKNOWN, '撤销失败');
    }
  }
}
