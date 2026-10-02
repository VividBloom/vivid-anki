import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { zlib } from '@kit.ContentFoundationKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { DbHelper } from '../../data/db/DbHelper';
import DailyStatsDao from '../../data/dao/DailyStatsDao';
import { Result, ErrorCode } from '../../common/utils/Result';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';

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

  /**
   * 导入 .apkg 文件
   * 
   * @param ctx UI 上下文
   * @param apkgPath .apkg 文件的完整路径
   */
  async importApkg(ctx: common.UIAbilityContext, apkgPath: string): Promise<Result<number>> {
    const tempDir = `${ctx.tempDir}/anki_import_${TimeUtil.now()}`;
    const ankiDbName = `anki_import_${TimeUtil.now()}.db`;
    const ankiDbPath = `${ctx.databaseDir}/${ankiDbName}`;

    try {
      // 1. 创建临时目录并解压
      if (!fs.accessSync(tempDir)) {
        fs.mkdirSync(tempDir);
      }
      
      LogUtil.i(ImportService.TAG, '开始解压: ' + apkgPath);
      await zlib.decompressFile(apkgPath, tempDir);

      // 2. 定位数据库文件 (anki2.0 是 collection.anki2, 2.1+ 可能含 collection.anki21)
      let anki2File = `${tempDir}/collection.anki2`;
      if (!fs.accessSync(anki2File)) {
        anki2File = `${tempDir}/collection.anki21`;
      }
      if (!fs.accessSync(anki2File)) {
        return Result.failure(ErrorCode.IO_ERROR, '未找到有效的 Anki 数据库文件');
      }

      // 3. 将数据库文件拷贝至沙箱数据库目录，以便 relationalStore 打开
      fs.copyFileSync(anki2File, ankiDbPath);

      // 4. 打开外部 Anki 数据库
      const ankiStore = await relationalStore.getRdbStore(ctx, {
        name: ankiDbName,
        securityLevel: relationalStore.SecurityLevel.S1
      });

      // 5. 执行导入逻辑
      const importedCount = await this.performImport(ctx, ankiStore);

      // 6. 清理
      ankiStore.close(); // 关闭连接以便删除文件
      return Result.success(importedCount);
    } catch (e) {
      LogUtil.e(ImportService.TAG, '导入失败: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.UNKNOWN, '导入失败，请检查文件格式');
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
  private async performImport(ctx: common.UIAbilityContext, ankiStore: relationalStore.RdbStore): Promise<number> {
    const ourStore = await DbHelper.getInstance(ctx);
    
    return await DbHelper.inTransaction(ourStore, async (): Promise<number> => {
      // 1. 读取 Anki 合集定义 (JSON)
      const decksJson = await this.fetchAnkiDecks(ankiStore);
      const deckMap = new Map<number, number>(); // AnkiID -> OurID

      // 2. 导入合集
      for (const ankiId of Object.keys(decksJson)) {
        const deck = decksJson[ankiId];
        if (deck.name === 'Default' && deck.id === 1) continue; // 跳过默认项

        const res = await ourStore.executeSql(
          'INSERT INTO deck (name, created_at, updated_at) VALUES (?, ?, ?)',
          [deck.name, TimeUtil.now(), TimeUtil.now()]
        );
        // 获取自增 ID
        const resultSet = await ourStore.querySql('SELECT last_insert_rowid() as id');
        if (resultSet.goToFirstRow()) {
          deckMap.set(Number(ankiId), resultSet.getLong(0));
        }
        resultSet.close();
      }

      // 兜底：如果没映射到任何合集，使用内置默认合集
      const defaultDeckId = await this.ensureDefaultDeck(ourStore);
      
      // 3. 导入笔记与卡片
      const cardSql = `
        SELECT c.id as anki_cid, c.did, c.due, c.type, c.queue, c.ivl, c.factor, c.reps, c.lapses, n.flds 
        FROM cards c JOIN notes n ON c.nid = n.id
      `;
      const resultSet = await ankiStore.querySql(cardSql);
      let count = 0;
      const cardMap = new Map<number, number>(); // AnkiCID -> OurCID

      while (resultSet.goToNextRow()) {
        const ankiCid = resultSet.getLong(resultSet.getColumnIndex('anki_cid'));
        const ankiDid = resultSet.getLong(resultSet.getColumnIndex('did'));
        const flds = resultSet.getString(resultSet.getColumnIndex('flds'));
        const fields = flds.split('\u001f'); 
        
        const front = fields[0] || '';
        const back = fields.slice(1).join('<br>') || '';
        
        const targetDeckId = deckMap.get(ankiDid) || defaultDeckId;
        const state = this.mapAnkiState(resultSet.getLong(resultSet.getColumnIndex('type')));
        
        await ourStore.executeSql(
          `INSERT INTO card (deck_id, front, back, state, due, reps, lapses, source, created_at, updated_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?, 'import', ?, ?)`,
          [
            targetDeckId, front, back, state, 
            resultSet.getLong(resultSet.getColumnIndex('due')),
            resultSet.getLong(resultSet.getColumnIndex('reps')),
            resultSet.getLong(resultSet.getColumnIndex('lapses')),
            TimeUtil.now(), TimeUtil.now()
          ]
        );
        
        const idRs = await ourStore.querySql('SELECT last_insert_rowid()');
        if (idRs.goToFirstRow()) {
          cardMap.set(ankiCid, idRs.getLong(0));
        }
        idRs.close();
        count++;
      }
      resultSet.close();

      // 4. 导入复习日志
      const revlogSql = `SELECT cid, ease, ivl, lastIvl, factor, time, type FROM revlog`;
      const revRs = await ankiStore.querySql(revlogSql);
      while (revRs.goToNextRow()) {
        const ankiCid = revRs.getLong(revRs.getColumnIndex('cid'));
        const ourCid = cardMap.get(ankiCid);
        if (!ourCid) continue;

        const reviewedAt = revRs.getLong(revRs.getColumnIndex('id') || revRs.getColumnIndex('time'));
        
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
      }
      revRs.close();

      // 5. 统一更新合集计数
      for (const ourDeckId of deckMap.values()) {
        await this.recalcDeckCounts(ourStore, ourDeckId);
      }
      await this.recalcDeckCounts(ourStore, defaultDeckId);

      // 6. 更新导入统计
      await this.dailyStatsDao.increment(ourStore, { importCount: count });

      return count;
    });
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
