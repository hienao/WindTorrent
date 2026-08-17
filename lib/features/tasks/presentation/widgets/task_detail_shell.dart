import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/extensions/l10n_extensions.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/widgets/delete_task_dialog.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/services/analytics_service.dart';

/// 任务详情共享外壳。
///
/// 渲染各下载器详情页共有的：页面头部、状态 Hero、下拉刷新、底部操作栏。
/// 具体内容（[body]）由调用方提供（generic fallback 或 Transmission 信息主页）。
///
/// 实时数据来自任务域单一事实来源（[TaskDomainStore]，由
/// RealtimeSyncController 回写），本壳不再持有 timer。首次进入只做埋点；
/// 子页面静态明细（文件树 / peers / options 等）各自首次加载 + 手动下拉刷新。
class TaskDetailShell extends StatefulWidget {
  const TaskDetailShell({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    required this.body,
    this.onRefresh,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final Widget body;

  /// 下拉刷新回调（子页面可注入自己的静态明细重载逻辑）。
  /// Hero / 状态栏的动态字段始终来自全局共享快照，不由此回调驱动。
  final Future<void> Function()? onRefresh;

  @override
  State<TaskDetailShell> createState() => _TaskDetailShellState();
}

class _TaskDetailShellState extends State<TaskDetailShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackTaskDetailViewed();
    });
  }

  Future<void> _trackTaskDetailViewed() async {
    final downloader = context
        .read<DownloaderController>()
        .getDownloader(widget.downloaderId);
    if (downloader == null) return;

    final task = context
        .read<TaskDomainStore>()
        .task(widget.downloaderId, widget.taskId);
    final status = task?.status.name ?? 'unknown';

    await AnalyticsService.instance.track(
      'task_detail_viewed',
      params: <String, Object>{
        'downloader_type': downloader.type.name,
        'task_status': status,
      },
    );
  }

  Future<void> _handleRefresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: SafeArea(
        bottom: false,
        child: Consumer<TaskDomainStore>(
          builder: (context, store, _) {
            final task = store.task(
              widget.downloaderId,
              widget.taskId,
            );

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                children: [
                  NeoPageHeader(
                    title: AppLocalizations.of(context)!.taskDetail,
                    onBack: () => context.pop(),
                  ),
                  _TaskHero(
                    taskId: widget.taskId,
                    downloaderId: widget.downloaderId,
                    fallbackName: widget.taskName,
                    task: task,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  widget.body,
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: TaskDetailActionBar(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
      ),
    );
  }
}

class _TaskHero extends StatelessWidget {
  const _TaskHero({
    required this.taskId,
    required this.downloaderId,
    required this.fallbackName,
    required this.task,
  });

  final String taskId;
  final String downloaderId;
  final String fallbackName;
  final DownloadTask? task;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName =
        task?.name.isNotEmpty == true ? task!.name : fallbackName;
    final downloaderName = context
            .watch<DownloaderController>()
            .getDownloader(downloaderId)
            ?.name ??
        '--';
    final status = task?.status ?? TaskStatus.unknown;
    final visual = _visualForTaskStatus(status);
    final progress = (task?.progress ?? 0).clamp(0, 1).toDouble();

    return NeoStatusHeroCard(
      icon: visual.icon,
      iconColor: visual.foreground,
      title: displayName,
      subtitle: downloaderName,
      badge: NeoBadge(
        label: task?.status.localizedLabel(context) ?? l10n.loading,
        backgroundColor: visual.background,
        foregroundColor: visual.foreground,
      ),
      progress: progress,
      leadingMeta: '${(progress * 100).toStringAsFixed(1)}%',
      trailingMeta: _speedMeta(task),
    );
  }
}

String _speedMeta(DownloadTask? task) {
  if (task == null) return '--';
  return '↓${task.formattedSpeed}  ↑${task.formattedUploadSpeed}';
}

class _TaskStatusVisual {
  final Color foreground;
  final Color background;
  final IconData icon;

  const _TaskStatusVisual({
    required this.foreground,
    required this.background,
    required this.icon,
  });
}

_TaskStatusVisual _visualForTaskStatus(TaskStatus status) {
  switch (status) {
    case TaskStatus.downloading:
      return _TaskStatusVisual(
        foreground: AppColors.warning,
        background: AppColors.warning.withValues(alpha: 0.16),
        icon: Icons.download_rounded,
      );
    case TaskStatus.waiting:
      return _TaskStatusVisual(
        foreground: AppColors.warning,
        background: AppColors.warning.withValues(alpha: 0.16),
        icon: Icons.more_horiz_rounded,
      );
    case TaskStatus.paused:
      return _TaskStatusVisual(
        foreground: AppColors.offline,
        background: AppColors.offline.withValues(alpha: 0.16),
        icon: Icons.pause_rounded,
      );
    case TaskStatus.seeding:
      return _TaskStatusVisual(
        foreground: AppColors.success,
        background: AppColors.success.withValues(alpha: 0.16),
        icon: Icons.upload_rounded,
      );
    case TaskStatus.completed:
      return _TaskStatusVisual(
        foreground: AppColors.success,
        background: AppColors.success.withValues(alpha: 0.16),
        icon: Icons.check_rounded,
      );
    case TaskStatus.error:
      return _TaskStatusVisual(
        foreground: AppColors.error,
        background: AppColors.error.withValues(alpha: 0.16),
        icon: Icons.priority_high_rounded,
      );
    case TaskStatus.removed:
    case TaskStatus.unknown:
      return _TaskStatusVisual(
        foreground: AppColors.offline,
        background: AppColors.offline.withValues(alpha: 0.16),
        icon: Icons.help_outline_rounded,
      );
  }
}

/// 详情页共享底部操作栏：暂停 / 恢复 / 删除。
///
/// 操作基于「匹配当前页面的任务」启用；stale 任务保持禁用（与历史行为一致）。
class TaskDetailActionBar extends StatelessWidget {
  const TaskDetailActionBar({
    super.key,
    required this.taskId,
    required this.downloaderId,
  });

  final String taskId;
  final String downloaderId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final taskController = context.watch<TaskController>();
    return Consumer<TaskDomainStore>(
      builder: (context, store, _) {
        final task = store.task(downloaderId, taskId);
        final busy = taskController.isActionInProgress;
        return NeoActionBar(
          child: Row(
            children: [
              Expanded(
                child: _actionButton(
                  context: context,
                  label: l10n.pause,
                  icon: Icons.pause,
                  loading: busy,
                  onPressed: (busy ||
                          task == null ||
                          (task.status != TaskStatus.downloading &&
                              task.status != TaskStatus.waiting &&
                              task.status != TaskStatus.seeding))
                      ? null
                      : () => taskController.pauseTaskForDownloader(
                            taskId,
                            downloaderId,
                            context.read<DownloaderController>(),
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  context: context,
                  label: l10n.resume,
                  icon: Icons.play_arrow_rounded,
                  loading: busy,
                  onPressed: (busy ||
                          task == null ||
                          task.status != TaskStatus.paused)
                      ? null
                      : () => taskController.resumeTaskForDownloader(
                            taskId,
                            downloaderId,
                            context.read<DownloaderController>(),
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  context: context,
                  label: l10n.delete,
                  icon: Icons.delete_outline,
                  destructive: true,
                  loading: busy,
                  onPressed: busy
                      ? null
                      : () async {
                          final deleteFiles =
                              await showDeleteTaskDialog(context);
                          if (deleteFiles != null && context.mounted) {
                            await taskController.removeTaskForDownloader(
                              taskId,
                              downloaderId,
                              context.read<DownloaderController>(),
                              deleteFiles: deleteFiles,
                            );
                            if (context.mounted) context.pop();
                          }
                        },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool destructive = false,
    bool loading = false,
  }) {
    final disabled = onPressed == null;
    final colorScheme = Theme.of(context).colorScheme;
    final color = destructive ? colorScheme.error : colorScheme.primary;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: disabled ? null : color,
        disabledBackgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
