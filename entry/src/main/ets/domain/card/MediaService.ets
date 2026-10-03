import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import MediaDao, { MediaEntity } from '../../data/dao/MediaDao';
import { Result, ErrorCode } from '../../common/utils/Result';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 媒体文件服务
 * 
 * 职责：
 *   1. 处理图片、音频文件的物理存储与数据库登记
 *   2. 维护媒体文件的引用计数 (ref_count)
 *   3. 提供过期媒体的物理清理能力
 */
export class MediaService {
  private mediaDao = new MediaDao();
  private static readonly MEDIA_DIR = 'media';
  /** 单个媒体文件上限 10MB，防止大图 OOM */
  private static readonly MAX_FILE_SIZE = 10 * 1024 * 1024;

  /**
   * 保存媒体文件到应用私有目录并登记
   * 
   * @param ctx UI 上下文
   * @param sourceUri 源文件路径 (支持 file:// 或 绝对路径)
   * @param type 类型：'image' | 'audio'
   */
  async saveMedia(ctx: common.UIAbilityContext, sourceUri: string, type: string): Promise<Result<number>> {
    try {
      // 0. 检查源文件是否存在及大小
      if (!fs.accessSync(sourceUri)) {
        return Result.failure(ErrorCode.FILE_ERROR, '源文件不存在');
      }
      const sourceStat = fs.statSync(sourceUri);
      if (sourceStat.size > MediaService.MAX_FILE_SIZE) {
        return Result.failure(ErrorCode.FILE_ERROR, '文件过大，上限 10MB');
      }

      // 1. 准备目标目录
      const mediaDir = `${ctx.filesDir}/${MediaService.MEDIA_DIR}`;
      if (!fs.accessSync(mediaDir)) {
        fs.mkdirSync(mediaDir);
      }

      // 2. 生成目标文件名 (时间戳 + 随机数)
      const ext = sourceUri.substring(sourceUri.lastIndexOf('.'));
      const fileName = `${Date.now()}_${Math.floor(Math.random() * 1000)}${ext}`;
      const targetPath = `${mediaDir}/${fileName}`;

      // 3. 物理拷贝
      // 注意：此处假设 sourceUri 是可读路径
      const srcFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      const dstFile = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.copyFileSync(srcFile.fd, dstFile.fd);
      fs.closeSync(srcFile);
      fs.closeSync(dstFile);

      // 4. 获取文件大小
      const stat = fs.statSync(targetPath);

      // 5. 登记入库
      const store = await DbHelper.getInstance(ctx);
      const res = await this.mediaDao.insert(store, {
        type: type,
        localPath: `${MediaService.MEDIA_DIR}/${fileName}`, // 存储相对路径，适配沙箱迁移
        fileSize: stat.size,
        refCount: 0 // 初始为 0，关联卡片后再增加
      });

      return res;
    } catch (e) {
      LogUtil.e('MediaService', '保存媒体失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.FILE_ERROR, '无法保存媒体文件');
    }
  }

  /**
   * 同步更新卡片的媒体引用
   * 
   * @param store 数据库实例
   * @param cardId 卡片 ID
   * @param newMediaIds 最新的媒体 ID 集合
   */
  async syncCardMediaRefs(store: relationalStore.RdbStore, cardId: number, newMediaIds: number[]): Promise<Result<void>> {
    try {
      // 1. 获取旧的引用
      const resultSet = await store.querySql('SELECT media_refs FROM card WHERE id = ?', [cardId]);
      let oldMediaIds: number[] = [];
      if (resultSet.goToNextRow()) {
        const refsStr = resultSet.getString(0);
        if (refsStr) {
          try {
            oldMediaIds = JSON.parse(refsStr) as number[];
          } catch (e) {
            oldMediaIds = [];
          }
        }
      }
      resultSet.close();

      // 2. 计算差异
      const added = newMediaIds.filter(id => !oldMediaIds.includes(id));
      const removed = oldMediaIds.filter(id => !newMediaIds.includes(id));

      // 3. 更新计数
      for (const id of added) {
        await this.mediaDao.incrementRef(store, id);
      }
      for (const id of removed) {
        await this.mediaDao.decrementRef(store, id);
      }

      // 4. 写回卡片表
      await store.executeSql('UPDATE card SET media_refs = ? WHERE id = ?', [
        JSON.stringify(newMediaIds),
        cardId
      ]);

      return Result.success(undefined);
    } catch (e) {
      LogUtil.e('MediaService', '同步媒体引用失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.DB_WRITE, '更新媒体引用失败');
    }
  }

  /**
   * 清理无引用的物理文件
   */
  async cleanup(ctx: common.UIAbilityContext): Promise<Result<number>> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const unusedRes = await this.mediaDao.queryUnused(store);
      
      if (!unusedRes.ok) return Result.failure(ErrorCode.DB_READ, '查询待清理媒体失败');
      
      let deletedCount = 0;
      for (const media of unusedRes.data) {
        const fullPath = `${ctx.filesDir}/${media.localPath}`;
        try {
          if (fs.accessSync(fullPath)) {
            fs.unlinkSync(fullPath);
          }
          await this.mediaDao.delete(store, media.id!);
          deletedCount++;
        } catch (err) {
          LogUtil.e('MediaService', `删除文件失败 ${fullPath}: ` + JSON.stringify(err));
        }
      }
      
      return Result.success(deletedCount);
    } catch (e) {
      return Result.failure(ErrorCode.FILE_ERROR, '清理媒体流程中断');
    }
  }

  /**
   * 获取媒体的绝对路径
   */
  getAbsPath(ctx: common.UIAbilityContext, localPath: string): string {
    return `${ctx.filesDir}/${localPath}`;
  }
}
