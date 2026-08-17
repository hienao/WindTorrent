import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_peers_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/qbit_peer_row.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';

/// qBit 节点(对端)子页面。
///
/// 展示任务的对端密集行。
/// 自行创建 [QBitTaskPeersController] 管理生命周期，
/// 接受可选 [controller] 参数用于测试注入。
class QBitTaskPeersPage extends StatefulWidget {
  const QBitTaskPeersPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final QBitTaskPeersController? controller;

  @override
  State<QBitTaskPeersPage> createState() => _QBitTaskPeersPageState();
}

class _QBitTaskPeersPageState extends State<QBitTaskPeersPage> {
  late final QBitTaskPeersController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = QBitTaskPeersController();
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
    return ChangeNotifierProvider<QBitTaskPeersController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        onRefresh: _load,
        body: Consumer<QBitTaskPeersController>(
          builder: (context, controller, _) {
            final l10n = AppLocalizations.of(context)!;
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
                    child: QBitPeerRow(peer: peer),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
