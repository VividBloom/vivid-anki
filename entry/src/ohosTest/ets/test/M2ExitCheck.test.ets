import { describe, it, expect } from '@ohos/hypium';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../main/ets/data/db/DbHelper';
import CardDao from '../../main/ets/data/dao/CardDao';
import RevlogDao from '../../main/ets/data/dao/RevlogDao';
import DailyStatsDao from '../../main/ets/data/dao/DailyStatsDao';
import { ReviewService } from '../../main/ets/domain/review/ReviewService';
import { Rating } from '../../main/ets/domain/scheduler/FsrsScheduler';
import { LogUtil } from '../../main/ets/common/utils/LogUtil';
import { TimeUtil } from '../../main/ets/common/utils/TimeUtil';

export default function m2ExitCheck() {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const context = delegator.getAppContext();
  const TAG = 'M2ExitCheck';

  describe('M2ExitCheck', () => {
    it('M2_核心全链路验证_数据持久化与调度', 0, async () => {
      LogUtil.i(TAG, '>>> 开始 M2 出口检查');
      const startAll = Date.now();

      // 1. 建库与环境清理
      LogUtil.i(TAG, '步骤 1: 初始化数据库并清理旧数据');
      const store = await DbHelper.getInstance(context);
      await store.executeSql('DELETE FROM card');
      await store.executeSql('DELETE FROM revlog');
      await store.executeSql('DELETE FROM daily_stats');
      
      const cardDao = new CardDao();
      const revlogDao = new RevlogDao();
      const statsDao = new DailyStatsDao();
      const reviewService = new ReviewService();

      // 2. 插 3 张假卡
      LogUtil.i(TAG, '步骤 2: 插入 3 张测试卡片');
      const c1Id = (await cardDao.insert(store, { deckId: 1, front: 'M2-Front-1', back: 'Back-1' })).data!;
      const c2Id = (await cardDao.insert(store, { deckId: 1, front: 'M2-Front-2', back: 'Back-2' })).data!;
      const c3Id = (await cardDao.insert(store, { deckId: 1, front: 'M2-Front-3', back: 'Back-3' })).data!;
      expect(c1Id > 0 && c2Id > 0 && c3Id > 0).assertTrue();

      // 3. 模拟复习翻卡评分
      LogUtil.i(TAG, '步骤 3: 模拟复习评分 (Card 1 -> Good)');
      const rateStart = Date.now();
      const rateSuccess = await reviewService.rateCard(context, c1Id, Rating.Good, 5000);
      expect(rateSuccess).assertTrue();
      const rateDuration = Date.now() - rateStart;
      LogUtil.i(TAG, `评分操作耗时: ${rateDuration}ms`);

      // 4. 验证数据变更 (杀进程重进模拟)
      LogUtil.i(TAG, '步骤 4: 验证持久化数据 (模拟重启后查询)');
      
      // A. 验证卡片状态更新
      const c1After = (await cardDao.queryById(store, c1Id)).data!;
      expect(c1After.state).assertEqual('review');
      expect(c1After.reps).assertEqual(1);
      expect(c1After.stability > 0).assertTrue(); // 间隔计算必须为正数
      expect(c1After.due > TimeUtil.now()).assertTrue();
      LogUtil.i(TAG, `Card 1 调度成功: S=${c1After.stability.toFixed(2)}, Due=${TimeUtil.todayKey(c1After.due)}`);

      // B. 验证复习日志
      const log = (await revlogDao.findLastValid(store, c1Id)).data!;
      expect(log).not().assertNull();
      expect(log.rating).assertEqual(Rating.Good);
      expect(log.stabilityBefore).assertEqual(0);
      expect(log.stabilityAfter).assertEqual(c1After.stability);
      expect(log.isDeleted).assertEqual(0);
      LogUtil.i(TAG, '复习日志写入完整 (Before/After 快照正确)');

      // C. 验证每日统计
      const stats = (await statsDao.queryByDate(store, TimeUtil.todayKey())).data!;
      expect(stats.reviewCount).assertEqual(1);
      expect(stats.newCount).assertEqual(1);
      LogUtil.i(TAG, '每日统计更新正确');

      // 5. 再次评分并验证不重复计数
      LogUtil.i(TAG, '步骤 5: 模拟第二张卡评分 (Card 2 -> Again)');
      await reviewService.rateCard(context, c2Id, Rating.Again, 3000);
      const statsFinal = (await statsDao.queryByDate(store, TimeUtil.todayKey())).data!;
      expect(statsFinal.reviewCount).assertEqual(2);
      LogUtil.i(TAG, '多次评分统计累加正确');

      const endAll = Date.now();
      LogUtil.i(TAG, `>>> M2 出口检查通过，总耗时: ${endAll - startAll}ms`);
    });
  });
}
