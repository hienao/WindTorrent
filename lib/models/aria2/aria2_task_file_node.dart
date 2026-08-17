import 'package:windwalker/models/qbit_task_file_node.dart';

/// Aria2 文件树节点。
///
/// 从 Aria2 平铺文件列表构建的目录树结构，与 [QBitTaskFileNode] 同构。
class Aria2TaskFileNode {
  const Aria2TaskFileNode({
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
  final List<Aria2TaskFileNode> children;

  String get formattedSize => formatBytes(size);
  String get progressLabel => '${(progress * 100).toStringAsFixed(1)}%';

  /// 从 Aria2 平铺文件列表构建目录树。
  ///
  /// [files] 为 `aria2.getFiles` 返回的原始 JSON 列表。
  /// [taskName] 为可选的任务名，用作根目录节点名称。
  static List<Aria2TaskFileNode> buildTree(
    List<Map<String, dynamic>> files, {
    String? taskName,
  }) {
    final fileEntries = <_FileEntry>[];
    for (final f in files) {
      final path = f['path']?.toString() ?? '';
      if (path.isEmpty) continue;
      final length = int.tryParse(f['length']?.toString() ?? '0') ?? 0;
      final completed =
          int.tryParse(f['completedLength']?.toString() ?? '0') ?? 0;
      fileEntries.add(
          _FileEntry(path: path, size: length, downloaded: completed));
    }

    if (fileEntries.isEmpty) return const [];

    // 找到所有路径的公共目录前缀
    final commonPrefix = _findCommonPrefix(
      fileEntries.map((e) => e.path).toList(),
    );

    // 构建虚拟根节点
    final root = _TreeNode(name: '', path: '', isDirectory: true);

    for (final entry in fileEntries) {
      final relativePath = entry.path.substring(commonPrefix.length);
      final segments =
          relativePath.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) continue;

      var current = root;
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final isFile = i == segments.length - 1;
        final childPath =
            current.path.isEmpty ? segment : '${current.path}/$segment';

        if (isFile) {
          current.children.add(_TreeNode(
            name: segment,
            path: childPath,
            isDirectory: false,
            size: entry.size,
            downloaded: entry.downloaded,
          ));
        } else {
          var existing = current.children.where(
            (c) => c.name == segment && c.isDirectory,
          );
          if (existing.isEmpty) {
            final dir = _TreeNode(
              name: segment,
              path: childPath,
              isDirectory: true,
            );
            current.children.add(dir);
            current = dir;
          } else {
            current = existing.first;
          }
        }
      }
    }

    // 如果根节点只有一个目录子节点且没有文件子节点，
    // 且有 taskName，用 taskName 替换该目录名
    if (taskName != null &&
        taskName.isNotEmpty &&
        root.children.length == 1 &&
        root.children.first.isDirectory) {
      root.children.first.name = taskName;
    }

    // 如果根节点有多个子节点，或子节点包含文件（非纯目录），
    // 且有 taskName，则创建一个包裹所有子节点的根目录
    if (taskName != null &&
        taskName.isNotEmpty &&
        root.children.length > 1) {
      final wrapper = _TreeNode(
        name: taskName,
        path: taskName,
        isDirectory: true,
        children: List<_TreeNode>.from(root.children),
      );
      root.children.clear();
      root.children.add(wrapper);
    }

    return root.children.map(_buildNode).toList();
  }

  static Aria2TaskFileNode _buildNode(_TreeNode node) {
    final children = node.children.map(_buildNode).toList();
    final totalSize = node.isDirectory
        ? children.fold<int>(0, (sum, c) => sum + c.size)
        : node.size;
    final totalDownloaded = node.isDirectory
        ? children.fold<int>(0, (sum, c) => sum + c.downloaded)
        : node.downloaded;
    return Aria2TaskFileNode(
      path: node.path,
      name: node.name,
      isDirectory: node.isDirectory,
      size: totalSize,
      downloaded: totalDownloaded,
      progress: totalSize > 0 ? totalDownloaded / totalSize : 0,
      children: children,
    );
  }

  /// 找到所有路径的公共目录前缀（以 `/` 结尾）。
  static String _findCommonPrefix(List<String> paths) {
    if (paths.isEmpty) return '';
    if (paths.length == 1) {
      final idx = paths[0].lastIndexOf('/');
      return idx >= 0 ? paths[0].substring(0, idx + 1) : '';
    }
    var prefix = paths[0];
    for (var i = 1; i < paths.length; i++) {
      while (!paths[i].startsWith(prefix)) {
        prefix = prefix.substring(0, prefix.length - 1);
      }
    }
    final idx = prefix.lastIndexOf('/');
    return idx >= 0 ? prefix.substring(0, idx + 1) : '';
  }
}

class _FileEntry {
  final String path;
  final int size;
  final int downloaded;
  const _FileEntry({
    required this.path,
    required this.size,
    required this.downloaded,
  });
}

class _TreeNode {
  String name;
  final String path;
  final bool isDirectory;
  final int size;
  final int downloaded;
  final List<_TreeNode> children;

  _TreeNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.downloaded = 0,
    List<_TreeNode>? children,
  }) : children = children ?? [];
}
