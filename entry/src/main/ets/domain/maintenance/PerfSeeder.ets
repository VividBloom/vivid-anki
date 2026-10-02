import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import CardDao, { CardEntity } from '../../data/dao/CardDao';
import DeckDao from '../../data/dao/DeckDao';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 性能压测 seeding 工具
 */
export class PerfSeeder {
  private static readonly TAG = 'PerfSeeder';

  /**
   * 填充 5000 张测试卡片
   */
  static async seedTestData(ctx: common.UIAbilityContext, count: number = 5000): Promise<void> {
    const store = await DbHelper.getInstance(ctx);
    const cardDao = new CardDao();
    const deckDao = new DeckDao();

    await DbHelper.inTransaction(store, async () => {
      // 1. 创建一个性能测试专用项目
      const deckResult = await deckDao.insert(store, {
        name: '性能测试项目',
        sortOrder: 999
      });
      
      if (!deckResult.ok) return;
      const deckId = deckResult.data;

      const now = TimeUtil.now();
      
      // 2. 批量插入卡片
      // 注意：relationalStore 没有原生 bulkInsert，但在事务内循环插入也是高效的
      for (let i = 0; i < count; i++) {
        const dueOffset = Math.floor(Math.random() * 10) - 5; // -5 到 5 天
        await cardDao.insert(store, {
          deckId: deckId,
          front: `性能测试要点正面 ${i}`,
          back: `性能测试要点背面 ${i}`,
          due: TimeUtil.addDays(now, dueOffset),
          state: i % 2 === 0 ? 'review' : 'new',
          stability: i % 2 === 0 ? 2.5 : 0,
          difficulty: i % 2 === 0 ? 5.0 : 0
        });
      }

      // 3. 更新统计
      await deckDao.recalcCounts(store, deckId, now);
      LogUtil.i(PerfSeeder.TAG, `成功填充 ${count} 条测试数据`);
    });
  }

  /**
   * 验证索引命中情况
   */
  static async verifyIndexes(ctx: common.UIAbilityContext): Promise<string> {
    const store = await DbHelper.getInstance(ctx);
    const nowTs = TimeUtil.now();
    
    // 检查 queryDue 对应的 SQL 执行计划
    const sql = `EXPLAIN QUERY PLAN SELECT * FROM card WHERE due <= ? AND deleted_at IS NULL AND suspended = 0 ORDER BY due ASC LIMIT 20`;
    const resultSet = await store.querySql(sql, [nowTs]);
    
    let plan = '';
    while (resultSet.goToNextRow()) {
      plan += resultSet.getString(resultSet.getColumnIndex('detail')) + '\n';
    }
    resultSet.close();
    
    LogUtil.i(PerfSeeder.TAG, '查询执行计划:\n' + plan);
    return plan;
  }
}
