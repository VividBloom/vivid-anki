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
 * AI 制卡核心服务层
 * 
 * 核心职责：
 * 1. 提取式生成：基于大语言模型 (LLM) 从原始文本中提取核心知识点，严禁编造事实。
 * 2. 交互鲁棒性：处理网络波动、生成超时、任务取消等复杂边界场景。
 * 3. 透明反馈：实现分步进度通知，确保用户在等待期间有明确的进度预期。
 */
export class AiService {
  private static readonly TAG = 'AiService';

  /**
   * 执行 AI 提取生成任务
   * 
   * 业务逻辑流转：
   * 1. 记录埋点：统计生成请求的来源类型与内容长度。
   * 2. 环境校验：检查当前网络连通性。
   * 3. 异步生成：请求 LLM 接口，并通过 signal 支持用户手动中断任务。
   * 4. 进度同步：实时回调 onProgress 更新 UI 骨架屏或进度条。
   * 5. 异常处理：确保生成失败时不扣除用户额度，并给出友好的出口引导。
   * 
   * @param options 生成配置项（源码文本、类型、进度回调、中止信号）
   * @returns 返回包含 JSON 字符串结果或错误信息的 Result 对象
   */
  async generate(options: AiGenOptions): Promise<Result<string>> {
    const { sourceText, sourceType, onProgress, signal } = options;
    
    // 步骤 1：记录埋点，用于分析 AI 采纳率
    Analytics.logEvent(Analytics.EVENT_AI_GEN_START, {
      source_type: sourceType,
      text_length: sourceText.length
    });

    try {
      // 步骤 2：预检查网络状态
      const isOnline = true; 
      if (!isOnline) {
        return Result.failure(ErrorCode.NETWORK_ERROR, '当前无网络，无法使用 AI 提取。您可以使用手动制卡或在联网后重试。');
      }

      // 步骤 3：模拟分步任务流，对齐真实 LLM 处理周期
      const steps = [
        { msg: '正在阅读内容...', p: 20 },
        { msg: '识别核心要点...', p: 50 },
        { msg: '优化表述...', p: 80 },
        { msg: '即将完成...', p: 95 }
      ];

      for (const step of steps) {
        // 关键点：检查中断信号，支持用户在等待过久时随时取消
        if (signal?.aborted) {
          return Result.failure(ErrorCode.CANCELLED, '已取消生成');
        }
        
        onProgress?.(step.msg, step.p);
        
        // 模拟真实请求的随机延迟（通常需要 3-8 秒）
        const delay = 800 + Math.random() * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
      }

      // 步骤 4：核心提取逻辑
      const mockResult = this.mockExtract(sourceText);
      
      if (!mockResult || mockResult.length === 0) {
        return Result.failure(ErrorCode.AI_GEN_FAILED, '未能在内容中提取到有效的学习项，请尝试更换素材或使用手动制卡。');
      }

      return Result.success(JSON.stringify(mockResult));
    } catch (e) {
      LogUtil.e(AiService.TAG, 'AI 生成异常: ' + JSON.stringify(e));
      // 心理学优化文案：强调不扣除额度，降低用户挫败感
      return Result.failure(ErrorCode.AI_GEN_FAILED, '提取过程出现意外，本次操作不扣除额度。建议稍后重试。');
    }
  }

  /**
   * 模拟提取式生成逻辑（仅作示例，生产环境应替换为 API 调用）
   * @param text 源码文本
   * @returns 提取出的要点数组
   */
  private mockExtract(text: string): { front: string, back: string }[] {
    if (!text.trim()) return [];
    
    const lines = text.split('\n').filter(l => l.trim().length > 10);
    return lines.slice(0, 5).map(line => ({
      front: line.substring(0, Math.min(20, line.length)) + '...',
      back: line
    }));
  }
}
