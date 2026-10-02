/**
 * 错误码
 * 对应《个人开发者最小文档》3.4 错误与异常约定 —— 同类错误统一处理与提示
 */

export class ErrorCode {
  // ---- 网络 ----
  static readonly NET_OFFLINE = 'ERR_NET_OFFLINE';

  // ---- AI 制卡 ----
  static readonly AI_TIMEOUT = 'ERR_AI_TIMEOUT';
  static readonly AI_QUOTA = 'ERR_AI_QUOTA';
  static readonly AI_CONTENT = 'ERR_AI_CONTENT';
  static readonly AI_MODEL_NA = 'ERR_AI_MODEL_NA';

  // ---- 导入导出 ----
  static readonly IMPORT_PARSE = 'ERR_IMPORT_PARSE';
  static readonly IMPORT_FORMAT = 'ERR_IMPORT_FORMAT';
  static readonly EXPORT_IO = 'ERR_EXPORT_IO';

  // ---- 数据 ----
  static readonly DB_MIGRATION = 'ERR_DB_MIGRATION';
  static readonly DB_WRITE = 'ERR_DB_WRITE';

  // ---- 权限 ----
  static readonly PERM_DENIED = 'ERR_PERM_DENIED';
}

/** 错误码 → 用户可见提示。UI 层直接取用，不要各自另写一套 */
export const ERROR_MESSAGE: Map<string, string> = new Map([
  [ErrorCode.NET_OFFLINE, '当前没有网络'],
  [ErrorCode.AI_TIMEOUT, '这次生成有点慢，没成功'],
  [ErrorCode.AI_QUOTA, '今天的 AI 额度用完了'],
  [ErrorCode.AI_CONTENT, '这段内容不太好拆成卡片'],
  [ErrorCode.AI_MODEL_NA, '这台设备的 AI 功能暂不可用'],
  [ErrorCode.IMPORT_PARSE, '这个文件读不了'],
  [ErrorCode.IMPORT_FORMAT, '不支持的文件格式'],
  [ErrorCode.EXPORT_IO, '导出失败，请检查存储空间'],
  [ErrorCode.DB_MIGRATION, '数据升级失败，已为你保留旧版本数据'],
  [ErrorCode.DB_WRITE, '保存失败，请重试'],
  [ErrorCode.PERM_DENIED, '需要你授权后才能使用']
]);
