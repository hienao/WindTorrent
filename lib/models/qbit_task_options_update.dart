/// qBittorrent 队列优先级动作枚举。
///
/// qBit WebUI 把队列重排暴露为相对操作（top/bottom/increase/decrease），
/// 读模型保留当前 [QBitTaskOptions.queuePosition] 的数值仅用于展示与判断
/// 队列是否启用，写模型（[QBitTaskOptionsUpdate]）使用本枚举表达意图。
enum QBitQueuePriorityAction {
  /// 不调整队列位置（save 时跳过队列写操作）。
  unchanged,

  /// 上移一位。
  increase,

  /// 下移一位。
  decrease,

  /// 置顶。
  top,

  /// 置底。
  bottom,
}

/// qBit 任务选项写载荷。
///
/// 由 [QBitTaskOptionsController.save] 构造，描述与当前态的差异：
/// 队列动作、目标分类、目标标签全集。adapter 据此调用相应 WebUI 端点。
class QBitTaskOptionsUpdate {
  const QBitTaskOptionsUpdate({
    required this.queueAction,
    required this.category,
    required this.tags,
  });

  final QBitQueuePriorityAction queueAction;
  final String category;
  final List<String> tags;
}
