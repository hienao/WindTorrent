import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_detail_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_entry_card.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/transmission_task_detail.dart';

/// Transmission 任务详情信息主页。
///
/// 展示 Torrent Info / Transfer / Date / Runtime 四个信息分组，
/// 以及「文件 / 服务器 / 节点 / 选项」子页面入口。
/// 通用任务态（进度/速度等）由共享 [TaskDetailShell] + [TaskDomainStore] 提供，
/// 完整详情由 [TransmissionTaskDetailController] 加载。
class TransmissionTaskDetailPage extends StatefulWidget {
  const TransmissionTaskDetailPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;

  @override
  State<TransmissionTaskDetailPage> createState() =>
      _TransmissionTaskDetailPageState();
}

class _TransmissionTaskDetailPageState
    extends State<TransmissionTaskDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailController = context.watch<TransmissionTaskDetailController>();

    return TaskDetailShell(
      taskId: widget.taskId,
      downloaderId: widget.downloaderId,
      taskName: widget.taskName,
      // 动态字段（进度/速度/状态）由全局 Transmission 快照经 TaskDomainStore
      // 共享缓存驱动；完整详情在此首次加载，下拉刷新时重新获取。
      onRefresh: _load,
      body: _bodyForState(l10n, detailController),
    );
  }

  /// 根据 Transmission 详情加载态选择 body：
  /// 加载中显示 spinner，失败显示错误，成功显示信息分组。
  Widget _bodyForState(
    AppLocalizations l10n,
    TransmissionTaskDetailController detailController,
  ) {
    final detail = _matchingDetail(detailController.detail);
    if (detailController.isLoading && detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (detailController.errorMessage != null && detail == null) {
      return NeoSection(
        title: l10n.taskMoreDetails,
        child: Text(detailController.errorMessage!),
      );
    }
    return _body(l10n, detail);
  }

  Future<void> _load() async {
    if (!mounted) return;
    final downloader = context
        .read<DownloaderController>()
        .getDownloader(widget.downloaderId);
    if (downloader == null) return;
    // 动态字段（进度/速度/状态）由全局 Transmission 快照经 TaskDomainStore
    // 共享缓存提供；此处只加载完整详情（torrent info / transfer / dates 等）。
    await context.read<TransmissionTaskDetailController>().load(
          taskId: widget.taskId,
          downloader: downloader,
        );
  }

  TransmissionTaskDetail? _matchingDetail(TransmissionTaskDetail? detail) {
    if (detail == null) return null;
    if (detail.taskId != widget.taskId ||
        detail.downloaderId != widget.downloaderId) {
      return null;
    }
    return detail;
  }

  /// 跳转到 Transmission 子页面（files / trackers / peers / options）。
  void _pushChild(BuildContext context, String child) {
    context.push(
      '/tasks/detail/${widget.taskId}/transmission/$child'
      '?downloaderId=${widget.downloaderId}'
      '&taskName=${Uri.encodeComponent(widget.taskName)}',
    );
  }

  Widget _body(AppLocalizations l10n, TransmissionTaskDetail? detail) {
    return Column(
      children: [
        TransmissionInfoSection(
          title: l10n.taskTorrentInfoSection,
          children: [
            TransmissionInfoRow(
              label: l10n.totalSize,
              value:
                  '${_formatBytes(detail?.totalSize ?? 0)} (${detail?.pieceCount ?? 0} x ${_formatBytes(detail?.pieceSize ?? 0)})',
            ),
            TransmissionInfoRow(label: l10n.savePath, value: detail?.savePath ?? '--'),
            TransmissionInfoRow(
              label: l10n.privacy,
              value: detail?.isPrivate == true ? l10n.yes : l10n.no,
            ),
            TransmissionInfoRow(label: l10n.creator, value: detail?.creator ?? '--'),
            TransmissionInfoRow(
              label: l10n.createdAt,
              value: _formatDateTime(detail?.createdAt),
            ),
            TransmissionInfoRow(label: l10n.magnet, value: detail?.magnet ?? '--'),
          ],
        ),
        const SizedBox(height: 16),
        TransmissionInfoSection(
          title: l10n.taskTransferSection,
          children: [
            TransmissionInfoRow(
              label: l10n.totalDownloaded,
              value: _formatBytes(detail?.downloadedEver ?? 0),
            ),
            TransmissionInfoRow(
              label: l10n.availability,
              value:
                  '${(((detail?.availablePercent ?? 0)) * 100).toStringAsFixed(1)}%',
            ),
            TransmissionInfoRow(
              label: l10n.totalUploaded,
              value: _formatBytes(detail?.uploadedEver ?? 0),
            ),
            TransmissionInfoRow(
              label: l10n.shareRatio,
              value: (detail?.ratio ?? 0).toStringAsFixed(4),
            ),
            TransmissionInfoRow(
              label: l10n.averageSpeed,
              value: '${_formatBytes(detail?.averageSpeed ?? 0)}/s',
            ),
          ],
        ),
        const SizedBox(height: 16),
        TransmissionInfoSection(
          title: l10n.taskDateSection,
          children: [
            TransmissionInfoRow(
              label: l10n.addedAt,
              value: _formatDateTime(detail?.addedAt),
            ),
            TransmissionInfoRow(
              label: l10n.completedAt,
              value: _formatDateTime(detail?.completedAt),
            ),
            TransmissionInfoRow(
              label: l10n.lastActivityAt,
              value: _formatDateTime(detail?.lastActivityAt),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TransmissionInfoSection(
          title: l10n.taskRuntimeSection,
          children: [
            TransmissionInfoRow(
              label: l10n.downloadDuration,
              value: _formatDuration(detail?.downloadDuration ?? Duration.zero),
            ),
            TransmissionInfoRow(
              label: l10n.seedingDuration,
              value: _formatDuration(detail?.seedingDuration ?? Duration.zero),
            ),
          ],
        ),
        const SizedBox(height: 16),
        NeoSection(
          title: l10n.taskMoreDetails,
          child: Column(
            children: [
              TaskDetailEntryCard(
                title: l10n.taskFilesEntry,
                subtitle: '${detail?.fileCount ?? 0} files',
                icon: Icons.folder_outlined,
                onTap: () => _pushChild(context, 'files'),
              ),
              TaskDetailEntryCard(
                title: l10n.taskTrackersEntry,
                subtitle: '${detail?.trackerCount ?? 0} trackers',
                icon: Icons.dns_outlined,
                onTap: () => _pushChild(context, 'trackers'),
              ),
              TaskDetailEntryCard(
                title: l10n.taskPeersEntry,
                subtitle: '${detail?.peerCount ?? 0} peers',
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
    );
  }
}

class TransmissionInfoSection extends StatelessWidget {
  const TransmissionInfoSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NeoSection(
      title: title,
      child: Column(children: children),
    );
  }
}

class TransmissionInfoRow extends StatelessWidget {
  const TransmissionInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

/// 将 DateTime 格式化为本地时区的可读字符串（不含 T）。
String _formatDateTime(DateTime? dt) {
  if (dt == null) return '--';
  final local = dt.toLocal();
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(local);
}

/// 将 Duration 格式化为 "Xh Ym" 或 "Ym" 形式，精确到分钟。
String _formatDuration(Duration d) {
  if (d == Duration.zero) return '--';
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

/// 将字节数格式化为易读的大小字符串。
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
