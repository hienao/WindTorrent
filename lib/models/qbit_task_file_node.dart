/// qBit 文件页的只读树节点模型。
///
/// 由 adapter 将扁平的 `name`（含 `/` 分隔路径）聚合为目录树得到。
/// 叶子节点代表文件，分支节点代表目录（[isDirectory] = true）。
class QBitTaskFileNode {
  const QBitTaskFileNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.downloaded,
    required this.progress,
    this.children = const [],
  });

  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final int downloaded;
  final double progress;
  final List<QBitTaskFileNode> children;

  String get formattedSize => formatBytes(size);
  String get progressLabel => '${(progress * 100).toStringAsFixed(1)}%';
}

/// 将字节数格式化为易读的大小字符串。
///
/// qBit 详情相关模型（文件树、对端行）共享的格式化函数。
String formatQBitBytes(int bytes) => formatBytes(bytes);

/// 将字节数格式化为易读的大小字符串（通用）。
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
