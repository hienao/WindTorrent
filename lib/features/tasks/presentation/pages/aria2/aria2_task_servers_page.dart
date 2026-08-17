import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/aria2_task_servers_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';

/// Aria2 服务器/Tracker 子页面。
///
/// 展示 BT 任务的 Tracker 列表（来自 `bittorrent.announceList`）。
class Aria2TaskServersPage extends StatefulWidget {
  const Aria2TaskServersPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final Aria2TaskServersController? controller;

  @override
  State<Aria2TaskServersPage> createState() => _Aria2TaskServersPageState();
}

class _Aria2TaskServersPageState extends State<Aria2TaskServersPage> {
  late final Aria2TaskServersController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = Aria2TaskServersController();
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
    await _controller.load(taskId: widget.taskId, downloader: downloader);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider<Aria2TaskServersController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        onRefresh: _load,
        body: Consumer<Aria2TaskServersController>(
          builder: (context, controller, _) {
            if (controller.isLoading && controller.trackers.isEmpty) {
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
                controller.trackers.isEmpty) {
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

            if (controller.trackers.isEmpty) {
              return NeoSection(
                title: l10n.qbitServersEntry,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.aria2NoTrackers),
                  ),
                ),
              );
            }

            return NeoSection(
              title: '${l10n.qbitServersEntry} (${controller.trackers.length})',
              child: Column(
                children: [
                  for (var i = 0; i < controller.trackers.length; i++) ...[
                    _TrackerRow(url: controller.trackers[i]),
                    if (i != controller.trackers.length - 1)
                      Divider(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // 提取协议标签
    final scheme = url.split('://').first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              scheme,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              style: textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
