import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/extensions/l10n_extensions.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/downloaders/presentation/widgets/downloader_type_icon.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';

/// Formats a bytes-per-second value into a human-readable speed string.
String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 KB/s';
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var value = bytesPerSecond.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final fractionDigits = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}

/// Number of tasks that are actively consuming slots (downloading, waiting or
/// seeding), derived from aggregated stats.
int activeTaskCount(Map<String, int> stats) {
  return (stats['downloading'] ?? 0) +
      (stats['waiting'] ?? 0) +
      (stats['seeding'] ?? 0);
}

/// Total task count for the overview status section.
///
/// Newer aggregated stats include a real total that preserves tasks whose
/// status is unknown. Older cached/test stats gracefully fall back to the known
/// status buckets.
int totalTaskCount(Map<String, int> stats) {
  return stats['total'] ??
      (stats['downloading'] ?? 0) +
          (stats['waiting'] ?? 0) +
          (stats['paused'] ?? 0) +
          (stats['seeding'] ?? 0) +
          (stats['completed'] ?? 0) +
          (stats['error'] ?? 0);
}

/// Status accent color shared by headers, rows and the ring chart.
Color statusColor(DownloaderStatus status) {
  switch (status) {
    case DownloaderStatus.online:
      return AppColors.success;
    case DownloaderStatus.offline:
      return AppColors.textTertiaryLight;
    case DownloaderStatus.error:
      return AppColors.error;
  }
}

/// Brand header: real app icon, page title and an online-count badge.
class NeoOverviewHeader extends StatelessWidget {
  final String title;
  final int onlineCount;
  final int totalCount;

