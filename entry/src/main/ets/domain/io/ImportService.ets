import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { zlib } from '@kit.ContentFoundationKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { DbHelper } from '../../data/db/DbHelper';
import DailyStatsDao from '../../data/dao/DailyStatsDao';
import { MediaService } from '../card/MediaService';
import MediaDao from '../../data/dao/MediaDao';
import { Result, ErrorCode } from '../../common/utils/Result';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 导入选项
 */
export interface ImportOptions {
  /** 进度回调 */
  onProgress?: (step: string, progress: number) => void;
  /** 取消信号 */
  signal?: AbortSignal;
}

/**
 * Anki 导入服务
 * 
 * 职责：
 *   1. 解析 .apkg 文件（Zip + SQLite + JSON）
 *   2. 映射 Anki 数据结构至本项目表结构
 *   3. 事务内批量导入 content
 * 
 * 术语：
 *   - UI 展示：「导入合集」
 *   - 内部：ImportService / Anki Import
 */
export class ImportService {
  private static readonly TAG = 'ImportService';
  private dailyStatsDao = new DailyStatsDao();
  private mediaService = new MediaService();
  private mediaDao = new MediaDao();

  /**
   * 导入 .apkg 文件
   * 
   * @param ctx UI 上下文
   * @param apkgPath .apkg 文件的完整路径
   * @param options 导入选项
   */
  async importApkg(ctx: common.UIAbilityContext, apkgPath: string, options?: ImportOptions): Promise<Result<number>> {
    const tempDir = `${ctx.tempDir}/anki_import_${TimeUtil.now()}`;
    const ankiDbName = `anki_import_${TimeUtil.now()}.db`;
    const ankiDbPath = `${ctx.databaseDir}/${ankiDbName}`;

    try {
      if (options?.signal?.aborted) return Result.failure(ErrorCode.UNKNOWN, '用户已取消');
      options?.onProgress?.('正在准备...', 5);

      // 1. 创建临时目录并解压
      if (!fs.accessSync(tempDir)) {
        fs.mkdirSync(tempDir);
      }
      
      LogUtil.i(ImportService.TAG, '开始解压: ' + apkgPath);
      options?.onProgress?.('正在解压文件...', 10);
      await zlib.decompressFile(apkgPath, tempDir);

      if (options?.signal?.aborted) throw new Error('CANCELED');

      // 2. 定位数据库文件
      options?.onProgress?.('正在解析数据库...', 20);
      let anki2File = `${tempDir}/collection.anki2`;
      if (!fs.accessSync(anki2File)) {
        anki2File = `${tempDir}/collection.anki21`;
      }
      if (!fs.accessSync(anki2File)) {
        return Result.failure(ErrorCode.IO_ERROR, '未找到有效的 Anki 数据库文件');
      }

      // 3. 将数据库文件拷贝至沙箱数据库目录
      fs.copyFileSync(anki2File, ankiDbPath);

      // 4. 打开外部 Anki 数据库
      const ankiStore = await relationalStore.getRdbStore(ctx, {
        name: ankiDbName,
        securityLevel: relationalStore.SecurityLevel.S1
      });

      // 5. 执行导入逻辑
      const importedCount = await this.performImport(ctx, ankiStore, tempDir, options);

      // 6. 清理
      ankiStore.close(); 
      return Result.success(importedCount);
    } catch (e) {
      if (e.message === 'CANCELED') {
        return Result.failure(ErrorCode.UNKNOWN, '用户已取消');
      }
      LogUtil.e(ImportService.TAG, '导入失败: ' + JSON.stringify(e));
      let errorMsg = '导入失败，请检查文件格式';
      if (e.message?.includes('no such table: col')) {
        errorMsg = '无效的 Anki 文件：缺少 collection 表';
      }
      return Result.failure(ErrorCode.UNKNOWN, errorMsg);
    } finally {
      // 彻底清理临时文件与外部数据库文件
      try {
        if (fs.accessSync(tempDir)) fs.rmdirSync(tempDir);
        if (fs.accessSync(ankiDbPath)) fs.unlinkSync(ankiDbPath);
      } catch (err) {
        // ignore cleanup errors
      }
    }
  }

