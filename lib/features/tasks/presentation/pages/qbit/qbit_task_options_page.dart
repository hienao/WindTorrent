import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/realtime/presentation/controllers/realtime_sync_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_options_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/widgets/qbit_options_form.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';

/// qBit 选项子页面。
///
/// 展示 loading / error / 表单 三种状态。表单含队列优先级动作、分类、标签。
/// 自行创建 [QBitTaskOptionsController] 管理生命周期，
/// 接受可选 [controller] 参数用于测试注入。
class QBitTaskOptionsPage extends StatefulWidget {
  const QBitTaskOptionsPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final QBitTaskOptionsController? controller;

  @override
  State<QBitTaskOptionsPage> createState() => _QBitTaskOptionsPageState();
}

class _QBitTaskOptionsPageState extends State<QBitTaskOptionsPage> {
  late final QBitTaskOptionsController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = QBitTaskOptionsController(
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
    if (!mounted) return;
    final downloader = context
        .read<DownloaderController>()
        .getDownloader(widget.downloaderId);
    if (downloader == null) return;
    final store = context.read<TaskDomainStore>();
    final hasSnapshot = store.qbitSnapshot(widget.downloaderId) != null;
    await _controller.load(
      taskId: widget.taskId,
      downloader: downloader,
      availableCategories:
          hasSnapshot ? store.qbitCategories(widget.downloaderId) : null,
      availableTags:
          hasSnapshot ? store.qbitTags(widget.downloaderId) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider<QBitTaskOptionsController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        onRefresh: _load,
        body: Consumer<QBitTaskOptionsController>(
          builder: (context, controller, _) {
            if (controller.isLoading) {
              return NeoSection(
                title: l10n.qbitOptionsEntry,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (controller.errorMessage != null && controller.isSaving) {
              // 保存失败：保留表单（表单内渲染错误），不切到全屏错误。
              return _form(context);
            }

            if (!controller.queueActionsEnabled &&
                controller.categoryDraft.isEmpty &&
                controller.tagDrafts.isEmpty &&
                controller.errorMessage != null) {
              // 加载失败且无草稿：展示全屏错误与重试。
              return NeoSection(
                title: l10n.qbitOptionsEntry,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(controller.errorMessage!,
                            textAlign: TextAlign.center),
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

            return _form(context);
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return QBitOptionsForm(
      taskId: widget.taskId,
      downloaderId: widget.downloaderId,
    );
  }
}
