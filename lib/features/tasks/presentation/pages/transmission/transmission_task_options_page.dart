import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/realtime/presentation/controllers/realtime_sync_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_options_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/features/tasks/presentation/widgets/transmission_options_form.dart';
import 'package:windwalker/l10n/app_localizations.dart';

/// Transmission 选项子页面。
///
/// 展示 loading / error / 表单 三种状态。
/// 接受可选的 [controller] 参数，用于测试注入；不传则内部创建。
class TransmissionTaskOptionsPage extends StatefulWidget {
  const TransmissionTaskOptionsPage({
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
  final TransmissionTaskOptionsController? controller;

  @override
  State<TransmissionTaskOptionsPage> createState() =>
      _TransmissionTaskOptionsPageState();
}

class _TransmissionTaskOptionsPageState
    extends State<TransmissionTaskOptionsPage> {
  late final TransmissionTaskOptionsController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TransmissionTaskOptionsController(
        // 任务变更后触发该下载器的全局实时刷新，使结果回流到
        // TaskDomainStore（任务域单一事实来源），保证跨页面同步。
        onTaskChanged: (downloaderId) {
          if (!mounted) return;
          context
              .read<RealtimeSyncController>()
              .refreshNow(downloaderId: downloaderId);
        },
      );
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
    final downloaderController = context.read<DownloaderController>();
    final downloader =
        downloaderController.getDownloader(widget.downloaderId);
    if (downloader == null) return;
    await _controller.load(taskId: widget.taskId, downloader: downloader);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider<TransmissionTaskOptionsController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        body: Consumer<TransmissionTaskOptionsController>(
          builder: (context, controller, _) {
            if (controller.isLoading) {
              return NeoSection(
                title: l10n.taskOptionsEntry,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (controller.errorMessage != null) {
              return NeoSection(
                title: l10n.taskOptionsEntry,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          controller.errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (controller.draft == null) {
              return const SizedBox.shrink();
            }

            return TransmissionOptionsForm(
              taskId: widget.taskId,
              downloaderId: widget.downloaderId,
            );
          },
        ),
      ),
    );
  }
}