  /**
   * 核心导入逻辑
   */
  private async performImport(ctx: common.UIAbilityContext, ankiStore: relationalStore.RdbStore, tempDir: string, options?: ImportOptions): Promise<number> {
    const ourStore = await DbHelper.getInstance(ctx);
    
    // 数据完整性校验：获取 Anki 原始卡片数量
    const ankiCountRs = await ankiStore.querySql('SELECT count(*) FROM cards');
    let ankiTotal = 0;
    if (ankiCountRs.goToFirstRow()) {
      ankiTotal = ankiCountRs.getLong(0);
    }
    ankiCountRs.close();
    LogUtil.i(ImportService.TAG, `Anki 原始卡片总数: ${ankiTotal}`);

    return await DbHelper.inTransaction(ourStore, async (): Promise<number> => {
      // 0. 获取全局新卡上限
      const settingsRs = await ourStore.querySql('SELECT new_limit FROM user_settings WHERE id = 1');
      let globalNewLimit = 20;
      if (settingsRs.goToFirstRow()) {
        globalNewLimit = settingsRs.getLong(0);
      }
      settingsRs.close();

      options?.onProgress?.('正在映射合集与媒体...', 30);
      if (options?.signal?.aborted) throw new Error('CANCELED');

      // 1. 读取 Anki 合集定义 (JSON)
      const decksJson = await this.fetchAnkiDecks(ankiStore);
      const deckMap = new Map<number, number>(); // AnkiID -> OurID
      const deckBatchOffsetMap = new Map<number, number>(); // OurID -> CurrentBatchOffset

      // 2. 读取 Anki 媒体映射
      const mediaMapping = this.fetchAnkiMediaMapping(tempDir);
      const reverseMediaMap = new Map<string, string>(); // OriginalName -> InternalName (digits)
      for (const key of Object.keys(mediaMapping)) {
        reverseMediaMap.set(mediaMapping[key], key);
      }
      const importedMediaCache = new Map<string, number>(); // OriginalName -> OurMediaId (去重)

      // 3. 导入合集
      for (const ankiId of Object.keys(decksJson)) {
        const deck = decksJson[ankiId];
        if (deck.name === 'Default' && deck.id === 1) continue; // 跳过默认项

        await ourStore.executeSql(
          'INSERT INTO deck (name, created_at, updated_at) VALUES (?, ?, ?)',
          [deck.name, TimeUtil.now(), TimeUtil.now()]
        );
        const resultSet = await ourStore.querySql('SELECT last_insert_rowid()');
        if (resultSet.goToFirstRow()) {
          const ourId = resultSet.getLong(0);
          deckMap.set(Number(ankiId), ourId);
          deckBatchOffsetMap.set(ourId, 0);
        }
        resultSet.close();
      }

      // 兜底：如果没映射到任何合集，使用内置默认合集
      const defaultDeckId = await this.ensureDefaultDeck(ourStore);
      if (!deckBatchOffsetMap.has(defaultDeckId)) {
        const offsetRs = await ourStore.querySql('SELECT batch_offset FROM deck WHERE id = ?', [defaultDeckId]);
        if (offsetRs.goToFirstRow()) {
          deckBatchOffsetMap.set(defaultDeckId, offsetRs.getLong(0));
        }
        offsetRs.close();
      }
      
      options?.onProgress?.('正在导入要点...', 50);
      if (options?.signal?.aborted) throw new Error('CANCELED');

      // 4. 导入笔记与卡片
      const cardSql = `
        SELECT c.id as anki_cid, c.did, c.due as anki_due, c.type, c.queue, c.ivl, c.factor, c.reps, c.lapses, n.flds 
        FROM cards c JOIN notes n ON c.nid = n.id
        ORDER BY c.did, c.due, c.id
      `;
      const resultSet = await ankiStore.querySql(cardSql);
      let count = 0;
      const cardMap = new Map<number, number>(); // AnkiCID -> OurCID
      const startOfToday = TimeUtil.startOfToday();
      const newCardCounter = new Map<number, number>(); // deckId -> countOfNewCardsInThisImport

      while (resultSet.goToNextRow()) {
        if (options?.signal?.aborted) throw new Error('CANCELED');

        const ankiCid = resultSet.getLong(resultSet.getColumnIndex('anki_cid'));
        const ankiDid = resultSet.getLong(resultSet.getColumnIndex('did'));
        const flds = resultSet.getString(resultSet.getColumnIndex('flds'));
        const fields = flds.split('\u001f'); 
        
        const front = fields[0] || '';
        const back = fields.slice(1).join('<br>') || '';
        
        // 媒体提取与物理拷贝
        const mediaRefs: number[] = [];
        const foundMedia = this.extractMediaNames(front + ' ' + back);
        for (const mediaName of foundMedia) {
          const internalName = reverseMediaMap.get(mediaName);
          if (internalName) {
            if (importedMediaCache.has(mediaName)) {
              const mediaId = importedMediaCache.get(mediaName)!;
              mediaRefs.push(mediaId);
              await this.mediaDao.incrementRef(ourStore, mediaId);
            } else {
              const sourcePath = `${tempDir}/${internalName}`;
              const type = this.getMediaType(mediaName);
              const saveResult = await this.mediaService.saveMedia(ctx, sourcePath, type);
              if (saveResult.ok) {
                mediaRefs.push(saveResult.data);
                importedMediaCache.set(mediaName, saveResult.data);
              }
            }
          }
        }

        const targetDeckId = deckMap.get(ankiDid) || defaultDeckId;
        const ankiType = resultSet.getLong(resultSet.getColumnIndex('type'));
        const state = this.mapAnkiState(ankiType);
        
        // 计算分批 due
        let finalDue = resultSet.getLong(resultSet.getColumnIndex('anki_due'));
        if (state === 'new') {
          const currentOffset = deckBatchOffsetMap.get(targetDeckId) || 0;
          const importIndex = newCardCounter.get(targetDeckId) || 0;
          const dayIndex = Math.floor((currentOffset + importIndex) / globalNewLimit);
          finalDue = startOfToday + dayIndex * 86400000 + (importIndex % globalNewLimit);
          newCardCounter.set(targetDeckId, importIndex + 1);
        }
        
        await ourStore.executeSql(
          `INSERT INTO card (deck_id, front, back, state, due, reps, lapses, media_refs, source, created_at, updated_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'import', ?, ?)`,
          [
            targetDeckId, front, back, state, 
            finalDue,
            resultSet.getLong(resultSet.getColumnIndex('reps')),
            resultSet.getLong(resultSet.getColumnIndex('lapses')),
            mediaRefs.length > 0 ? JSON.stringify(mediaRefs) : null,
            TimeUtil.now(), TimeUtil.now()
          ]
        );
        
        const idRs = await ourStore.querySql('SELECT last_insert_rowid()');
        if (idRs.goToFirstRow()) {
          cardMap.set(ankiCid, idRs.getLong(0));
        }
        idRs.close();
        count++;

        // 每 100 张更新一次微小进度（50-80% 阶段）
        if (count % 100 === 0) {
          options?.onProgress?.(`已导入 ${count} 张要点...`, 50 + Math.min(30, Math.floor(count / 100)));
        }
      }
      resultSet.close();

      options?.onProgress?.('正在同步复习记录...', 85);
      if (options?.signal?.aborted) throw new Error('CANCELED');

      // 5. 导入复习日志
      const revlogSql = `SELECT cid, ease, ivl, lastIvl, factor, time, type FROM revlog`;
      const revRs = await ankiStore.querySql(revlogSql);
      let revCount = 0;
      while (revRs.goToNextRow()) {
        if (options?.signal?.aborted) throw new Error('CANCELED');

        const ankiCid = revRs.getLong(revRs.getColumnIndex('cid'));
        const ourCid = cardMap.get(ankiCid);
        if (!ourCid) continue;

        let reviewedAt = 0;
        try {
          reviewedAt = revRs.getLong(revRs.getColumnIndex('id'));
        } catch (e) {
          reviewedAt = revRs.getLong(revRs.getColumnIndex('time'));
        }
        
        await ourStore.executeSql(
          `INSERT INTO revlog (card_id, rating, elapsed_days, reviewed_at, stability_before, difficulty_before, reps_before, lapses_before, stability_after, difficulty_after, interval_after, created_at)
           VALUES (?, ?, ?, ?, 0, 0, 0, 0, 0, 0, ?, ?)`,
          [
            ourCid, 
            revRs.getLong(revRs.getColumnIndex('ease')),
            revRs.getLong(revRs.getColumnIndex('ivl')),
            reviewedAt,
            revRs.getLong(revRs.getColumnIndex('ivl')),
            TimeUtil.now()
          ]
        );
        revCount++;
        if (revCount % 200 === 0) {
          options?.onProgress?.(`已同步 ${revCount} 条记录...`, 85 + Math.min(10, Math.floor(revCount / 200)));
        }
      }
      revRs.close();

      options?.onProgress?.('正在整理数据...', 95);
      if (options?.signal?.aborted) throw new Error('CANCELED');

      // 6. 统一更新合集计数与 batch_offset
      for (const ourDeckId of deckBatchOffsetMap.keys()) {
        const addedNew = newCardCounter.get(ourDeckId) || 0;
        const oldOffset = deckBatchOffsetMap.get(ourDeckId) || 0;
        
        await ourStore.executeSql(
          'UPDATE deck SET batch_offset = ? WHERE id = ?',
          [oldOffset + addedNew, ourDeckId]
        );
        await this.recalcDeckCounts(ourStore, ourDeckId);
      }

      // 7. 更新导入统计
      await this.dailyStatsDao.increment(ourStore, { importCount: count });

      // 8. 完整性二次校验
      if (count !== ankiTotal) {
        LogUtil.w(ImportService.TAG, `导入数量不一致：Anki ${ankiTotal} vs 本地 ${count}`);
      }

      options?.onProgress?.('完成', 100);
      LogUtil.i(ImportService.TAG, `导入完成，共 ${count} 张，已按每天 ${globalNewLimit} 张分批安排。`);
      return count;
    });
  }

