import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/aria2_task_files_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/aria2_file_tree_node.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';

/// Aria2 文件子页面。
///
/// 展示任务的只读文件树，支持目录展开/折叠，与 qBit 文件页同构。
class Aria2TaskFilesPage extends StatefulWidget {
  const Aria2TaskFilesPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final Aria2TaskFilesController? controller;

  @override
  State<Aria2TaskFilesPage> createState() => _Aria2TaskFilesPageState();
}

class _Aria2TaskFilesPageState extends State<Aria2TaskFilesPage> {
  late final Aria2TaskFilesController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = Aria2TaskFilesController();
      _ownsController = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final downloader = context
        .read<DownloaderController>()
        .getDownloader(widget.downloaderId);
    if (downloader == null) return;
    await _controller.load(
      taskId: widget.taskId,
      downloader: downloader,
      taskName: widget.taskName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider<Aria2TaskFilesController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        onRefresh: _load,
        body: Consumer<Aria2TaskFilesController>(
          builder: (context, controller, _) {
            if (controller.isLoading && controller.files.isEmpty) {
              return NeoSection(
                title: l10n.taskFilesEntry,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }
            if (controller.errorMessage != null && controller.files.isEmpty) {
              return NeoSection(
                title: l10n.taskFilesEntry,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      controller.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              );
            }
            if (controller.files.isEmpty) {
              return NeoSection(
                title: l10n.taskFilesEntry,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.qbitNoFiles),
                  ),
                ),
              );
            }
            return NeoSection(
              title: l10n.taskFilesEntry,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final node in controller.files)
                    Aria2FileTreeNode(node: node, depth: 0),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
