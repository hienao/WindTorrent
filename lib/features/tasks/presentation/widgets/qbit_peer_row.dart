import 'package:flutter/material.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/qbit_task_peer.dart';

/// qBit 对端密集行卡片。
///
/// 标题为 `ip:port`，下方为协议徽章 + 状态标签徽章，及速度/流量/进度/相关性。
class QBitPeerRow extends StatelessWidget {
  const QBitPeerRow({super.key, required this.peer});

  final QBitTaskPeer peer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final container = Theme.of(context).colorScheme.primaryContainer;
    final onContainer = Theme.of(context).colorScheme.onPrimaryContainer;

    return NeoSection(
      title: '${peer.address}:${peer.port}',
      trailing: NeoBadge(
        label: peer.protocol,
        backgroundColor: container,
        foregroundColor: onContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (peer.stateTags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final tag in peer.stateTags)
                  NeoBadge(
                    label: tag,
                    backgroundColor: container,
                    foregroundColor: onContainer,
                  ),
              ],
            ),
          if (peer.stateTags.isNotEmpty) const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth < 360;
              final metrics = [
                _PeerMetric(
                  value: peer.formattedDownloadSpeed,
                  label: l10n.qbitDownload,
                  prefix: '↓',
                ),
                _PeerMetric(
                  value: peer.formattedUploadSpeed,
                  label: l10n.qbitUpload,
                  prefix: '↑',
                ),
                _PeerMetric(
                  value: peer.formattedDownloaded,
                  label: l10n.qbitDownloaded,
                ),
                _PeerMetric(
                  value: peer.formattedUploaded,
                  label: l10n.qbitUploaded,
                ),
              ];

              if (useTwoColumns) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: itemWidth,
                        child: _PeerMetricBlock(
                          metric: metric,
                          textTheme: textTheme,
                        ),
                      ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final metric in metrics)
                    Expanded(
                      child: _PeerMetricBlock(
                        metric: metric,
                        textTheme: textTheme,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: NeoProgress(value: peer.progress, minHeight: 8)),
              const SizedBox(width: 12),
              Text(
                peer.progressLabel,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.qbitFileAffinity} ${peer.relevancePercent}',
            textAlign: TextAlign.left,
            style: textTheme.bodySmall?.copyWith(
              color: textTheme.bodySmall?.color?.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerMetric {
  const _PeerMetric({required this.value, required this.label, this.prefix});

  final String value;
  final String label;
  final String? prefix;
}

class _PeerMetricBlock extends StatelessWidget {
  const _PeerMetricBlock({required this.metric, required this.textTheme});

  final _PeerMetric metric;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final mutedColor = textTheme.bodySmall?.color?.withValues(alpha: 0.72);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          metric.prefix == null
              ? metric.value
              : '${metric.prefix} ${metric.value}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          metric.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: mutedColor, height: 1.2),
        ),
      ],
    );
  }
}
