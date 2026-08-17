import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/utils/peer_id_parser.dart';
import 'package:windwalker/models/qbit_task_file_node.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/aria2_task_peers_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/aria2/aria2_task_peer.dart';

/// Aria2 节点子页面。
///
/// 每个节点独立卡片，展示地址、客户端、速度等信息。
class Aria2TaskPeersPage extends StatefulWidget {
  const Aria2TaskPeersPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final Aria2TaskPeersController? controller;

  @override
  State<Aria2TaskPeersPage> createState() => _Aria2TaskPeersPageState();
}

class _Aria2TaskPeersPageState extends State<Aria2TaskPeersPage> {
  late final Aria2TaskPeersController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = Aria2TaskPeersController();
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
    return ChangeNotifierProvider<Aria2TaskPeersController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        onRefresh: _load,
        body: Consumer<Aria2TaskPeersController>(
          builder: (context, controller, _) {
            if (controller.isLoading && controller.peers.isEmpty) {
              return NeoSection(
                title: l10n.taskPeersEntry,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }
            if (controller.errorMessage != null && controller.peers.isEmpty) {
              return NeoSection(
                title: l10n.taskPeersEntry,
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
            if (controller.peers.isEmpty) {
              return NeoSection(
                title: l10n.taskPeersEntry,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.qbitNoPeers),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final peer in controller.peers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PeerCard(peer: peer),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 单个节点卡片。
class _PeerCard extends StatelessWidget {
  const _PeerCard({required this.peer});
  final Aria2TaskPeer peer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final peerInfo = PeerIdParser.parse(peer.peerId);
    final clientDisplay = peerInfo.display;

    return NeoSection(
      title: peer.address,
      trailing: _StatusBadge(isSeeder: peer.seeder),
      child: Column(
        children: [
          if (clientDisplay != 'unknown')
            _PeerInfoRow(label: l10n.aria2PeerClient, value: clientDisplay),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  icon: Icons.arrow_downward_rounded,
                  value: '${formatBytes(peer.downloadSpeed)}/s',
                  label: l10n.currentDownloadSpeed,
                  color: colorScheme.primary,
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  icon: Icons.arrow_upward_rounded,
                  value: '${formatBytes(peer.uploadSpeed)}/s',
                  label: l10n.currentUploadSpeed,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isSeeder});
  final bool isSeeder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSeeder
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isSeeder ? l10n.aria2Seeder : l10n.aria2Leech,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isSeeder
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PeerInfoRow extends StatelessWidget {
  const _PeerInfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: textTheme.bodySmall, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            )),
            Text(label, style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      ],
    );
  }
}