  const NeoOverviewHeader({
    super.key,
    required this.title,
    required this.onlineCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final textTheme = Theme.of(context).textTheme;
    final online = onlineCount > 0;

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: tokens.raisedSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: tokens.highlightColor.withValues(
                  alpha: tokens.isDark ? 0.05 : 0.9,
                ),
                offset: const Offset(-5, -5),
                blurRadius: 12,
              ),
              BoxShadow(
                color: tokens.shadowColor.withValues(
                  alpha: tokens.isDark ? 0.26 : 0.22,
                ),
                offset: const Offset(7, 7),
                blurRadius: 16,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset('assets/branding/app_icon_master.png'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(l10n.windTorrentConsole, style: textTheme.bodyMedium),
              const SizedBox(height: 8),
              NeoBadge(
                label: online
                    ? l10n.downloadersOnlineRatio(onlineCount, totalCount)
                    : l10n.waitingForDownloaderConnection,
                backgroundColor: online
                    ? tokens.successTint
                    : tokens.warningTint,
                foregroundColor: online ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Summary panel: total download/upload speed, active task count and quick
/// action shortcuts.
class NeoOverviewSummaryPanel extends StatelessWidget {
  final Map<String, int> stats;
  final List<Downloader> downloaders;
  final VoidCallback? onAddTask;
  final VoidCallback? onShowDownloaders;
  final VoidCallback? onShowTasks;

  const NeoOverviewSummaryPanel({
    super.key,
    required this.stats,
    required this.downloaders,
    this.onAddTask,
    this.onShowDownloaders,
    this.onShowTasks,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 总速率优先取 TaskDomainStore 实时摘要（qBit / Transmission），
    // 无摘要时回退 Downloader 模型（Aria2）。
    final controller = context.read<DownloaderController>();
    int totalDownloadSpeed = 0;
    int totalUploadSpeed = 0;
    for (final d in downloaders) {
      final summary = controller.realtimeSummary(d.id);
      totalDownloadSpeed += summary?.downloadSpeed ?? d.downloadSpeed;
      totalUploadSpeed += summary?.uploadSpeed ?? d.uploadSpeed;
    }

    return NeoSurface(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: l10n.totalDownloadSpeed,
                  value: formatSpeed(totalDownloadSpeed),
                  icon: Icons.south_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: _MetricPill(
                  label: l10n.activeTasks,
                  value: '${activeTaskCount(stats)}',
                  icon: Icons.bolt_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: _MetricPill(
                  label: l10n.totalUploadSpeed,
                  value: formatSpeed(totalUploadSpeed),
                  icon: Icons.north_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  label: l10n.addTaskButton,
                  icon: Icons.add_rounded,
                  onTap: onAddTask,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  label: l10n.downloadersTab,
                  icon: Icons.storage_rounded,
                  onTap: onShowDownloaders,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  label: l10n.viewTasks,
                  icon: Icons.task_alt_rounded,
                  onTap: onShowTasks,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Icon(icon, color: tokens.primaryAccent, size: 22),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: tokens.recessedSurface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: tokens.shadowColor.withValues(
                alpha: tokens.isDark ? 0.26 : 0.18,
              ),
              offset: const Offset(3, 3),
              blurRadius: 8,
            ),
            BoxShadow(
              color: tokens.highlightColor.withValues(
                alpha: tokens.isDark ? 0.04 : 0.78,
              ),
              offset: const Offset(-3, -3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: tokens.primaryAccent, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// 将状态字符串映射到 TaskStatus 枚举
TaskStatus? _statusFromString(String status) {
  switch (status) {
    case 'downloading':
      return TaskStatus.downloading;
    case 'waiting':
      return TaskStatus.waiting;
    case 'paused':
      return TaskStatus.paused;
    case 'seeding':
      return TaskStatus.seeding;
    case 'completed':
      return TaskStatus.completed;
    case 'error':
      return TaskStatus.error;
    default:
      return null;
  }
}

/// 3x2 task-status matrix showing counts per task state.
class NeoStatusMatrix extends StatelessWidget {
  final Map<String, int> stats;
  final void Function(TaskStatus)? onStatusTap;

  const NeoStatusMatrix({super.key, required this.stats, this.onStatusTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      _StatusItem(
        Icons.arrow_downward_rounded,
        l10n.downloading,
        stats['downloading'] ?? 0,
        AppColors.primary,
        'downloading',
      ),
      _StatusItem(
        Icons.schedule_rounded,
        l10n.waiting,
        stats['waiting'] ?? 0,
        AppColors.warning,
        'waiting',
      ),
      _StatusItem(
        Icons.pause_rounded,
        l10n.paused,
        stats['paused'] ?? 0,
        AppColors.textTertiaryLight,
        'paused',
      ),
      _StatusItem(
        Icons.upload_rounded,
        l10n.seeding,
        stats['seeding'] ?? 0,
        AppColors.success,
        'seeding',
      ),
      _StatusItem(
        Icons.task_alt_rounded,
        l10n.completed,
        stats['completed'] ?? 0,
        AppColors.success,
        'completed',
      ),
      _StatusItem(
        Icons.error_outline_rounded,
        l10n.error,
        stats['error'] ?? 0,
        AppColors.error,
        'error',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 104,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _StatusTile(
        item: items[index],
        onTap: () {
          final status = _statusFromString(items[index].statusKey);
          if (status != null) {
            onStatusTap?.call(status);
          }
        },
      ),
    );
  }
}

class _StatusItem {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String statusKey;

  const _StatusItem(
    this.icon,
    this.label,
    this.value,
    this.color,
    this.statusKey,
  );
}

class _StatusTile extends StatelessWidget {
  final _StatusItem item;
  final VoidCallback? onTap;

  const _StatusTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: NeoSurface(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${item.value}',
                maxLines: 1,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Downloader distribution: ring chart, per-type summary and tappable rows.
class NeoDownloaderDistribution extends StatelessWidget {
  final List<Downloader> downloaders;

  const NeoDownloaderDistribution({super.key, required this.downloaders});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (downloaders.isEmpty) {
      return NeoSurface(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(l10n.noDownloadersYet),
        ),
      );
    }

    return NeoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.downloaderDistribution,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: CustomPaint(
                  painter: _DownloaderRingPainter(downloaders),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _DownloaderTypeSummary(downloaders: downloaders)),
            ],
          ),
          const SizedBox(height: 16),
          for (final downloader in downloaders)
            _DownloaderDistributionRow(downloader: downloader),
        ],
      ),
    );
  }
}

/// Slices the ring by per-type downloader counts.
class _DownloaderRingPainter extends CustomPainter {
  final List<Downloader> downloaders;

  _DownloaderRingPainter(this.downloaders);

  static const _typeColors = <DownloaderType, Color>{
    DownloaderType.aria2: Color(0xFF2A7FFF),
    DownloaderType.qbittorrent: Color(0xFF14B8A6),
    DownloaderType.transmission: Color(0xFFEF4444),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final total = downloaders.length;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final ringThickness = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness
        ..color = const Color(0xFFE3E8F0),
    );

    if (total == 0) return;

    final perType = <DownloaderType, int>{
      for (final type in DownloaderType.values)
        type: downloaders.where((d) => d.type == type).length,
    };
    final sweep = 2 * math.pi;
    var startAngle = -math.pi / 2;

    perType.forEach((type, count) {
      if (count == 0) return;
      final slice = sweep * (count / total);
      canvas.drawArc(
        rect,
        startAngle,
        slice,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringThickness
          ..strokeCap = StrokeCap.round
          ..color = _typeColors[type]!,
      );
      startAngle += slice;
    });

    // Center total label.
    final textSpan = TextSpan(
      text: '$total',
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
    TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, center - const Offset(6, 12));
  }

  @override
  bool shouldRepaint(covariant _DownloaderRingPainter oldDelegate) {
    return oldDelegate.downloaders != downloaders;
  }
}

class _DownloaderTypeSummary extends StatelessWidget {
  final List<Downloader> downloaders;

  const _DownloaderTypeSummary({required this.downloaders});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final perType = <DownloaderType, int>{
      for (final type in DownloaderType.values)
        type: downloaders.where((d) => d.type == type).length,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.multiProtocolDownloaders,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final entry in perType.entries)
          if (entry.value > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _ringColor(entry.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.key.label} · ${entry.value}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Color _ringColor(DownloaderType type) {
    switch (type) {
      case DownloaderType.aria2:
        return const Color(0xFF2A7FFF);
      case DownloaderType.qbittorrent:
        return const Color(0xFF14B8A6);
      case DownloaderType.transmission:
        return const Color(0xFFEF4444);
    }
  }
}

class _DownloaderDistributionRow extends StatelessWidget {
  final Downloader downloader;

  const _DownloaderDistributionRow({required this.downloader});

  @override
  Widget build(BuildContext context) {
    // 实时字段优先取 TaskDomainStore 摘要（qBit / Transmission），
    // 无摘要时回退 Downloader 模型（Aria2）。
    final summary = context.read<DownloaderController>().realtimeSummary(
      downloader.id,
    );
    final status = summary?.status ?? downloader.status;
    final color = statusColor(status);
    final tasks = summary?.taskCount ?? downloader.taskCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push(
            '${AppConstants.tasksRoute}?id=${downloader.id}&type=${downloader.type.name}',
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                DownloaderTypeIcon(
                  type: downloader.type,
                  size: DownloaderTypeIconSize.medium,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        downloader.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${downloader.type.label} · ${formatSpeed(summary?.downloadSpeed ?? downloader.downloadSpeed)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$tasks',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      status.localizedLabel(context),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiaryLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
