import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { ReminderService } from '../../domain/reminder/ReminderService';
import { ReviewService } from '../../domain/review/ReviewService';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 提醒设置页
 * 
 * 职责：提供每日复习提醒的开关与时间设置。
 * 禁语检查：文案正向引导，不使用「逾期」、「惩罚」等词汇。
 */
@Entry
@Component
struct ReminderPage {
  private reminderService = new ReminderService();
  private reviewService = new ReviewService();
  
  @State isEnabled: boolean = false;
  @State selectedTime: string = '09:00';
  @State isLoading: boolean = true;

  async aboutToAppear() {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.loadSettings(ctx);
  }

  private async loadSettings(ctx: common.UIAbilityContext) {
    this.isLoading = true;
    try {
      const settings = await this.reviewService.getSettings(ctx);
      if (settings) {
        this.isEnabled = settings.reminderEnabled === 1;
        this.selectedTime = settings.reminderTime || '09:00';
      }
    } catch (e) {
      LogUtil.e('ReminderPage', '加载设置失败: ' + JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  private async handleSave() {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      await this.reminderService.updateReminderSettings(ctx, this.isEnabled, this.selectedTime);
      promptAction.showToast({ message: '设置已保存' });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: '保存失败' });
    }
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        
        Text('每日提醒')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
        
        Blank()
        
        Text('完成')
          .fontSize(16)
          .fontColor($r('app.color.primary_color'))
          .fontWeight(FontWeight.Medium)
          .onClick(() => this.handleSave())
      }
      .width('100%')
      .minHeight(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))

      if (this.isLoading) {
        LoadingProgress().width(48).height(48).margin({ top: 100 })
      } else {
        List() {
          ListItem() {
            Row() {
              Column() {
                Text('定时提醒')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text('开启后，每天准时为你准备好要点')
                  .fontSize(14)
                  .fontColor($r('app.color.text_tertiary'))
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              
              Blank()
              
              Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
                .selectedColor($r('app.color.primary_color'))
                .onChange((isOn: boolean) => {
                  this.isEnabled = isOn;
                })
            }
            .width('100%')
            .minHeight(72)
            .padding(16)
            .backgroundColor($r('app.color.card_background'))
          }

          if (this.isEnabled) {
            ListItem() {
              Row() {
                Text('提醒时间')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                
                Blank()
                
                Text(this.selectedTime)
                  .fontSize(16)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ right: 8 })
                
                Image($r('app.media.ic_public_arrow_right'))
                  .width(16)
                  .height(16)
                  .fillColor($r('app.color.text_tertiary'))
              }
              .width('100%')
              .minHeight(56)
              .padding(16)
              .backgroundColor($r('app.color.card_background'))
              .onClick(() => {
                TimePickerDialog.show({
                  selected: new Date(`2024-01-01 ${this.selectedTime}`),
                  useMilitaryTime: true,
                  onAccept: (value: TimePickerResult) => {
                    const hour = value.hour.toString().padStart(2, '0');
                    const minute = value.minute.toString().padStart(2, '0');
                    this.selectedTime = `${hour}:${minute}`;
                  }
                })
              })
            }
            .margin({ top: 1 })
          }

          ListItem() {
            Text('温馨提示：闹钟类提醒会在系统后台运行，确保你不会错过当天的学习计划。')
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .padding(16)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('app.color.page_background'))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
