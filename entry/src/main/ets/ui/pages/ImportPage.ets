import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { ImportService } from '../../domain/io/ImportService';
import { StateView } from '../components/StateView';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 导入合集页
 * 
 * 职责：提供从 Anki .apkg 文件导入内容的界面。
 * 禁语检查：避开「牌组」、「卡片」、「逾期」、「难度」等词汇。
 */
@Entry
@Component
struct ImportPage {
  private importService: ImportService = new ImportService();
  private abortController: AbortController | null = null;

  @State status: 'idle' | 'importing' | 'success' | 'failed' = 'idle';
  @State progress: number = 0;
  @State stepMsg: string = '';
  @State errorMsg: string = '';
  @State importedCount: number = 0;

  private async handleSelectFile() {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = ['.apkg'];
      
      const result = await documentPicker.select(documentSelectOptions);
      if (result && result.length > 0) {
        this.startImport(result[0]);
      }
    } catch (e) {
      LogUtil.e('ImportPage', '选择文件失败: ' + JSON.stringify(e));
    }
  }

  private async startImport(filePath: string) {
    this.status = 'importing';
    this.progress = 0;
    this.stepMsg = '准备中...';
    this.abortController = new AbortController();

    const ctx = getContext(this) as common.UIAbilityContext;
    const result = await this.importService.importApkg(ctx, filePath, {
      onProgress: (step, prog) => {
        this.stepMsg = step;
        this.progress = prog;
      },
      signal: this.abortController.signal
    });

    if (result.ok) {
      this.status = 'success';
      this.importedCount = result.data;
    } else {
      if (result.message === '用户已取消') {
        this.status = 'idle';
      } else {
        this.status = 'failed';
        this.errorMsg = result.message;
      }
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
          .onClick(() => router.back())
        
        Text('导入合集')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        
        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      Column() {
        if (this.status === 'idle') {
          this.IdleView()
        } else if (this.status === 'importing') {
          this.ImportingView()
        } else if (this.status === 'success') {
          this.SuccessView()
        } else if (this.status === 'failed') {
          this.FailedView()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
  }

  @Builder
  IdleView() {
    Column({ space: 24 }) {
      Image($r('app.media.ic_public_add_filled'))
        .width(80)
        .height(80)
        .fillColor('#007DFF')
        .opacity(0.1)
      
      Column({ space: 8 }) {
        Text('从 Anki 导入内容')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Text('支持 .apkg 格式文件')
          .fontSize(14)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.Center)

      Button('选择文件')
        .width('100%')
        .height(50)
        .backgroundColor('#007DFF')
        .onClick(() => this.handleSelectFile())
    }
  }

  @Builder
  ImportingView() {
    Column({ space: 32 }) {
      Progress({ value: this.progress, total: 100, type: ProgressType.Ring })
        .width(120)
        .height(120)
        .color('#007DFF')
        .style({ strokeWidth: 10 })
      
      Column({ space: 8 }) {
        Text(this.stepMsg)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text('请保持应用在前台运行')
          .fontSize(12)
          .fontColor('#999999')
      }
      .alignItems(HorizontalAlign.Center)

      Button('取消')
        .width(120)
        .height(40)
        .backgroundColor(Color.Transparent)
        .fontColor('#999999')
        .border({ width: 1, color: '#EEEEEE' })
        .onClick(() => this.handleCancel())
    }
  }

  @Builder
  SuccessView() {
    Column({ space: 24 }) {
      Image($r('app.media.ic_public_ok'))
        .width(80)
        .height(80)
        .fillColor('#2ECC71')
      
      Column({ space: 8 }) {
        Text('导入成功')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Text(`已成功导入 ${this.importedCount} 个要点`)
          .fontSize(16)
          .fontColor('#666666')
        Text('内容已按每天 20 个分批安排')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Center)

      Button('开始学习')
        .width('100%')
        .height(50)
        .backgroundColor('#007DFF')
        .onClick(() => router.back())
    }
  }

  @Builder
  FailedView() {
    Column({ space: 24 }) {
      Image($r('app.media.ic_public_cancel'))
        .width(80)
        .height(80)
        .fillColor('#FF4D4F')
      
      Column({ space: 12 }) {
        Text('导入失败')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Text(this.errorMsg)
          .fontSize(16)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
        
        Row() {
          Image($r('app.media.ic_public_info'))
            .width(14)
            .height(14)
            .fillColor('#999999')
            .margin({ right: 4 })
          Text('原始文件未被修改')
            .fontSize(12)
            .fontColor('#999999')
        }
        .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Center)

      Row({ space: 16 }) {
        Button('重试')
          .layoutWeight(1)
          .height(50)
          .backgroundColor('#007DFF')
          .onClick(() => this.handleSelectFile())
        
        Button('返回')
          .layoutWeight(1)
          .height(50)
          .backgroundColor('#F0F0F0')
          .fontColor('#666666')
          .onClick(() => router.back())
      }
    }
  }
}
