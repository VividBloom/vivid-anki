import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { DbHelper } from '../../data/db/DbHelper';
import SessionDao, { SessionEntity } from '../../data/dao/SessionDao';
import { LogUtil } from '../../common/utils/LogUtil';
import { Result } from '../../common/utils/Result';
import { util } from '@kit.ArkTS';

/**
 * 中断恢复服务
 * 
 * 职责：
 *   1. 检测活跃会话
 *   2. 管理会话生命周期（开始、更新、完成、放弃）
 */
export class ResumeService {
  private static readonly TAG = 'ResumeService';
  private sessionDao: SessionDao = new SessionDao();

  /**
   * 检查是否有未完成的活跃会话
   */
  async checkActiveSession(ctx: common.UIAbilityContext): Promise<SessionEntity | null> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const result = await this.sessionDao.findActive(store);
      return result.ok ? result.data : null;
    } catch (e) {
      LogUtil.e(ResumeService.TAG, '检查活跃会话失败: ' + JSON.stringify(e));
      return null;
    }
  }

  /**
   * 开启新会话
   */
  async startSession(ctx: common.UIAbilityContext, totalPlanned: number, deckId: number | null = null): Promise<string | null> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const sessionId = util.generateRandomUUID(true);
      // 此处 deviceId 暂用固定值，V1.0 仅本地使用
      const deviceId = 'local_device';
      
      const result = await this.sessionDao.create(store, {
        sessionId,
        deckId,
        totalPlanned,
        deviceId
      });
      
      return result.ok ? result.data : null;
    } catch (e) {
      LogUtil.e(ResumeService.TAG, '开启会话失败: ' + JSON.stringify(e));
      return null;
    }
  }

  /**
   * 更新会话进度
   */
  async updateProgress(ctx: common.UIAbilityContext, sessionId: string, completed: number, lastCardId: number, lastPosition: number): Promise<boolean> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const result = await this.sessionDao.updateProgress(store, sessionId, {
        completed,
        lastCardId,
        lastPosition
      });
      return result.ok;
    } catch (e) {
      LogUtil.e(ResumeService.TAG, '更新进度失败: ' + JSON.stringify(e));
      return false;
    }
  }

  /**
   * 完成会话
   */
  async finishSession(ctx: common.UIAbilityContext, sessionId: string): Promise<boolean> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const result = await this.sessionDao.finish(store, sessionId);
      return result.ok;
    } catch (e) {
      LogUtil.e(ResumeService.TAG, '完成会话失败: ' + JSON.stringify(e));
      return false;
    }
  }

  /**
   * 放弃会话
   */
  async abandonSession(ctx: common.UIAbilityContext, sessionId: string): Promise<boolean> {
    try {
      const store = await DbHelper.getInstance(ctx);
      const result = await this.sessionDao.abandon(store, sessionId);
      return result.ok;
    } catch (e) {
      LogUtil.e(ResumeService.TAG, '放弃会话失败: ' + JSON.stringify(e));
      return false;
    }
  }
}
