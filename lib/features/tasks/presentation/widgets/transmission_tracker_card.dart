import 'package:flutter/material.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/transmission_task_tracker.dart';

/// 展示单个 Transmission Tracker 信息的卡片。
///
/// 包含主机名、Tier、announce/scrape 时间、做种/下载/完成计数，
/// 以及可选的错误信息。
class TransmissionTrackerCard extends StatelessWidget {
  const TransmissionTrackerCard({super.key, required this.tracker});

  final TransmissionTaskTracker tracker;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return NeoSection(
      title: tracker.host,
      trailing: _tierBadge(context, l10n),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _infoRow('Announce', tracker.announce),
          if (tracker.lastAnnounceAt != null)
            _infoRow('Last Announce', tracker.lastAnnounceAt!.toString()),
          if (tracker.nextAnnounceAt != null)
            _infoRow('Next Announce', tracker.nextAnnounceAt!.toString()),
          if (tracker.lastScrapeAt != null)
            _infoRow('Last Scrape', tracker.lastScrapeAt!.toString()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                l10n.transmissionSeeds(tracker.seederCount),
                style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                l10n.transmissionLeeches(tracker.leecherCount),
                style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                l10n.transmissionDownloads(tracker.downloadCount),
                style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (tracker.errorMessage != null &&
              tracker.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tracker.errorMessage!,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tierBadge(BuildContext context, AppLocalizations l10n) {
    return NeoBadge(
      label: l10n.transmissionTier(tracker.tier),
      backgroundColor:
          Theme.of(context).colorScheme.primaryContainer,
      foregroundColor:
          Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
