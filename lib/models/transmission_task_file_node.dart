/// Transmission 任务文件树节点模型。
///
/// 用于文件子页面，每个节点代表一个文件或目录。
/// 目录节点通过 [children] 递归包含子节点。
class TransmissionTaskFileNode {
  const TransmissionTaskFileNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.downloaded,
    required this.progress,
    this.children = const [],
  });

  /// 文件/目录的完整路径（RPC 返回的相对路径）。
  final String path;

  /// 显示用的文件/目录名。
  final String name;

  /// 是否为目录。
  final bool isDirectory;

  /// 文件/目录总大小（字节）。
  final int size;

  /// 已下载字节数。
  final int downloaded;

  /// 下载进度（0.0–1.0）。
  final double progress;

  /// 子节点列表（仅目录有值，文件为空列表）。
  final List<TransmissionTaskFileNode> children;
}
