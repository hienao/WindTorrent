import 'package:windwalker/models/transmission_task_file_node.dart';

/// 将 Transmission RPC 返回的扁平文件路径列表构建为目录树。
///
/// RPC 返回的文件路径如 `"subfolder/file.txt"`，
/// 此函数将其分组为层级结构的 [TransmissionTaskFileNode] 树。
List<TransmissionTaskFileNode> buildFileTree(
  List<TransmissionTaskFileNode> flatFiles,
) {
  return _buildLevel(flatFiles, 0);
}

List<TransmissionTaskFileNode> _buildLevel(
  List<TransmissionTaskFileNode> files,
  int depth,
) {
  if (files.isEmpty) return [];

  // 单文件且路径无子目录 → 叶子节点
  if (files.length == 1 && !files.first.path.contains('/')) {
    return files;
  }

  // 按当前层级的路径段分组
  final groups = <String, List<TransmissionTaskFileNode>>{};
  final rootFiles = <TransmissionTaskFileNode>[];

  for (final file in files) {
    final segments = file.path.split('/');
    if (segments.length <= 1) {
      // 已是当前层级的文件
      rootFiles.add(file);
    } else {
      final dirName = segments.first;
      groups.putIfAbsent(dirName, () => []);
      // 去掉当前层级前缀，保留子路径
      final remainingPath = segments.sublist(1).join('/');
      groups[dirName]!.add(TransmissionTaskFileNode(
        path: remainingPath,
        name: remainingPath.contains('/')
            ? remainingPath.split('/').last
            : remainingPath,
        isDirectory: file.isDirectory,
        size: file.size,
        downloaded: file.downloaded,
        progress: file.progress,
        children: file.children,
      ));
    }
  }

  final result = <TransmissionTaskFileNode>[];

  // 递归构建目录节点
  for (final entry in groups.entries) {
    final dirPath = entry.key;
    final children = _buildLevel(entry.value, depth + 1);

    // 聚合目录的总大小和已下载量
    var totalSize = 0;
    var totalDownloaded = 0;
    for (final child in _allLeafNodes(children)) {
      totalSize += child.size;
      totalDownloaded += child.downloaded;
    }

    result.add(TransmissionTaskFileNode(
      path: dirPath,
      name: dirPath,
      isDirectory: true,
      size: totalSize,
      downloaded: totalDownloaded,
      progress: totalSize > 0 ? totalDownloaded / totalSize : 0,
      children: children,
    ));
  }

  // 添加当前层级的根文件
  result.addAll(rootFiles);

  return result;
}

/// 递归获取所有叶子节点。
Iterable<TransmissionTaskFileNode> _allLeafNodes(
  List<TransmissionTaskFileNode> nodes,
) sync* {
  for (final node in nodes) {
    if (node.isDirectory) {
      yield* _allLeafNodes(node.children);
    } else {
      yield node;
    }
  }
}
