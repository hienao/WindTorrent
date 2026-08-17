import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_files_controller.dart';
import 'package:windwalker/models/transmission_task_file_node.dart';

/// 文件树节点 widget，递归渲染目录与文件。
///
/// 目录节点可展开/折叠，点击切换 [TransmissionTaskFilesController.expandedPaths]。
class TransmissionFileTreeNode extends StatelessWidget {
  const TransmissionFileTreeNode({
    super.key,
    required this.node,
    required this.depth,
  });

  final TransmissionTaskFileNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TransmissionTaskFilesController>();
    final expanded = controller.expandedPaths.contains(node.path);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          type: MaterialType.transparency,
          child: ListTile(
            contentPadding:
                EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
            leading: Icon(
              node.isDirectory
                  ? (expanded ? Icons.folder_open : Icons.folder_outlined)
                  : Icons.insert_drive_file_outlined,
            ),
            title: Text(
              node.name,
              style: textTheme.bodyMedium,
            ),
            subtitle: Text(
              node.isDirectory
                  ? '${_formatBytes(node.downloaded)} / ${_formatBytes(node.size)}  ${(node.progress * 100).toStringAsFixed(0)}%'
                  : '${_formatBytes(node.downloaded)} / ${_formatBytes(node.size)}',
              style: textTheme.bodySmall,
            ),
            trailing: node.isDirectory
                ? Icon(expanded
                    ? Icons.expand_more_rounded
                    : Icons.chevron_right_rounded)
                : Text(
                    '${(node.progress * 100).toStringAsFixed(0)}%',
                    style: textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
            onTap: node.isDirectory
                ? () => controller.toggleExpanded(node.path)
                : null,
          ),
        ),
        if (node.isDirectory && expanded)
          for (final child in node.children)
            TransmissionFileTreeNode(node: child, depth: depth + 1),
      ],
    );
  }

  /// 简易字节格式化。
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
