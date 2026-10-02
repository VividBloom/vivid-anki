import { LogUtil } from '../../common/utils/LogUtil';

/**
 * 要点解析项
 */
export interface ParsedItem {
  front: string;
  back: string;
}

/**
 * 解析结果
 */
export interface ParseResult {
  items: ParsedItem[];
  separator: string;
  count: number;
}

/**
 * 要点解析服务
 * 
 * 职责：识别多行文本中的分隔符并拆分为待创建的要点。
 * 支持分隔符：Tab (\t)、逗号 (,)、顿号 (、)
 */
export class CardParseService {
  private static readonly SEPARATORS = ['\t', '、', ','];

  /**
   * 解析文本
   * 
   * @param text 输入的原始文本
   * @returns 解析出的要点列表及识别出的分隔符
   */
  parse(text: string): ParseResult {
    if (!text || !text.trim()) {
      return { items: [], separator: '', count: 0 };
    }

    // 1. 按行拆分
    const lines = text.split(/\r?\n/).filter((l: string): boolean => l.trim().length > 0);
    
    // 2. 启发式识别内部分隔符
    const separator = this.detectSeparator(lines);
    
    // 3. 执行拆分
    const items: ParsedItem[] = lines.map((line: string): ParsedItem => {
      if (!separator) {
        return { front: line.trim(), back: '' };
      }
      
      const parts = line.split(separator);
      if (parts.length === 1) {
        return { front: parts[0].trim(), back: '' };
      }
      
      // 取第一部分为正面，剩余部分合并为背面（处理背面也含分隔符的情况）
      return {
        front: parts[0].trim(),
        back: parts.slice(1).join(separator).trim()
      };
    });

    return {
      items: items,
      separator: separator || '换行',
      count: items.length
    };
  }

  /**
   * 自动识别最可能的分隔符
   */
  private detectSeparator(lines: string[]): string {
    const counts = new Map<string, number>();
    
    CardParseService.SEPARATORS.forEach((sep: string) => {
      let matchCount = 0;
      lines.forEach((line: string) => {
        if (line.includes(sep)) {
          matchCount++;
        }
      });
      counts.set(sep, matchCount);
    });

    // 找出匹配行数最多的分隔符，且匹配行数必须超过 30%（防止误判）
    let bestSep = '';
    let maxCount = 0;
    
    counts.forEach((count: number, sep: string) => {
      if (count > maxCount && count > lines.length * 0.3) {
        maxCount = count;
        bestSep = sep;
      }
    });

    return bestSep;
  }
}
