import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_files_controller.dart';
import 'package:windwalker/models/qbit_task_file_node.dart';

/// qBit 文件树节点。
///
/// 叶子节点展示文件名/大小/进度；目录节点可点击展开/折叠，展开后递归渲染子节点。
/// 展开状态由 [QBitTaskFilesController]（按 path）集中管理，保证同树一致。
class QBitFileTreeNode extends StatelessWidget {
  const QBitFileTreeNode({
    super.key,
    required this.node,
    required this.depth,
  });

  final QBitTaskFileNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QBitTaskFilesController>();
    final expanded = node.isDirectory && controller.isExpanded(node.path);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding:
                EdgeInsets.only(left: 12.0 + depth * 16.0, right: 8),
            leading: Icon(node.isDirectory
                ? Icons.folder_rounded
                : Icons.insert_drive_file_rounded),
            title: Text(node.name),
            subtitle: Text('${node.formattedSize}  ${node.progressLabel}'),
            trailing: node.isDirectory
                ? Icon(expanded
                    ? Icons.expand_more_rounded
                    : Icons.chevron_right_rounded)
                : null,
          onTap: node.isDirectory
              ? () => controller.toggleExpanded(node.path)
              : null,
          ),
        ),
        if (expanded)
          for (final child in node.children)
            QBitFileTreeNode(node: child, depth: depth + 1),
      ],
    );
  }
}
