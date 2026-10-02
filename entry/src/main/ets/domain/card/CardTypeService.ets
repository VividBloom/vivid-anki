/**
 * 要点类型枚举
 */
export enum CardType {
  BASIC = 'basic',
  CLOZE = 'cloze',
  REVERSE = 'reverse'
}

/**
 * 渲染内容接口
 */
export interface RenderedContent {
  question: string;
  answer: string;
}

/**
 * 要点类型处理服务
 * 
 * 职责：
 *   1. 根据要点类型处理正面/背面的渲染逻辑
 *   2. 支持基础、填空、双向三种模式
 */
export class CardTypeService {
  /**
   * 获取渲染后的内容
   * 
   * @param front 原始正面内容
   * @param back 原始背面内容
   * @param type 类型
   * @param isBack 是否展示背面（翻卡后）
   */
  getRenderedContent(front: string, back: string, type: string, isBack: boolean): RenderedContent {
    switch (type) {
      case CardType.CLOZE:
        return this.renderCloze(front, back, isBack);
      case CardType.REVERSE:
        return this.renderReverse(front, back, isBack);
      case CardType.BASIC:
      default:
        return {
          question: front,
          answer: isBack ? back : ''
        };
    }
  }

  /**
   * 填空模式渲染
   * 正面：将 {{...}} 替换为 [...]
   * 背面：显示完整内容，高亮被挖空部分
   */
  private renderCloze(front: string, back: string, isBack: boolean): RenderedContent {
    const clozeRegex = /\{\{(.+?)\}\}/g;
    
    if (!isBack) {
      // 正面：隐藏答案
      return {
        question: front.replace(clozeRegex, '[...]'),
        answer: ''
      };
    } else {
      // 背面：显示原内容 + 补充说明
      // 注意：实际 UI 中可以用富文本高亮，此处仅处理字符串
      return {
        question: front.replace(clozeRegex, '$1'),
        answer: back
      };
    }
  }

  /**
   * 双向模式渲染
   * 本质上是该记录在复习时「反向」展示
   */
  private renderReverse(front: string, back: string, isBack: boolean): RenderedContent {
    return {
      question: back,
      answer: isBack ? front : ''
    };
  }
}
