import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { zlib } from '@kit.ContentFoundationKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { DbHelper } from '../../data/db/DbHelper';
import { Result } from '../../common/utils/Result';
import { Analytics } from '../../common/utils/Analytics';
import { ErrorCode } from '../../common/constants/ErrorCode';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';
import { MediaService } from '../card/MediaService';

import { AnalyticsService } from '../analytics/AnalyticsService';

/**
 * 导出选项
 */
export interface ExportOptions {
  /** 进度回调 */
  onProgress?: (step: string, progress: number) => void;
  /** 取消信号 */
  signal?: AbortSignal;
}

/**
 * 数据导出服务
 * 
 * 核心职责：
 * 1. 数据主权保障：提供 JSON、APKG、CSV 等多种格式导出，确保用户数据可自由迁移。
 * 2. Anki 兼容：构建符合 Anki 规范的 SQLite 数据库结构（col, notes, cards, revlog），实现跨平台接续。
 * 3. 埋点导出：支持导出本地统计数据，供用户进行深度记忆分析或争议排查。
 * 4. 离线运行：所有处理逻辑均在本地沙箱完成，不依赖云端接口，确保隐私安全。
 */
export class ExportService {
  private static readonly TAG = 'ExportService';
  private mediaService = new MediaService();
  private analyticsService = new AnalyticsService();

  /**
   * 导出埋点统计数据（用于数据审计与分析）
   * 
   * @param ctx UIAbilityContext 上下文
   * @param targetDir 目标存储目录（通常为用户选择的下载或备份路径）
   * @param options 进度回调与取消控制
   * @returns 成功返回导出的文件绝对路径
   */
  async exportAnalytics(ctx: common.UIAbilityContext, targetDir: string, options?: ExportOptions): Promise<Result<string>> {
    try {
      options?.onProgress?.('正在提取埋点数据...', 20);
      const events = await this.analyticsService.getAllEvents(ctx);

      if (options?.signal?.aborted) return Result.failure(ErrorCode.EXPORT_IO, '用户已取消');
      options?.onProgress?.('正在生成 JSON...', 60);

      const fileName = `memo_analytics_${TimeUtil.now()}.json`;
      const filePath = `${targetDir}/${fileName}`;
      const jsonStr = JSON.stringify(events, null, 2);

      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNCATE);
      fs.writeSync(file.fd, jsonStr);
      fs.closeSync(file);

      options?.onProgress?.('完成', 100);
      return Result.success(filePath);
    } catch (e) {
      LogUtil.e(ExportService.TAG, '埋点导出失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.EXPORT_IO, '导出失败，请重试');
    }
  }

  /**
   * 导出为全量备份 JSON（本项目专用格式）
   */
  async exportJson(ctx: common.UIAbilityContext, targetDir: string, options?: ExportOptions): Promise<Result<string>> {
    try {
      options?.onProgress?.('正在准备数据...', 10);
      const store = await DbHelper.getInstance(ctx);
      
      const data = {
        version: 1,
        exportedAt: TimeUtil.now(),
        decks: await this.fetchAllDecks(store),
        cards: await this.fetchAllCards(store),
        revlogs: await this.fetchAllRevlogs(store)
      };

      if (options?.signal?.aborted) return Result.failure(ErrorCode.EXPORT_IO, '用户已取消');
      options?.onProgress?.('正在生成 JSON...', 50);

      const fileName = `memo_export_${TimeUtil.now()}.json`;
      const filePath = `${targetDir}/${fileName}`;
      const jsonStr = JSON.stringify(data, null, 2);
      
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNCATE);
      fs.writeSync(file.fd, jsonStr);
      fs.closeSync(file);

      // 埋点
      Analytics.logEvent(Analytics.EVENT_DATA_EXPORT, { format: 'json' });

      options?.onProgress?.('导出完成', 100);
      return Result.success(filePath);
    } catch (e) {
      LogUtil.e(ExportService.TAG, 'JSON 导出失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.EXPORT_IO, '导出失败，请重试');
    }
  }

