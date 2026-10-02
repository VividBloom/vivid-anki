import { describe, it, expect } from '@ohos/hypium';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import { PerfSeeder } from '../../main/ets/domain/maintenance/PerfSeeder';
import { ReviewService } from '../../main/ets/domain/review/ReviewService';
import { LogUtil } from '../../main/ets/common/utils/LogUtil';

export default function performanceTest() {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const context = delegator.getAppContext();
  const reviewService = new ReviewService();
  const TAG = 'PerformanceTest';

  describe('PerformanceTest', () => {
    it('P1_大数据量压测_5000张卡', 0, async () => {
      // 1. 填充数据
      LogUtil.i(TAG, '开始填充 5000 张测试卡片...');
      await PerfSeeder.seedTestData(context, 5000);
      
      // 2. 验证索引命中
      LogUtil.i(TAG, '验证查询执行计划...');
      const plan = await PerfSeeder.verifyIndexes(context);
      // 期待看到 "USING INDEX idx_card_due" 或类似的索引使用说明
      expect(plan.toLowerCase().includes('index')).assertTrue();
      expect(plan.toLowerCase().includes('idx_card_due')).assertTrue();

      // 3. 测量首屏数据获取耗时
      LogUtil.i(TAG, '开始测量首屏数据获取耗时...');
      const start = Date.now();
      const summary = await reviewService.getTodaySummary(context);
      const end = Date.now();
      const duration = end - start;

      LogUtil.i(TAG, `5000 张卡库首屏数据获取耗时: ${duration}ms`);
      LogUtil.i(TAG, `今日待复习: ${summary.reviewCount}, 新要点: ${summary.newCount}`);

      // 验收标准：≤ 300ms
      expect(duration <= 300).assertTrue();
    });
  });
}