  private fetchAnkiMediaMapping(tempDir: string): Record<string, string> {
    const mediaFile = `${tempDir}/media`;
    if (!fs.accessSync(mediaFile)) return {};
    try {
      const content = fs.readTextSync(mediaFile);
      return JSON.parse(content);
    } catch (e) {
      LogUtil.e(ImportService.TAG, '读取媒体映射失败: ' + JSON.stringify(e));
      return {};
    }
  }

  private extractMediaNames(html: string): string[] {
    const names: string[] = [];
    const imgRegex = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi;
    let match: RegExpExecArray | null;
    while ((match = imgRegex.exec(html)) !== null) {
      names.push(match[1]);
    }
    const soundRegex = /\[sound:([^\]]+)\]/gi;
    while ((match = soundRegex.exec(html)) !== null) {
      names.push(match[1]);
    }
    return [...new Set(names)]; // 去重
  }

  private getMediaType(fileName: string): string {
    const ext = fileName.toLowerCase().split('.').pop();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].includes(ext || '')) return 'image';
    if (['mp3', 'wav', 'm4a', 'ogg', 'aac'].includes(ext || '')) return 'audio';
    return 'image';
  }

  private async fetchAnkiDecks(ankiStore: relationalStore.RdbStore): Promise<Record<string, any>> {
    const res = await ankiStore.querySql('SELECT decks FROM col');
    let decksJson = {};
    if (res.goToFirstRow()) {
      decksJson = JSON.parse(res.getString(0));
    }
    res.close();
    return decksJson;
  }

  private mapAnkiState(type: number): string {
    switch (type) {
      case 0: return 'new';
      case 1: return 'learning';
      case 2: return 'review';
      case 3: return 'relearning';
      default: return 'new';
    }
  }

  private async ensureDefaultDeck(store: relationalStore.RdbStore): Promise<number> {
    const res = await store.querySql("SELECT id FROM deck WHERE name = '默认合集' LIMIT 1");
    let id = 1;
    if (res.goToFirstRow()) {
      id = res.getLong(0);
    }
    res.close();
    return id;
  }

  private async recalcDeckCounts(store: relationalStore.RdbStore, deckId: number): Promise<void> {
    const now = TimeUtil.now();
    await store.executeSql(
      `UPDATE deck SET 
       card_count = (SELECT count(*) FROM card WHERE deck_id = ? AND deleted_at IS NULL),
       due_count = (SELECT count(*) FROM card WHERE deck_id = ? AND deleted_at IS NULL AND due <= ?),
       updated_at = ?
       WHERE id = ?`,
      [deckId, deckId, now, now, deckId]
    );
  }
}
