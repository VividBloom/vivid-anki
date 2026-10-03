import { common } from '@kit.AbilityKit';
import { Result, ErrorCode } from '../../common/utils/Result';
import { Analytics } from '../../common/utils/Analytics';
import { LogUtil } from '../../common/utils/LogUtil';

/**
 * AI 生成状态进度回调
 */
export type AiProgressCallback = (step: string, progress: number) => void;

/**
 * AI 生成配置
 */
export interface AiGenOptions {
  sourceText: string;
  sourceType: 'text' | 'image' | 'audio';
  onProgress?: AiProgressCallback;
  signal?: AbortSignal;
}

/**
 * AI 制卡核心服务
 * 
 * 职责：
 *   1. 执行提取式生成（不编造事实）
 *   2. 处理网络、超时等异常态
 *   3. 支持生成进度反馈与取消操作
 */
export class AiService {
  private static readonly TAG = 'AiService';

  /**
   * 执行生成任务
   */
  async generate(options: AiGenOptions): Promise<Result<string>> {
    const { sourceText, sourceType, onProgress, signal } = options;
    
    // 记录 AI 生成开始埋点
    Analytics.logEvent(Analytics.EVENT_AI_GEN_START, {
      source_type: sourceType,
      text_length: sourceText.length
    });

    try {
      // 1. 检查网络（此处模拟，实际应调用网络检查 API）
      const isOnline = true; // 实际开发中替换为真实判断
      if (!isOnline) {
        return Result.failure(ErrorCode.NETWORK_ERROR, '当前无网络，无法使用 AI 提取。您可以使用手动制卡或在联网后重试。');
      }

      // 2. 模拟分步进度
      const steps = [
        { msg: '正在阅读内容...', p: 20 },
        { msg: '识别核心要点...', p: 50 },
        { msg: '优化表述...', p: 80 },
        { msg: '即将完成...', p: 95 }
      ];

      for (const step of steps) {
        if (signal?.aborted) {
          return Result.failure(ErrorCode.CANCELLED, '已取消生成');
        }
        
        onProgress?.(step.msg, step.p);
        
        // 模拟 3-8 秒的耗时分布
        const delay = 800 + Math.random() * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
      }

      // 3. 模拟提取逻辑（纯提取，不编造）
      // 实际开发中此处为请求 LLM 接口
      const mockResult = this.mockExtract(sourceText);
      
      if (!mockResult || mockResult.length === 0) {
        return Result.failure(ErrorCode.AI_GEN_FAILED, '未能在内容中提取到有效的学习项，请尝试更换素材或使用手动制卡。');
      }

      return Result.success(JSON.stringify(mockResult));
    } catch (e) {
      LogUtil.e(AiService.TAG, 'AI 生成异常: ' + JSON.stringify(e));
      return Result.failure(ErrorCode.AI_GEN_FAILED, '提取过程出现意外，本次操作不扣除额度。建议稍后重试。');
    }
  }

  /**
   * 模拟提取式生成逻辑
   */
  private mockExtract(text: string): { front: string, back: string }[] {
    if (!text.trim()) return [];
    
    // 简单的按行模拟提取
    const lines = text.split('\n').filter(l => l.trim().length > 10);
    return lines.slice(0, 5).map(line => ({
      front: line.substring(0, Math.min(20, line.length)) + '...',
      back: line
    }));
  }
}
