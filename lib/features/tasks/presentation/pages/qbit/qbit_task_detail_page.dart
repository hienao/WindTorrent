import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_detail_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_entry_card.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/qbit_task_detail.dart';
import 'package:windwalker/models/qbit_task_file_node.dart';

/// qBittorrent 任务详情信息主页。
///
/// 展示 Progress / Transfer / Torrent Info / HTTP Sources 四个信息分组，
/// 以及「文件 / 服务器 / 节点 / 选项」子页面入口。
/// 通用任务态（进度/速度等）由共享 [TaskDetailShell] + [TaskDomainStore] 提供，
/// qBit 完整详情由 [QBitTaskDetailController] 加载。
class QBitTaskDetailPage extends StatefulWidget {
  const QBitTaskDetailPage({
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
  final QBitTaskDetailController? controller;

  @override
  State<QBitTaskDetailPage> createState() => _QBitTaskDetailPageState();
}

class _QBitTaskDetailPageState extends State<QBitTaskDetailPage> {
  late final QBitTaskDetailController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = QBitTaskDetailController();
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
    final downloader =
        context.read<DownloaderController>().getDownloader(widget.downloaderId);
    if (downloader == null) return;
    await _controller.load(taskId: widget.taskId, downloader: downloader);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<QBitTaskDetailController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        // 动态字段（进度/速度等）由全局 qBit 快照经 TaskDomainStore 共享缓存驱动；
        // 静态完整详情（transfer / torrent info / http sources）在此首次加载，
        // 下拉刷新时重新获取。
        onRefresh: _load,
        body: Consumer<QBitTaskDetailController>(
          builder: (context, controller, _) {
            final l10n = AppLocalizations.of(context)!;
            final detail = _matchingDetail(controller.detail);
            if (controller.isLoading && detail == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.errorMessage != null && detail == null) {
              return NeoSection(
                title: l10n.qbitProgressSection,
                child: Text(controller.errorMessage!),
              );
            }
            return _QBitDetailBody(
              detail: detail,
              onFiles: () => _pushChild(context, 'files'),
              onSources: () => _pushChild(context, 'sources'),
              onPeers: () => _pushChild(context, 'peers'),
              onOptions: () => _pushChild(context, 'options'),
            );
          },
        ),
      ),
    );
  }

  /// 仅当详情同时匹配 taskId 与 downloaderId 时才视为本页面详情。
  QBitTaskDetail? _matchingDetail(QBitTaskDetail? detail) {
    if (detail == null) return null;
    if (detail.taskId != widget.taskId ||
        detail.downloaderId != widget.downloaderId) {
      return null;
    }
    return detail;
  }

  /// 跳转到 qBit 子页面（files / sources / peers / options）。
  ///
  /// 使用完整路径 push（与 Transmission 详情页同一约定），路径参数显式拼接。
  void _pushChild(BuildContext context, String child) {
    context.push(
      '/tasks/detail/${widget.taskId}/qbit/$child'
      '?downloaderId=${widget.downloaderId}'
      '&taskName=${Uri.encodeComponent(widget.taskName)}',
    );
  }
}

class _QBitDetailBody extends StatelessWidget {
  const _QBitDetailBody({
    required this.detail,
    required this.onFiles,
    required this.onSources,
    required this.onPeers,
    required this.onOptions,
  });

