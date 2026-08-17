import 'package:flutter/material.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/transmission_task_peer.dart';

/// 展示单个 Transmission Peer（节点）信息的卡片。
///
/// 所有信息（客户端名、IP:端口、进度、速度）均在卡片内部展示，
/// 卡片宽度填满父容器。
class TransmissionPeerRow extends StatelessWidget {
  const TransmissionPeerRow({super.key, required this.peer});

  final TransmissionTaskPeer peer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final progressPercent = (peer.progress * 100).toStringAsFixed(1);

    return SizedBox(
      width: double.infinity,
      child: NeoCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：客户端名 + 进度百分比
          Row(
            children: [
              Expanded(
                child: Text(
                  peer.clientName,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progressPercent%',
                style:
                    textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 第二行：IP:端口
          Text(
            '${peer.address}:${peer.port}',
            style: textTheme.bodyMedium?.copyWith(
              color: textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          // 第三行：下载/上传速度
          Row(
            children: [
              Text(
                l10n.transmissionDownloadSpeed(_formatSpeed(peer.downloadSpeed)),
                style:
                    textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Text(
                l10n.transmissionUploadSpeed(_formatSpeed(peer.uploadSpeed)),
                style:
                    textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

/// 将 bytes/s 格式化为易读的速度单位。
String _formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
  if (bytesPerSecond < 1024 * 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
  return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
}
