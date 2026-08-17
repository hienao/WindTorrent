import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_trackers_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/features/tasks/presentation/widgets/transmission_tracker_card.dart';
import 'package:windwalker/l10n/app_localizations.dart';

/// Transmission 服务器(Trackers)子页面。
///
/// 展示当前任务的所有 tracker 信息，包括主机名、Tier、
/// announce 时间、做种/下载计数等。
/// 自行创建 [TransmissionTaskTrackersController] 管理生命周期，
/// 接受可选 [controller] 参数用于测试注入。
class TransmissionTaskTrackersPage extends StatefulWidget {
  const TransmissionTaskTrackersPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;

  /// 可选的外部注入控制器，测试时使用。
  final TransmissionTaskTrackersController? controller;

  @override
  State<TransmissionTaskTrackersPage> createState() =>
      _TransmissionTaskTrackersPageState();
}

class _TransmissionTaskTrackersPageState
    extends State<TransmissionTaskTrackersPage> {
  late final TransmissionTaskTrackersController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TransmissionTaskTrackersController();
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
    return ChangeNotifierProvider<TransmissionTaskTrackersController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        onRefresh: _load,
        body: Consumer<TransmissionTaskTrackersController>(
          builder: (context, controller, _) {
            final l10n = AppLocalizations.of(context)!;

            if (controller.isLoading && controller.trackers.isEmpty) {
              return NeoSection(
                title: l10n.taskTrackersEntry,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (controller.errorMessage != null) {
              return NeoSection(
                title: l10n.taskTrackersEntry,
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
                title: l10n.taskTrackersEntry,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(l10n.transmissionNoTrackers),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final tracker in controller.trackers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TransmissionTrackerCard(tracker: tracker),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
