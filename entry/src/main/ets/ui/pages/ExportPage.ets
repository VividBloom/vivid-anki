import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { ExportService } from '../../domain/io/ExportService';
import { SettingsService, SettingsDTO } from '../../domain/settings/SettingsService';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 导出合集页
 * 
 * 职责：提供 JSON、apkg、CSV 三种格式的导出功能，并管理自动备份开关。
 * 禁语检查：遵守 UI 禁语，文案正向。
 */
@Entry
@Component
struct ExportPage {
  private exportService: ExportService = new ExportService();
  private settingsService: SettingsService = new SettingsService();
  private abortController: AbortController | null = null;

  @State status: 'idle' | 'exporting' | 'success' | 'failed' = 'idle';
  @State progress: number = 0;
  @State stepMsg: string = '';
  @State errorMsg: string = '';
  @State exportPath: string = '';
  @State autoBackup: boolean = true;

  async aboutToAppear() {
    const ctx = getContext(this) as common.UIAbilityContext;
    const settings = await this.settingsService.getSettings(ctx);
    this.autoBackup = settings.autoBackup;
  }

  private async handleExport(type: 'json' | 'apkg' | 'csv' | 'analytics') {
    try {
      this.status = 'exporting';
      this.progress = 0;
      this.stepMsg = '准备导出...';
      this.abortController = new AbortController();

      const ctx = getContext(this) as common.UIAbilityContext;
      const targetDir = ctx.filesDir;

      let result;
      if (type === 'json') {
        result = await this.exportService.exportJson(ctx, targetDir, {
          onProgress: (step, prog) => {
            this.stepMsg = step;
            this.progress = prog;
          },
          signal: this.abortController.signal
        });
      } else if (type === 'csv') {
        result = await this.exportService.exportCsv(ctx, targetDir, {
          onProgress: (step, prog) => {
            this.stepMsg = step;
            this.progress = prog;
          },
          signal: this.abortController.signal
        });
      } else if (type === 'analytics') {
        result = await this.exportService.exportAnalytics(ctx, targetDir, {
          onProgress: (step, prog) => {
            this.stepMsg = step;
            this.progress = prog;
          },
          signal: this.abortController.signal
        });
      } else {
        result = await this.exportService.exportApkg(ctx, targetDir, {
          onProgress: (step, prog) => {
            this.stepMsg = step;
            this.progress = prog;
          },
          signal: this.abortController.signal
        });
      }

      if (result.ok) {
        this.status = 'success';
        this.exportPath = result.value;
      } else {
        if (result.error.message === '用户已取消') {
          this.status = 'idle';
        } else {
          this.status = 'failed';
          this.errorMsg = result.error.message;
        }
      }
    } catch (e) {
      LogUtil.e('ExportPage', '导出异常: ' + JSON.stringify(e));
      this.status = 'failed';
      this.errorMsg = '导出过程中发生未知错误';
    }
  }

  private handleCancel() {
    if (this.abortController) {
      this.abortController.abort();
      promptAction.showToast({ message: '正在取消...' });
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
        
        Text('导出合集')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 16 })
        
        Blank()
      }
      .width('100%')
      .minHeight(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.card_background'))

      Column() {
        // ... (views)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  IdleView() {
    Column({ space: 24 }) {
      Image($r('app.media.ic_public_share'))
        .width(60)
        .height(60)
        .fillColor($r('app.color.primary_color'))
        .opacity(0.1)
      
      Column({ space: 8 }) {
        Text('备份你的学习成果')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('数据完全归你所有，随时可迁移')
          .fontSize(14)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)

      // 自动备份开关
      Row() {
        Column({ space: 4 }) {
          Text('每日自动快照')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text('每天首次启动时自动备份最近 7 天数据')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.autoBackup })
          .selectedColor($r('app.color.primary_color'))
          .onChange(async (isOn: boolean) => {
            const ctx = getContext(this) as common.UIAbilityContext;
            const success = await this.settingsService.updateSetting(ctx, { autoBackup: isOn });
            if (success) {
              this.autoBackup = isOn;
            }
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(12)
      .margin({ top: 8, bottom: 8 })

      Column({ space: 12 }) {
        Button('导出为 Anki (.apkg)')
          .width('100%')
          .minHeight(50)
          .backgroundColor($r('app.color.primary_color'))
          .onClick(() => this.handleExport('apkg'))
        
        Button('导出为 JSON (全量备份)')
          .width('100%')
          .minHeight(50)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_primary'))
          .border({ width: 1, color: $r('app.color.divider_color') })
          .onClick(() => this.handleExport('json'))

        Button('导出为 CSV (表格格式)')
          .width('100%')
          .minHeight(50)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_primary'))
          .border({ width: 1, color: $r('app.color.divider_color') })
          .onClick(() => this.handleExport('csv'))

        Button('导出埋点数据 (JSON)')
          .width('100%')
          .minHeight(50)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_primary'))
          .border({ width: 1, color: $r('app.color.divider_color') })
          .onClick(() => this.handleExport('analytics'))
      }
      
      Column({ space: 4 }) {
        Text('本应用导出永久免费、永不设限')
          .fontSize(12)
          .fontColor($r('app.color.primary_color'))
          .fontWeight(FontWeight.Medium)
        
        Text('注：导出的 apkg 可再次导入本应用，复习记录会完整保留。')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
      }
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20 })
    }
  }

  @Builder
  ExportingView() {
    Column({ space: 32 }) {
      Progress({ value: this.progress, total: 100, type: ProgressType.Ring })
        .width(120)
        .height(120)
        .color($r('app.color.primary_color'))
        .style({ strokeWidth: 10 })
      
      Column({ space: 8 }) {
        Text(this.stepMsg)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text('正在打包数据，请稍候')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)

      Button('取消')
        .width(120)
        .minHeight(40)
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.text_tertiary'))
        .border({ width: 1, color: $r('app.color.divider_color') })
        .onClick(() => this.handleCancel())
    }
  }

  @Builder
  SuccessView() {
    Column({ space: 24 }) {
      Image($r('app.media.ic_public_ok'))
        .width(80)
        .height(80)
        .fillColor($r('app.color.success_color'))
      
      Column({ space: 8 }) {
        Text('导出成功')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('文件已保存至沙箱目录')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
        Text(this.exportPath)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 8 })
          .textAlign(TextAlign.Center)
      }
      .alignItems(HorizontalAlign.Center)

      Button('完成')
        .width('100%')
        .minHeight(50)
        .backgroundColor($r('app.color.primary_color'))
        .onClick(() => router.back())
    }
  }

  @Builder
  FailedView() {
    Column({ space: 24 }) {
      Image($r('app.media.ic_public_cancel'))
        .width(80)
        .height(80)
        .fillColor($r('app.color.error_color'))
      
      Column({ space: 12 }) {
        Text('导出失败')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(this.errorMsg)
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
      }
      .alignItems(HorizontalAlign.Center)

      Row({ space: 16 }) {
        Button('重试')
          .layoutWeight(1)
          .minHeight(50)
          .backgroundColor($r('app.color.primary_color'))
          .onClick(() => this.status = 'idle')
        
        Button('返回')
          .layoutWeight(1)
          .minHeight(50)
          .backgroundColor($r('app.color.divider_color'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => router.back())
      }
    }
  }
}
