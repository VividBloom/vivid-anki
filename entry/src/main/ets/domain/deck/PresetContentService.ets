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
 * 冷启动内容服务层
 * 
 * 核心职责：
 * 1. 预置内容管理：定义并维护应用首次运行时的内置精选合集与要点。
 * 2. 静默注入逻辑：在应用冷启动过程中，安全地将预置数据持久化到本地数据库。
 * 3. 版本控制：通过 `source_ref` 记录内容版本，支持后续的内容静默升级与补丁分发。
 */
export class PresetContentService {
  private static readonly TAG = 'PresetContentService';

  /**
   * 内置预置内容定义
   * 包含：HarmonyOS 开发要点、FSRS 算法介绍、产品使用指南
   */
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
   * 执行内容注入任务
   * 
   * 业务逻辑流程：
   * 1. 检查各预置合集是否已在数据库中（基于名称和 is_preset 标记）。
   * 2. 若合集不存在，则开启事务进行完整注入。
   * 3. 插入合集记录并获取主键 ID。
   * 4. 批量插入关联的要点（Card），并标记来源为 'preset'。
   * 5. 触发合集计数更新。
   * 
   * @param ctx UIAbilityContext 上下文，用于获取数据库实例
   */
  async injectPresetContent(ctx: common.UIAbilityContext): Promise<void> {
    const store = await DbHelper.getInstance(ctx);
    
    await DbHelper.inTransaction(store, async () => {
      for (const preset of PresetContentService.CONTENT) {
        // 步骤 1：去重校验，防止重复注入
        const checkRs = await store.querySql(
          'SELECT id FROM deck WHERE name = ? AND is_preset = 1 LIMIT 1',
          [preset.name]
        );
        
        let deckId: number;
        if (checkRs.goToFirstRow()) {
          deckId = checkRs.getLong(0);
          checkRs.close();
          continue; 
        }
        checkRs.close();

        LogUtil.i(PresetContentService.TAG, `正在注入预置合集: ${preset.name}`);

        // 步骤 2：持久化合集元数据
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

        // 步骤 3：持久化下属要点
        for (const card of preset.cards) {
          await store.executeSql(
            `INSERT INTO card (deck_id, front, back, source, source_ref, state, due, created_at, updated_at) 
             VALUES (?, ?, ?, 'preset', ?, 'new', ?, ?, ?)`,
            [deckId, card.front, card.back, preset.version, now, now, now]
          );
        }

        // 步骤 4：刷新合集计数统计
        await this.recalcDeckCounts(store, deckId, now);
      }
    });
  }

  /**
   * 内部方法：重算合集的冗余计数
   * @param store RdbStore 实例
   * @param deckId 合集 ID
   * @param nowTs 当前时间戳
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
