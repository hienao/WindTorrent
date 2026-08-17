import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/extensions/l10n_extensions.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_entry_card.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/download_task.dart';

/// Aria2 任务详情信息主页。
class Aria2TaskDetailPage extends StatefulWidget {
  const Aria2TaskDetailPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;

  @override
  State<Aria2TaskDetailPage> createState() => _Aria2TaskDetailPageState();
}

class _Aria2TaskDetailPageState extends State<Aria2TaskDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    await context.read<TaskController>().loadTaskDetailForDownloader(
      widget.taskId,
      widget.downloaderId,
      context.read<DownloaderController>(),
    );
  }

  void _pushChild(BuildContext context, String child) {
    context.push(
      '/tasks/detail/${widget.taskId}/aria2/$child'
      '?downloaderId=${widget.downloaderId}'
      '&taskName=${Uri.encodeComponent(widget.taskName)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final task = _matchingTask(context.watch<TaskController>().currentTask);

    return TaskDetailShell(
      taskId: widget.taskId,
      downloaderId: widget.downloaderId,
      taskName: widget.taskName,
      onRefresh: _load,
      body: Column(
        children: [
          _downloadSection(context, l10n, task),
          const SizedBox(height: 16),
          _connectionSection(context, l10n, task),
          const SizedBox(height: 16),
          NeoSection(
            title: l10n.taskMoreDetails,
            child: Column(
              children: [
                TaskDetailEntryCard(
                  title: l10n.taskFilesEntry,
                  subtitle: task != null ? '${task.fileCount ?? 0} files' : null,
                  icon: Icons.folder_outlined,
                  onTap: () => _pushChild(context, 'files'),
                ),
                TaskDetailEntryCard(
                  title: l10n.qbitServersEntry,
                  icon: Icons.dns_outlined,
                  onTap: () => _pushChild(context, 'servers'),
                ),
                TaskDetailEntryCard(
                  title: l10n.taskPeersEntry,
                  subtitle: task != null
                      ? '${task.connections ?? 0} connections'
                      : null,
                  icon: Icons.people_outline_rounded,
                  onTap: () => _pushChild(context, 'peers'),
                ),
                TaskDetailEntryCard(
                  title: l10n.taskOptionsEntry,
                  subtitle: l10n.taskOptionsShellSubtitle,
                  icon: Icons.tune_rounded,
                  onTap: () => _pushChild(context, 'options'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DownloadTask? _matchingTask(DownloadTask? task) {
    if (task == null) return null;
    if (task.id != widget.taskId || task.downloaderId != widget.downloaderId) {
      return null;
    }
    return task;
  }

  Widget _downloadSection(
    BuildContext context,
    AppLocalizations l10n,
    DownloadTask? task,
  ) {
    final statusText = task?.status.localizedLabel(context) ?? l10n.loading;
    final progress = (task?.progress ?? 0).clamp(0, 1).toDouble();
    final health = task?.healthPercent;
    return NeoSection(
      title: l10n.downloadInfoSection,
      child: Column(
        children: [
          _InfoRow(l10n.status, statusText),
          _InfoRow(l10n.progress, '${(progress * 100).toStringAsFixed(1)}%'),
          if (health != null)
            _InfoRow(l10n.aria2Health, '${(health * 100).toStringAsFixed(1)}%'),
          _InfoRow(
            l10n.downloadedOverTotal,
            task != null
                ? '${task.formattedDownloaded} / ${task.formattedSize}'
                : '--',
          ),
          _InfoRow(l10n.remainingTime, _formatEta(task, l10n)),
          _InfoRow(l10n.qbitSavePath, task?.savePath ?? '--'),
        ],
      ),
    );
  }

  Widget _connectionSection(
    BuildContext context,
    AppLocalizations l10n,
    DownloadTask? task,
  ) {
    final downloaderName = context
            .read<DownloaderController>()
            .getDownloader(widget.downloaderId)
            ?.name ??
        '--';
    return NeoSection(
      title: l10n.connectionInfoSection,
      child: Column(
        children: [
          _InfoRow(l10n.downloaderName, downloaderName),
          _InfoRow(l10n.tracker, task?.tracker ?? '--'),
          _InfoRow(l10n.connectionCount, '${task?.connections ?? '--'}'),
          _InfoRow(l10n.seeds, '${task?.seeders ?? '--'}'),
          if (task?.gid != null) _InfoRow('GID', task!.gid),
        ],
      ),
    );
  }

  /// 格式化剩余时间：超过 1 天时简化为 l10n 对应文案。
  String _formatEta(DownloadTask? task, AppLocalizations l10n) {
    if (task == null) return '--';
    if (task.downloadSpeed <= 0 || task.status != TaskStatus.downloading) {
      return '--';
    }
    final remaining = task.totalSize - task.downloaded;
    if (remaining <= 0) return '--';
    final seconds = remaining ~/ task.downloadSpeed;
    if (seconds > 86400) return l10n.aria2OverOneDay;
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分钟';
    return '${seconds ~/ 3600}小时${(seconds % 3600) ~/ 60}分钟';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
