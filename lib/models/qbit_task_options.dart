/// qBit 任务选项读模型。
///
/// 描述队列位置、当前分类、当前标签，以及服务端可选分类/标签目录。
/// [queuePosition] 为 -1 时表示该任务不在队列中（队列动作应禁用）。
class QBitTaskOptions {
  const QBitTaskOptions({
    required this.queuePosition,
    required this.category,
    required this.tags,
    required this.availableCategories,
    required this.availableTags,
  });

  final int queuePosition;
  final String category;
  final List<String> tags;
  final List<String> availableCategories;
  final List<String> availableTags;

  QBitTaskOptions copyWith({
    int? queuePosition,
    String? category,
    List<String>? tags,
    List<String>? availableCategories,
    List<String>? availableTags,
  }) {
    return QBitTaskOptions(
      queuePosition: queuePosition ?? this.queuePosition,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      availableCategories: availableCategories ?? this.availableCategories,
      availableTags: availableTags ?? this.availableTags,
    );
  }
}
