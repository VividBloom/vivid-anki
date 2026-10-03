import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DbHelper } from '../../data/db/DbHelper';
import { TimeUtil } from '../../common/utils/TimeUtil';
import { LogUtil } from '../../common/utils/LogUtil';

interface PresetCard {
  front: string;
  back: string;
}

interface PresetDeck {
  name: string;
  cards: PresetCard[];
  version: string;
}

/**
 * 冷启动内容服务
 * 
 * 职责：
 *   1. 预置精品牌组及其内容
 *   2. 写入 card.source_ref 版本标记
 *   3. 确保首屏加载前完成必要的静默入库
 */
export class PresetContentService {
  private static readonly TAG = 'PresetContentService';

  private static readonly CONTENT: PresetDeck[] = [
    {
      name: 'HarmonyOS 开发核心要点',
      version: '1.0.0',
      cards: [
        { front: 'ArkUI 声明式 UI 的核心思想是什么？', back: 'UI = f(state)。通过声明式描述 UI 结构，框架根据状态自动更新，降低开发复杂度。' },
        { front: 'ArkUI 中的 @State 装饰器有什么作用？', back: '标记组件内的状态变量。当变量值改变时，会触发组件的重新渲染，实现数据驱动的视图更新。' },
        { front: 'Ability 的生命周期主要包括哪些阶段？', back: 'onCreate, onWindowStageCreate, onForeground, onBackground, onWindowStageDestroy, onDestroy。' },
        { front: 'HarmonyOS 的“一次开发多端部署”主要依赖什么实现？', back: '响应式布局（断点、自适应布局组件）与多设备能力查询（SysCap）机制。' }
      ]
    },
    {
      name: 'FSRS-6 算法精要',
      version: '1.0.0',
      cards: [
        { front: 'FSRS 算法中的“稳定性 (Stability)”代表什么？', back: '代表知识的牢固程度。预测在此间隔后复习，能够保持 90% 成功提取的概率。' },
        { front: 'FSRS 算法中，“掌握挑战 (Difficulty)”的取值范围是多少？', back: '1 到 10。值越大表示该知识点越具挑战性，随复习表现动态调整。' },
        { front: '为什么目标留存率 (Desired Retention) 会影响复习频率？', back: '目标留存率越高，要求的复习频率就越高，以确保更低的遗忘概率。' }
      ]
    },
    {
      name: '“瞄一眼” 产品指南',
      version: '1.0.0',
      cards: [
        { front: '“瞄一眼”的回收站数据会保留多久？', back: '30 天。在此期间你可以随时在回收站中恢复已移出的合集或要点。' },
        { front: '在“瞄一眼”中，彻底删除合集后，复习记录会消失吗？', back: '不会。为了保障 FSRS 算法的准确性，复习记录 (revlog) 会永久保留，仅物理删除合集和要点条目。' },
        { front: '“数据主权”在本项目中是如何体现的？', back: '导出功能完全开放、不设限制（如不限量、不收费、不加水印），确保用户对个人数据拥有绝对所有权。' }
      ]
    }
  ];

  /**
   * 注入预置内容
   */
  async injectPresetContent(ctx: common.UIAbilityContext): Promise<void> {
    const store = await DbHelper.getInstance(ctx);
    
    await DbHelper.inTransaction(store, async () => {
      for (const preset of PresetContentService.CONTENT) {
        // 1. 检查合集是否已存在（通过名称和 is_preset 标识）
        const checkRs = await store.querySql(
          'SELECT id FROM deck WHERE name = ? AND is_preset = 1 LIMIT 1',
          [preset.name]
        );
        
        let deckId: number;
        if (checkRs.goToFirstRow()) {
          deckId = checkRs.getLong(0);
          checkRs.close();
          // 如果已存在，暂时不重复插入要点
          continue; 
        }
        checkRs.close();

        LogUtil.i(PresetContentService.TAG, `正在注入预置合集: ${preset.name}`);

        // 2. 插入合集
        const now = TimeUtil.now();
        await store.executeSql(
          'INSERT INTO deck (name, is_preset, created_at, updated_at) VALUES (?, 1, ?, ?)',
          [preset.name, now, now]
        );
        
        const idRs = await store.querySql('SELECT last_insert_rowid()');
        if (idRs.goToFirstRow()) {
          deckId = idRs.getLong(0);
        } else {
          idRs.close();
          throw new Error('Failed to get last insert rowid for deck');
        }
        idRs.close();

        // 3. 插入要点
        for (const card of preset.cards) {
          await store.executeSql(
            `INSERT INTO card (deck_id, front, back, source, source_ref, state, due, created_at, updated_at) 
             VALUES (?, ?, ?, 'preset', ?, 'new', ?, ?, ?)`,
            [deckId, card.front, card.back, preset.version, now, now, now]
          );
        }

        // 4. 更新合集计数
        await this.recalcDeckCounts(store, deckId, now);
      }
    });
  }

  /**
   * 重算合集的冗余计数
   */
  private async recalcDeckCounts(store: relationalStore.RdbStore, deckId: number, nowTs: number): Promise<void> {
    await store.executeSql(
      `UPDATE deck SET 
       card_count = (SELECT count(*) FROM card WHERE deck_id = ? AND deleted_at IS NULL),
       due_count = (SELECT count(*) FROM card WHERE deck_id = ? AND deleted_at IS NULL AND due <= ?),
       updated_at = ?
       WHERE id = ?`,
      [deckId, deckId, nowTs, nowTs, deckId]
    );
  }
}