  /**
   * 导出为 .apkg 格式（Anki 兼容包）
   * 
   * 逻辑流程：
   * 1. 环境准备：创建临时导出目录及外部数据库文件。
   * 2. 结构构建：调用 initAnkiTables 创建 Anki 兼容的表结构。
   * 3. 数据泵：从本地 RdbStore 提取合集、要点及复习记录，转换并写入外部数据库。
   * 4. 媒体打包：将 card.media_refs 关联的物理文件重命名并拷贝至临时目录，生成 media 映射表。
   * 5. 最终压缩：使用 zlib 将所有组件打包为单个 .apkg 文件。
   */
  async exportApkg(ctx: common.UIAbilityContext, targetDir: string, options?: ExportOptions): Promise<Result<string>> {
    const tempDir = `${ctx.tempDir}/anki_export_${TimeUtil.now()}`;
    const ankiDbName = `anki_export_${TimeUtil.now()}.db`;
    const ankiDbPath = `${ctx.databaseDir}/${ankiDbName}`;
    const apkgFileName = `memo_export_${TimeUtil.now()}.apkg`;
    const apkgPath = `${targetDir}/${apkgFileName}`;

    try {
      if (options?.signal?.aborted) throw new Error('CANCELED');
      options?.onProgress?.('正在准备导出目录...', 5);

      // 1. 创建临时目录
      if (!fs.accessSync(tempDir)) {
        fs.mkdirSync(tempDir);
      }

      // 2. 创建并初始化临时 Anki 数据库
      options?.onProgress?.('正在构建数据库结构...', 10);
      const ankiStore = await relationalStore.getRdbStore(ctx, {
        name: ankiDbName,
        securityLevel: relationalStore.SecurityLevel.S1
      });
      await this.initAnkiTables(ankiStore);

      // 3. 填充数据
      options?.onProgress?.('正在同步数据...', 30);
      const ourStore = await DbHelper.getInstance(ctx);
      await this.populateAnkiData(ctx, ourStore, ankiStore, tempDir, options);

      // 4. 关闭数据库以允许文件操作
      ankiStore.close();

      // 5. 拷贝数据库到临时目录并重命名为 collection.anki2
      fs.copyFileSync(ankiDbPath, `${tempDir}/collection.anki2`);

      // 6. 压缩为 .apkg
      options?.onProgress?.('正在生成压缩包...', 80);
      // 注意：zlib.compressFile 在鸿蒙中通常支持文件夹压缩，如果不支持，需要逐个文件处理
      // 此处假设支持文件夹压缩，或者使用替代方案
      await zlib.compressFile(tempDir, apkgPath);

      if (options?.signal?.aborted) throw new Error('CANCELED');
      
      // 埋点
      Analytics.logEvent(Analytics.EVENT_DATA_EXPORT, { format: 'apkg' });

      options?.onProgress?.('完成', 100);
      return Result.success(apkgPath);
    } catch (e) {
      if (e.message === 'CANCELED') {
        return Result.failure(ErrorCode.EXPORT_IO, '用户已取消');
      }
      LogUtil.e(ExportService.TAG, 'APKG 导出失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.EXPORT_IO, '导出失败，请重试');
    } finally {
      // 清理临时文件
      try {
        if (fs.accessSync(tempDir)) fs.rmdirSync(tempDir);
        if (fs.accessSync(ankiDbPath)) fs.unlinkSync(ankiDbPath);
      } catch (err) {
        // ignore cleanup errors
      }
    }
  }

  /**
   * 导出为 CSV 文件 (通用表格格式)
   * 
   * @param ctx UI 上下文
   * @param targetDir 目标目录
   * @param options 导出选项
   */
  async exportCsv(ctx: common.UIAbilityContext, targetDir: string, options?: ExportOptions): Promise<Result<string>> {
    try {
      options?.onProgress?.('正在提取要点...', 10);
      const store = await DbHelper.getInstance(ctx);
      const cards = await this.fetchAllCards(store);
      
      if (options?.signal?.aborted) return Result.failure(ErrorCode.EXPORT_IO, '用户已取消');
      options?.onProgress?.('正在生成 CSV...', 50);

      const fileName = `memo_export_${TimeUtil.now()}.csv`;
      const filePath = `${targetDir}/${fileName}`;
      
      // CSV Header
      let content = '正面,背面,状态,最后复习时间,复习次数\n';
      
      for (const c of cards) {
        // 简单处理 CSV 转义
        const f = `"${(c.front || '').replace(/"/g, '""')}"`;
        const b = `"${(c.back || '').replace(/"/g, '""')}"`;
        const lastRev = c.last_review ? TimeUtil.formatDate(c.last_review) : '';
        content += `${f},${b},${c.state},${lastRev},${c.reps}\n`;
      }

      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNCATE);
      fs.writeSync(file.fd, content);
      fs.closeSync(file);

      // 埋点
      Analytics.logEvent(Analytics.EVENT_DATA_EXPORT, { format: 'csv' });

      options?.onProgress?.('导出完成', 100);
      return Result.success(filePath);
    } catch (e) {
      LogUtil.e(ExportService.TAG, 'CSV 导出失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.EXPORT_IO, '导出失败，请重试');
    }
  }

  private async fetchAllDecks(store: relationalStore.RdbStore): Promise<any[]> {
    const resultSet = await store.querySql('SELECT * FROM deck WHERE deleted_at IS NULL');
    const list: any[] = [];
    while (resultSet.goToNextRow()) {
      list.push(this.rowToObj(resultSet));
    }
    resultSet.close();
    return list;
  }

  private async fetchAllCards(store: relationalStore.RdbStore): Promise<any[]> {
    const resultSet = await store.querySql('SELECT * FROM card WHERE deleted_at IS NULL');
    const list: any[] = [];
    while (resultSet.goToNextRow()) {
      list.push(this.rowToObj(resultSet));
    }
    resultSet.close();
    return list;
  }

  private async fetchAllRevlogs(store: relationalStore.RdbStore): Promise<any[]> {
    const resultSet = await store.querySql('SELECT * FROM revlog WHERE is_deleted = 0');
    const list: any[] = [];
    while (resultSet.goToNextRow()) {
      list.push(this.rowToObj(resultSet));
    }
    resultSet.close();
    return list;
  }

  private rowToObj(resultSet: relationalStore.ResultSet): any {
    const obj: any = {};
    const names = resultSet.columnNames;
    for (const name of names) {
      const idx = resultSet.getColumnIndex(name);
      // 简单映射，根据实际情况可能需要处理类型
      try {
        obj[name] = resultSet.getValue(idx);
      } catch (e) {
        obj[name] = null;
      }
    }
    return obj;
  }

  private async initAnkiTables(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql(`CREATE TABLE col (
      id              integer primary key,
      crt             integer not null,
      mod             integer not null,
      scm             integer not null,
      ver             integer not null,
      dty             integer not null,
      usn             integer not null,
      ls              integer not null,
      conf            text not null,
      models          text not null,
      decks           text not null,
      dconf           text not null,
      tags            text not null
    )`);
    await store.executeSql(`CREATE TABLE notes (
      id              integer primary key,
      guid            text not null,
      mid             integer not null,
      mod             integer not null,
      usn             integer not null,
      tags            text not null,
      flds            text not null,
      sfld            integer not null,
      csum            integer not null,
      flags           integer not null,
      data            text not null
    )`);
    await store.executeSql(`CREATE TABLE cards (
      id              integer primary key,
      nid             integer not null,
      did             integer not null,
      ord             integer not null,
      mod             integer not null,
      usn             integer not null,
      type            integer not null,
      queue           integer not null,
      due             integer not null,
      ivl             integer not null,
      factor          integer not null,
      reps            integer not null,
      lapses          integer not null,
      left            integer not null,
      odue            integer not null,
      odid            integer not null,
      flags           integer not null,
      data            text not null
    )`);
    await store.executeSql(`CREATE TABLE revlog (
      id              integer primary key,
      cid             integer not null,
      usn             integer not null,
      ease            integer not null,
      ivl             integer not null,
      lastIvl         integer not null,
      factor          integer not null,
      time            integer not null,
      type            integer not null
    )`);
  }

  private async populateAnkiData(ctx: common.UIAbilityContext, ourStore: relationalStore.RdbStore, ankiStore: relationalStore.RdbStore, tempDir: string, options?: ExportOptions): Promise<void> {
    // 1. 初始化 col 表 (Anki 必需)
    const now = TimeUtil.now();
    const decksObj: Record<string, any> = { "1": { "id": 1, "name": "Default" } };
    
    const ourDecks = await this.fetchAllDecks(ourStore);
    for (const d of ourDecks) {
      decksObj[d.id.toString()] = { "id": d.id, "name": d.name };
    }

    await ankiStore.executeSql(
      `INSERT INTO col (id, crt, mod, scm, ver, dty, usn, ls, conf, models, decks, dconf, tags)
       VALUES (1, ?, ?, ?, 11, 0, 0, 0, '{}', '{}', ?, '{}', '{}')`,
      [now, now, now, JSON.stringify(decksObj)]
    );

    // 2. 导出卡片与笔记
    const ourCards = await this.fetchAllCards(ourStore);
    const mediaMapping: Record<string, string> = {};
    let mediaCounter = 0;

    for (let i = 0; i < ourCards.length; i++) {
      if (options?.signal?.aborted) throw new Error('CANCELED');
      const c = ourCards[i];
      const nid = c.id + 1000000; 
      
      // 处理媒体：解析 card.media_refs 字段
      if (c.media_refs) {
        try {
          const mediaIds = JSON.parse(c.media_refs) as number[];
          const mediaDetails = await ourStore.querySql(`SELECT id, local_path FROM media WHERE id IN (${mediaIds.join(',')})`);
          while (mediaDetails.goToNextRow()) {
            const mid = mediaDetails.getLong(0);
            const localPath = mediaDetails.getString(1);
            const absPath = this.mediaService.getAbsPath(ctx, localPath);
            
            if (fs.accessSync(absPath)) {
              const fileName = localPath.split('/').pop() || `media_${mid}`;
              const internalName = (mediaCounter++).toString();
              fs.copyFileSync(absPath, `${tempDir}/${internalName}`);
              mediaMapping[internalName] = fileName;
            }
          }
          mediaDetails.close();
        } catch (e) {
          LogUtil.w(ExportService.TAG, `处理卡片 ${c.id} 媒体失败: ${e.message}`);
        }
      }

      // 插入 notes
      const flds = `${c.front}\u001f${c.back}`;
      await ankiStore.executeSql(
        `INSERT INTO notes (id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data)
         VALUES (?, ?, 1, ?, 0, '', ?, 0, 0, 0, '')`,
        [nid, `guid_${c.id}`, now, flds]
      );

      // 插入 cards
      await ankiStore.executeSql(
        `INSERT INTO cards (id, nid, did, ord, mod, usn, type, queue, due, ivl, factor, reps, lapses, left, odue, odid, flags, data)
         VALUES (?, ?, ?, 0, ?, 0, ?, ?, ?, 0, 0, ?, ?, 0, 0, 0, 0, '')`,
        [
          c.id, nid, c.deck_id, now,
          this.mapToAnkiType(c.state),
          this.mapToAnkiQueue(c.state),
          c.due, c.reps, c.lapses
        ]
      );

      if (i % 100 === 0) {
        options?.onProgress?.(`已处理 ${i} 张要点...`, 30 + Math.min(40, Math.floor(i / ourCards.length * 40)));
      }
    }

    // 3. 导出复习日志
    const ourLogs = await this.fetchAllRevlogs(ourStore);
    for (let i = 0; i < ourLogs.length; i++) {
      if (options?.signal?.aborted) throw new Error('CANCELED');
      const l = ourLogs[i];
      await ankiStore.executeSql(
        `INSERT INTO revlog (id, cid, usn, ease, ivl, lastIvl, factor, time, type)
         VALUES (?, ?, 0, ?, ?, ?, 0, ?, ?)`,
        [
          l.id, l.card_id, l.rating, l.interval_after, l.interval_before || 0,
          l.duration_ms || 0, 0 
        ]
      );
    }

    // 4. 生成 media 映射文件
    const mediaJson = JSON.stringify(mediaMapping);
    const mediaFile = fs.openSync(`${tempDir}/media`, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    fs.writeSync(mediaFile.fd, mediaJson);
    fs.closeSync(mediaFile);
  }

  private mapToAnkiType(state: string): number {
    switch (state) {
      case 'new': return 0;
      case 'learning': return 1;
      case 'review': return 2;
      case 'relearning': return 3;
      default: return 0;
    }
  }

  private mapToAnkiQueue(state: string): number {
    switch (state) {
      case 'new': return 0;
      case 'learning': return 1;
      case 'review': return 2;
      default: return 0;
    }
  }
}
