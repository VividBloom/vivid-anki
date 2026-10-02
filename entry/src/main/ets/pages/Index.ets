import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { TodayPage } from '../ui/pages/TodayPage';
import { ReviewService } from '../domain/review/ReviewService';

@Entry
@Component
struct Index {
  private reviewService: ReviewService = new ReviewService();
  @State onboardingDone: boolean = true;
  @State isLoading: boolean = true;

  async aboutToAppear() {
    const ctx = getContext(this) as common.UIAbilityContext;
    const settings = await this.reviewService.getSettings(ctx);
    if (settings) {
      this.onboardingDone = settings.onboardingDone === 1;
      if (!this.onboardingDone) {
        router.replaceUrl({ url: 'ui/pages/OnboardPage' });
      }
    }
    this.isLoading = false;
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingProgress().width(48).height(48)
      } else if (this.onboardingDone) {
        TodayPage()
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}