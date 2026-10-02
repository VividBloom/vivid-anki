import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { SettingsService, SettingsDTO } from '../../domain/settings/SettingsService';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 设置页
 * 
 * 职责：提供简洁的偏好设置入口。
 * 禁语检查：严格遵守 UI 禁语，文案正向引导。
 * 实现要求：设置项 ≤ 6 个，保持克制。
 */
@Entry
@Component
struct SettingsPage {
  private settingsService = new SettingsService();
  
  @State settings: SettingsDTO = {
    newLimit: 20,
    reminderEnabled: false,
    leftHanded: false,
    readAloud: false,
    autoBackup: true,
    syncEnabled: false
  };
  
  @State isLoading: boolean = true;

  async aboutToAppear() {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.loadSettings(ctx);
  }

  private async loadSettings(ctx: common.UIAbilityContext) {
    this.isLoading = true;
    try {
      this.settings = await this.settingsService.getSettings(ctx);
    } catch (e) {
      LogUtil.e('SettingsPage', '加载设置失败: ' + JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  private async toggleSetting(key: keyof SettingsDTO, value: boolean) {
    const ctx = getContext(this) as common.UIAbilityContext;
    const patch: Partial<SettingsDTO> = {};
    (patch as any)[key] = value;
    
    const success = await this.settingsService.updateSetting(ctx, patch);
    if (success) {
      (this.settings as any)[key] = value;
    } else {
      promptAction.showToast({ message: '修改失败' });
    }
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(24)
          .height(24)
          .onClick(() => router.back())
        
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        
        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      if (this.isLoading) {
        LoadingProgress().width(48).height(48).margin({ top: 100 })
      } else {
        List() {
          // 1. 每日新要点上限 (通过弹窗修改)
          ListItem() {
            this.SettingItem('每日新要点', `${this.settings.newLimit}`, () => {
              this.showLimitPicker();
            })
          }

          // 2. 每日提醒 (跳转提醒页)
          ListItem() {
            this.SettingItem('每日提醒', this.settings.reminderEnabled ? '已开启' : '已关闭', () => {
              router.pushUrl({ url: 'ui/pages/ReminderPage' });
            })
          }

          // 3. 左撇子模式
          ListItem() {
            this.SwitchItem('左撇子模式', '调整复习按钮布局', this.settings.leftHanded, (v) => {
              this.toggleSetting('leftHanded', v);
            })
          }

          // 4. 自动朗读
          ListItem() {
            this.SwitchItem('自动朗读', '进入背面时播放语音', this.settings.readAloud, (v) => {
              this.toggleSetting('readAloud', v);
            })
          }

          // 5. 自动备份
          ListItem() {
            this.SwitchItem('自动备份', '每天生成本地快照', this.settings.autoBackup, (v) => {
              this.toggleSetting('autoBackup', v);
            })
          }

          // 6. 多端同步
          ListItem() {
            this.SwitchItem('云端同步', '保持多设备进度一致', this.settings.syncEnabled, (v) => {
              this.toggleSetting('syncEnabled', v);
            })
          }

          // 关于项
          ListItem() {
            this.SettingItem('关于瞄一眼', '', () => {
              router.pushUrl({ url: 'ui/pages/AboutPage' });
            })
            .margin({ top: 24 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F7F7F7')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
  }

  @Builder
  SettingItem(title: string, value: string, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor('#999999')
        .margin({ right: 8 })
      Image($r('app.media.ic_public_arrow_right'))
        .width(16)
        .height(16)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .onClick(onClick)
  }

  @Builder
  SwitchItem(title: string, subTitle: string, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(subTitle)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      
      Blank()
      
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange(onChange)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
  }

  private showLimitPicker() {
    TextPickerDialog.show({
      range: ['10', '20', '30', '50', '100'],
      selected: 1,
      onAccept: (value: TextPickerResult) => {
        this.toggleSetting('newLimit', parseInt(value.value as string));
      }
    })
  }
}