  final QBitTaskDetail? detail;
  final VoidCallback onFiles;
  final VoidCallback onSources;
  final VoidCallback onPeers;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _TransferSection(detail: detail),
        const SizedBox(height: 16),
        _TorrentInfoSection(detail: detail),
        const SizedBox(height: 16),
        _HttpSourcesSection(detail: detail),
        const SizedBox(height: 16),
        NeoSection(
          title: l10n.taskMoreDetails,
          child: Column(
            children: [
              TaskDetailEntryCard(
                title: l10n.taskFilesEntry,
                icon: Icons.folder_outlined,
                onTap: onFiles,
              ),
              TaskDetailEntryCard(
                title: l10n.qbitServersEntry,
                subtitle: l10n.qbitSourceCount(detail?.sourceCount ?? 0),
                icon: Icons.dns_outlined,
                onTap: onSources,
              ),
              TaskDetailEntryCard(
                title: l10n.taskPeersEntry,
                subtitle: detail != null
                    ? l10n.qbitPeerSummary(
                        detail!.peerCount, detail!.leechs + detail!.seeds)
                    : null,
                icon: Icons.people_outline_rounded,
                onTap: onPeers,
              ),
              TaskDetailEntryCard(
                title: l10n.qbitOptionsEntry,
                subtitle: l10n.qbitOptionsSubtitle,
                icon: Icons.tune_rounded,
                onTap: onOptions,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransferSection extends StatelessWidget {
  const _TransferSection({required this.detail});
  final QBitTaskDetail? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return NeoSection(
      title: l10n.taskTransferSection,
      child: Column(
        children: [
          _InfoRow(
              label: l10n.qbitDownloaded,
              value: formatQBitBytes(detail?.downloaded ?? 0)),
          _InfoRow(
              label: l10n.qbitUploaded,
              value: formatQBitBytes(detail?.uploaded ?? 0)),
          _InfoRow(
              label: l10n.qbitRatio,
              value: (detail?.shareRatio ?? 0).toStringAsFixed(2)),
          _InfoRow(
              label: l10n.qbitAvailability,
              value: '${(detail?.availability ?? 0).toStringAsFixed(1)}%'),
          _InfoRow(
              label: l10n.qbitAvgDownload,
              value: '${formatQBitBytes(detail?.dlSpeedAvg ?? 0)}/s'),
          _InfoRow(
              label: l10n.qbitAvgUpload,
              value: '${formatQBitBytes(detail?.upSpeedAvg ?? 0)}/s'),
          _InfoRow(
              label: l10n.qbitDlLimit,
              value: _fmtSpeedLimit(detail?.dlLimit ?? -1)),
          _InfoRow(
              label: l10n.qbitUpLimit,
              value: _fmtSpeedLimit(detail?.upLimit ?? -1)),
          _InfoRow(label: l10n.qbitEta, value: _fmtDuration(detail?.eta ?? 0)),
          _InfoRow(label: l10n.qbitSeeds, value: '${detail?.seeds ?? 0}'),
          _InfoRow(
              label: l10n.qbitConnections,
              value:
                  '${detail?.connections ?? 0} / ${detail?.connectionsLimit ?? 0}'),
          _InfoRow(
              label: l10n.qbitActivityTime,
              value: _fmtDuration(detail?.timeElapsed ?? 0)),
          _InfoRow(
              label: l10n.qbitSeedingTime,
              value: _fmtDuration(detail?.seedingTime ?? 0)),
          _InfoRow(
              label: l10n.qbitPriority,
              value: _fmtPriority(detail?.queuePosition ?? -1)),
        ],
      ),
    );
  }
}

class _TorrentInfoSection extends StatelessWidget {
  const _TorrentInfoSection({required this.detail});
  final QBitTaskDetail? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final category = detail?.category ?? '';
    final tags = detail?.tags ?? const [];
    return NeoSection(
      title: l10n.taskTorrentInfoSection,
      child: Column(
        children: [
          _InfoRow(
              label: l10n.qbitTotalSize,
              value: formatQBitBytes(detail?.totalSize ?? 0)),
          _InfoRow(
              label: l10n.qbitBlocks,
              value:
                  '${detail?.completedPieceCount ?? 0} / ${detail?.pieceCount ?? 0} × ${formatQBitBytes(detail?.pieceSize ?? 0)}'),
          _InfoRow(label: l10n.qbitSavePath, value: detail?.savePath ?? '--'),
          _InfoRow(label: l10n.qbitCategoryLabel, value: category.isEmpty ? '--' : category),
          _InfoRow(
              label: l10n.qbitTagsLabel, value: tags.isEmpty ? '--' : tags.join(', ')),
          _InfoRow(
              label: l10n.qbitInfoHashV1,
              value: detail?.infoHashV1?.isNotEmpty == true
                  ? detail!.infoHashV1!
                  : l10n.qbitNotAvailable),
          _InfoRow(
              label: l10n.qbitInfoHashV2,
              value: detail?.infoHashV2?.isNotEmpty == true
                  ? detail!.infoHashV2!
                  : l10n.qbitNotAvailable),
        ],
      ),
    );
  }
}

class _HttpSourcesSection extends StatelessWidget {
  const _HttpSourcesSection({required this.detail});
  final QBitTaskDetail? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = detail?.httpSourceCount ?? 0;
    return NeoSection(
      title: l10n.qbitHttpSourcesSection,
      child: Text(count == 0
          ? l10n.qbitNoHttpSources
          : l10n.qbitHttpSourceCount(count)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
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

String _fmtDuration(int seconds) {
  if (seconds <= 0) return '--';
  final d = Duration(seconds: seconds);
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}

String _fmtPriority(int position) {
  if (position < 0) return '--';
  return '#$position';
}

String _fmtSpeedLimit(int bytesPerSec) {
  if (bytesPerSec <= 0) return '∞';
  return '${formatQBitBytes(bytesPerSec)}/s';
}
