import 'package:flutter/material.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/qbit_task_source.dart';

/// qBit 来源（DHT/PeX/LSD 等伪 tracker）卡片。
///
/// 展示来源名、状态徽章，及 peers/seeds/downloads/downloaded 计数。
class QBitSourceCard extends StatelessWidget {
  const QBitSourceCard({super.key, required this.source});

  final QBitTaskSource source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return NeoSection(
      title: source.name,
      trailing: NeoBadge(
        label: source.statusLabel,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _infoRow(
            label: l10n.qbitPeersLabel,
            value: '${source.peerCount}',
            textTheme: textTheme,
          ),
          _infoRow(
            label: l10n.qbitSeedsLabel,
            value: '${source.seedCount}',
            textTheme: textTheme,
          ),
          _infoRow(
            label: l10n.qbitDownloadsLabel,
            value: '${source.downloadCount}',
            textTheme: textTheme,
          ),
          _infoRow(
            label: l10n.qbitDownloadedLabel,
            value: '${source.downloadedCount}',
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    required TextTheme textTheme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(label, style: textTheme.bodyMedium)),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
