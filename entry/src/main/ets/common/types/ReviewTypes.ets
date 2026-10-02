/**
 * 复习队列中的卡片简略信息 (DTO)
 * 用于高性能查询，减少内存占用与分层违规。
 */
export interface QueueCard {
  id: number;
  deckId: number;
  isNew: boolean;
  stability: number;
  difficulty: number;
  lastReview: number;
  due: number;
}
