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
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/download_task.dart';

class AllTasksTabPage extends StatefulWidget {
  final TaskStatus? initialStatus;

  const AllTasksTabPage({super.key, this.initialStatus});

  @override
  State<AllTasksTabPage> createState() => _AllTasksTabPageState();
}

class _AllTasksTabPageState extends State<AllTasksTabPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _downloaderNames = <String, String>{};
  TaskStatus? _activeStatus;

  @override
  void initState() {
    super.initState();
    _activeStatus = widget.initialStatus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllTasks();
    });
  }

  @override
  void didUpdateWidget(AllTasksTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStatus != oldWidget.initialStatus) {
      setState(() {
        _activeStatus = widget.initialStatus;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTasks() async {
    if (!mounted) return;

    final downloaderController = context.read<DownloaderController>();
    await downloaderController.loadDownloaders();
    if (!mounted) return;

    // 更新下载器名称映射
    _downloaderNames
      ..clear()
      ..addEntries(
        downloaderController.downloaders.map((d) => MapEntry(d.id, d.name)),
      );

    // 触发全局立即刷新（所有下载器含 Aria2 由 RealtimeSyncController 回写）
    await context.read<RealtimeSyncController>().refreshNow();
    if (!mounted) return;
  }

  List<DownloadTask> _filteredTasks(List<DownloadTask> source) {
    var out = _activeStatus == null
        ? source
        : source.where((e) => e.status == _activeStatus).toList();

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return out;

    return out.where((task) {
      final downloaderName = (_downloaderNames[task.downloaderId] ?? '')
          .toLowerCase();
      return task.name.toLowerCase().contains(query) ||
          task.savePath.toLowerCase().contains(query) ||
          downloaderName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: Consumer<TaskDomainStore>(
        builder: (context, store, _) {
          final taskController = context.watch<TaskController>();
          final tasks = _filteredTasks(store.allTasks);
          final padding = ResponsiveLayout.getPadding(context);
          final horizontalPadding = EdgeInsets.symmetric(
            horizontal: padding.horizontal / 2,
          );

          return RefreshIndicator(
            onRefresh: _loadAllTasks,
            child: ListView(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top,
                bottom: padding.bottom,
              ),
              children: [
                NeoPageHeader(
                  title: l10n.taskList,
                  subtitle: l10n.searchTasks,
                  trailing: NeoHeaderAction(
                    tooltip: l10n.refresh,
                    icon: Icons.refresh_rounded,
                    onPressed: _loadAllTasks,
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
                if (taskController.isRefreshingAll)
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
                          _AllTaskTile(
                            task: task,
                            downloaderName:
                                _downloaderNames[task.downloaderId] ??
                                task.downloaderId,
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

class _AllTaskTile extends StatelessWidget {
  final DownloadTask task;
  final String downloaderName;

  const _AllTaskTile({required this.task, required this.downloaderName});

  @override
  Widget build(BuildContext context) {
    final visual = _visualForTaskStatus(task.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: NeoStatusHeroCard(
        icon: visual.icon,
        iconColor: visual.foreground,
        title: task.name,
        subtitle: '$downloaderName · ${task.savePath}',
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
            '/tasks/detail/${task.id}?downloaderId=${task.downloaderId}&taskName=$encodedName',
          );
        },
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
