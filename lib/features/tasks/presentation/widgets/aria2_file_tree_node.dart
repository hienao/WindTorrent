import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/features/tasks/presentation/controllers/aria2_task_files_controller.dart';
import 'package:windwalker/models/aria2/aria2_task_file_node.dart';
import 'package:windwalker/models/qbit_task_file_node.dart';

/// Aria2 文件树节点（递归），与 [QBitFileTreeNode] 同构。
class Aria2FileTreeNode extends StatelessWidget {
  const Aria2FileTreeNode({
    super.key,
    required this.node,
    required this.depth,
  });

  final Aria2TaskFileNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<Aria2TaskFilesController>();
    final isExpanded = controller.isExpanded(node.path);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (node.isDirectory) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.toggleExpanded(node.path),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12.0 + depth * 16.0,
                  right: 12,
                  top: 8,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpanded
                          ? Icons.folder_open_outlined
                          : Icons.folder_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        node.name,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${node.formattedSize} · ${node.progressLabel}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            for (final child in node.children)
              Aria2FileTreeNode(node: child, depth: depth + 1),
        ],
      );
    }

    // 文件叶子节点
    return Padding(
      padding: EdgeInsets.only(
        left: 12.0 + depth * 16.0,
        right: 12,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.name,
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: node.progress.clamp(0, 1).toDouble(),
                    minHeight: 3,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${formatBytes(node.downloaded)} / ${node.formattedSize}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
