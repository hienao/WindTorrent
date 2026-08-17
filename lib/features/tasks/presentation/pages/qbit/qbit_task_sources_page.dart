import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_sources_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/qbit_source_card.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';

/// qBit 服务器(来源)子页面。
///
/// 展示任务的来源卡片（DHT/PeX/LSD 等伪 tracker）。
/// 自行创建 [QBitTaskSourcesController] 管理生命周期，
/// 接受可选 [controller] 参数用于测试注入。
class QBitTaskSourcesPage extends StatefulWidget {
  const QBitTaskSourcesPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final QBitTaskSourcesController? controller;

  @override
  State<QBitTaskSourcesPage> createState() => _QBitTaskSourcesPageState();
}

class _QBitTaskSourcesPageState extends State<QBitTaskSourcesPage> {
  late final QBitTaskSourcesController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = QBitTaskSourcesController();
      _ownsController = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final downloader = context
        .read<DownloaderController>()
        .getDownloader(widget.downloaderId);
    if (downloader == null) return;
    await _controller.load(taskId: widget.taskId, downloader: downloader);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<QBitTaskSourcesController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        onRefresh: _load,
        body: Consumer<QBitTaskSourcesController>(
          builder: (context, controller, _) {
            final l10n = AppLocalizations.of(context)!;
            if (controller.isLoading && controller.sources.isEmpty) {
              return NeoSection(
                title: l10n.qbitServersEntry,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (controller.errorMessage != null &&
                controller.sources.isEmpty) {
              return NeoSection(
                title: l10n.qbitServersEntry,
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

            if (controller.sources.isEmpty) {
              return NeoSection(
                title: l10n.qbitServersEntry,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.qbitNoSources),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final source in controller.sources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: QBitSourceCard(source: source),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
