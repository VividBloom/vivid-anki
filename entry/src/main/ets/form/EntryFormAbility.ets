import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { ReviewService } from '../domain/review/ReviewService';
import { LogUtil } from '../common/utils/LogUtil';

/**
 * 卡片提供方 Ability
 * 
 * 职责：
 *   1. 响应卡片创建、更新、删除生命周期
 *   2. 定期刷新卡片数据（通过 ReviewService 获取今日摘要）
 */
export default class EntryFormAbility extends FormExtensionAbility {
  private static readonly TAG = 'EntryFormAbility';
  private reviewService = new ReviewService();

  async onAddForm(want: Want): Promise<formBindingData.FormBindingData> {
    LogUtil.i(EntryFormAbility.TAG, 'onAddForm');
    const homeData = await this.reviewService.getHomeData(this.context);
    
    const total = homeData.todayDone + homeData.summary.newCount + homeData.summary.reviewCount;
    const remaining = homeData.summary.newCount + homeData.summary.reviewCount;
    const progress = total > 0 ? Math.floor((homeData.todayDone / total) * 100) : 0;

    const formData: Record<string, string | number> = {
      'remaining': remaining,
      'progress': progress,
      'title': '今天还剩',
      'unit': '张'
    };
    return formBindingData.createFormBindingData(formData);
  }

  async onUpdateForm(formId: string): Promise<void> {
    LogUtil.i(EntryFormAbility.TAG, 'onUpdateForm: ' + formId);
    const homeData = await this.reviewService.getHomeData(this.context);
    
    const total = homeData.todayDone + homeData.summary.newCount + homeData.summary.reviewCount;
    const remaining = homeData.summary.newCount + homeData.summary.reviewCount;
    const progress = total > 0 ? Math.floor((homeData.todayDone / total) * 100) : 0;

    const formData: Record<string, string | number> = {
      'remaining': remaining,
      'progress': progress
    };
    const bindingData = formBindingData.createFormBindingData(formData);
    await formProvider.updateForm(formId, bindingData);
  }

  onRemoveForm(formId: string): void {
    LogUtil.i(EntryFormAbility.TAG, 'onRemoveForm: ' + formId);
  }
}
