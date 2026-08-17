import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/extensions/l10n_extensions.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/core/utils/responsive_layout.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/realtime/presentation/controllers/realtime_sync_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/widgets/delete_task_dialog.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/services/analytics_service.dart';

class TasksPage extends StatefulWidget {
  final String? downloaderId;
  final DownloaderType? downloaderType;
  final bool showBackButton;
  final bool showRefreshButton;
  final String? titleOverride;

  const TasksPage({
    super.key,
    this.downloaderId,
    this.downloaderType,
    this.showBackButton = true,
    this.showRefreshButton = true,
    this.titleOverride,
  });

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final TextEditingController _searchController = TextEditingController();
  TaskStatus? _activeStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks();
      _trackTaskListViewed();
    });
  }

  Future<void> _trackTaskListViewed() async {
    final id = widget.downloaderId;
    if (id == null || id.isEmpty || !mounted) return;
    final store = context.read<TaskDomainStore>();
    final downloaderController = context.read<DownloaderController>();
    final downloader = downloaderController.getDownloader(id);
    if (downloader == null) return;

    final tasks = store.tasksForDownloader(id);
    final activeCount = tasks.where(
      (t) =>
          t.status == TaskStatus.downloading ||
          t.status == TaskStatus.waiting,
    ).length;

    await AnalyticsService.instance.track(
      'task_list_viewed',
      params: <String, Object>{
        'downloader_type': downloader.type.name,
        'task_count': tasks.length,
        'active_count': activeCount,
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final id = widget.downloaderId;
    if (id == null || id.isEmpty || !mounted) return;

    // 触发该下载器的全局立即刷新，任务列表由共享快照回写
    await context.read<RealtimeSyncController>().refreshNow(downloaderId: id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final downloader = context.watch<DownloaderController>().getDownloader(
      widget.downloaderId ?? '',
    );
    final title =
        widget.titleOverride ?? widget.downloaderType?.label ?? l10n.taskList;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: Consumer<TaskDomainStore>(
        builder: (context, store, _) {
          final taskController = context.watch<TaskController>();
          final tasks = _filterTasks(
            store.tasksForDownloader(widget.downloaderId ?? ''),
            _searchController.text,
          );
          final isLoading = taskController.isLoadingDownloader(
            widget.downloaderId ?? '',
          );
          final padding = ResponsiveLayout.getPadding(context);
          final horizontalPadding = EdgeInsets.symmetric(
            horizontal: padding.horizontal / 2,
          );

          return RefreshIndicator(
            onRefresh: _loadTasks,
            child: ListView(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top,
                bottom: padding.bottom,
              ),
              children: [
                NeoPageHeader(
                  title: title,
                  subtitle: downloader == null
                      ? l10n.taskList
                      : '${downloader.name} · ${downloader.host}:${downloader.port}',
                  onBack: widget.showBackButton ? () => context.pop() : null,
                  trailing: widget.showRefreshButton
                      ? NeoHeaderAction(
                          tooltip: l10n.refresh,
                          icon: Icons.refresh_rounded,
                          onPressed: _loadTasks,
                        )
                      : null,
                ),
                if (downloader != null)
                  Padding(
                    padding: horizontalPadding.add(
                      const EdgeInsets.only(bottom: 12),
                    ),
                    child: NeoStatusHeroCard(
                      icon: _iconForDownloaderType(downloader.type),
                      title: downloader.name,
                      subtitle: '${downloader.host}:${downloader.port}',
                      leadingMeta: downloader.type.label,
                      trailingMeta: '${tasks.length}',
                    ),
                  ),
                Padding(
                  padding: horizontalPadding.add(
                    const EdgeInsets.only(top: 4, bottom: 12),
                  ),
                  child: NeoInputShell(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: l10n.searchTasks,
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                NeoFilterStrip<TaskStatus?>(
                  selectedValue: _activeStatus,
                  options: _taskStatusOptions(l10n),
                  onSelected: (status) => setState(() {
                    _activeStatus = status;
                  }),
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 96),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (tasks.isEmpty)
                  Padding(
                    padding: horizontalPadding,
                    child: NeoEmptyState(
                      icon: Icons.download_done_rounded,
                      title: l10n.noTasks,
                      subtitle: l10n.searchTasks,
                    ),
                  )
                else
                  Padding(
                    padding: horizontalPadding,
                    child: Column(
                      children: [
                        for (final task in tasks)
                          _TaskTile(
                            task: task,
                            downloaderId: widget.downloaderId ?? '',
                            onPause: () => taskController.pauseTaskForDownloader(
                              task.id,
                              widget.downloaderId ?? '',
                              context.read<DownloaderController>(),
                            ),
                            onResume: () => taskController.resumeTaskForDownloader(
                              task.id,
                              widget.downloaderId ?? '',
                              context.read<DownloaderController>(),
                            ),
                            onDelete: () async {
                              final downloaderController = context
                                  .read<DownloaderController>();
                              final deleteFiles = await showDeleteTaskDialog(
                                context,
                              );
                              if (deleteFiles != null) {
                                await taskController.removeTaskForDownloader(
                                  task.id,
                                  widget.downloaderId ?? '',
                                  downloaderController,
                                  deleteFiles: deleteFiles,
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<DownloadTask> _filterTasks(List<DownloadTask> source, String q) {
    var out = _activeStatus == null
        ? source
        : source.where((e) => e.status == _activeStatus).toList();
    final query = q.trim().toLowerCase();
    if (query.isNotEmpty) {
      out = out.where((e) => e.name.toLowerCase().contains(query)).toList();
    }
    return out;
  }
}

List<NeoChoiceOption<TaskStatus?>> _taskStatusOptions(AppLocalizations l10n) {
  return [
    NeoChoiceOption<TaskStatus?>(
      value: null,
      label: l10n.all,
      icon: Icons.tune_rounded,
    ),
    NeoChoiceOption<TaskStatus?>(
      value: TaskStatus.downloading,
      label: l10n.downloadingTab,
      icon: Icons.download_rounded,
    ),
    NeoChoiceOption<TaskStatus?>(
      value: TaskStatus.waiting,
      label: l10n.waiting,
      icon: Icons.more_horiz_rounded,
    ),
    NeoChoiceOption<TaskStatus?>(
      value: TaskStatus.paused,
      label: l10n.paused,
      icon: Icons.pause_rounded,
    ),
    NeoChoiceOption<TaskStatus?>(
      value: TaskStatus.seeding,
      label: l10n.seeding,
      icon: Icons.upload_rounded,
    ),
    NeoChoiceOption<TaskStatus?>(
      value: TaskStatus.completed,
      label: l10n.completedTab,
      icon: Icons.check_rounded,
    ),
    NeoChoiceOption<TaskStatus?>(
      value: TaskStatus.error,
      label: l10n.error,
      icon: Icons.priority_high_rounded,
    ),
  ];
}

IconData _iconForDownloaderType(DownloaderType type) {
  switch (type) {
    case DownloaderType.aria2:
      return Icons.hub_rounded;
    case DownloaderType.qbittorrent:
      return Icons.cloud_queue_rounded;
    case DownloaderType.transmission:
      return Icons.router_rounded;
  }
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

class _TaskTile extends StatelessWidget {
  final DownloadTask task;
  final String downloaderId;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.downloaderId,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visual = _visualForTaskStatus(task.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: [
          NeoStatusHeroCard(
            icon: visual.icon,
            iconColor: visual.foreground,
            title: task.name,
            subtitle: task.savePath,
            badge: NeoBadge(
              label: task.status.localizedLabel(context),
              backgroundColor: visual.background,
              foregroundColor: visual.foreground,
            ),
            progress: task.progress,
            leadingMeta:
                '${(task.progress * 100).toStringAsFixed(1)}% · ${task.formattedSize}',
            trailingMeta: _taskSpeedMeta(task),
            onTap: () {
              final encodedName = Uri.encodeComponent(task.name);
              context.push(
                '/tasks/detail/${task.id}?downloaderId=$downloaderId&taskName=$encodedName',
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: NeoButton.secondary(
                  onPressed:
                      task.status == TaskStatus.downloading ||
                          task.status == TaskStatus.waiting
                      ? onPause
                      : null,
                  label: Text(l10n.pause),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeoButton.secondary(
                  onPressed: task.status == TaskStatus.paused ? onResume : null,
                  label: Text(l10n.resume),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeoButton.secondary(
                  onPressed: onDelete,
                  label: Text(l10n.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 任务列表项的速度摘要：下载/上传，速度为 0 时隐藏。
String _taskSpeedMeta(DownloadTask task) {
  final dl = task.downloadSpeed;
  final ul = task.uploadSpeed;
  if (dl == 0 && ul == 0) return '--';
  final parts = <String>[];
  if (dl > 0) parts.add('↓${task.formattedSpeed}');
  if (ul > 0) parts.add('↑${task.formattedUploadSpeed}');
  return parts.join('  ');
}
