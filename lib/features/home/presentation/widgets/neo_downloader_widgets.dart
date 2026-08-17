import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/downloaders/presentation/widgets/downloader_type_icon.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';

/// Human-readable protocol label for a downloader connection.
String downloaderProtocolLabel(Downloader downloader) {
  return downloader.useHttps ? 'HTTPS' : 'HTTP';
}

/// Version label, falling back to an em-dash when unknown.
String downloaderVersionLabel(Downloader downloader) {
  final version = downloader.version;
  return version == null || version.isEmpty ? '—' : version;
}

/// Status accent color shared by the badge and other surfaces.
Color downloaderStatusColor(DownloaderStatus status) {
  switch (status) {
    case DownloaderStatus.online:
      return AppColors.success;
    case DownloaderStatus.error:
      return AppColors.error;
    case DownloaderStatus.offline:
      return AppColors.offline;
  }
}

/// Status badge tinted by the downloader's connection status.
class NeoDownloaderStatusBadge extends StatelessWidget {
  final String label;
  final DownloaderStatus status;

  const NeoDownloaderStatusBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = downloaderStatusColor(status);
    return NeoBadge(
      label: label,
      backgroundColor: color.withValues(alpha: 0.12),
      foregroundColor: color,
    );
  }
}

/// Inset neumorphic pill for static info like type/version/protocol.
class NeoDownloaderInfoPill extends StatelessWidget {
  final String label;

  const NeoDownloaderInfoPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.recessedSurface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowColor.withValues(
              alpha: tokens.isDark ? 0.32 : 0.18,
            ),
            offset: const Offset(3, 3),
            blurRadius: 7,
          ),
          BoxShadow(
            color: tokens.highlightColor.withValues(
              alpha: tokens.isDark ? 0.035 : 0.72,
            ),
            offset: const Offset(-3, -3),
            blurRadius: 7,
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(
            context,
          ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Neumorphic card describing one downloader: identity, info pills, actions.
class NeoDownloaderCard extends StatelessWidget {
  final Downloader downloader;
  final String statusLabel;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenConfig;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NeoDownloaderCard({
    super.key,
    required this.downloader,
    required this.statusLabel,
    required this.onOpenTasks,
    required this.onOpenConfig,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 状态徽章颜色优先取 TaskDomainStore 实时摘要（qBit / Transmission），
    // 无摘要时回退 Downloader 模型（Aria2）。
    final status =
        context.read<DownloaderController>().realtimeSummary(downloader.id)?.status ??
        downloader.status;
    return NeoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DownloaderTypeIcon(
                type: downloader.type,
                size: DownloaderTypeIconSize.large,
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${downloader.host}:${downloader.port}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              NeoDownloaderStatusBadge(
                label: statusLabel,
                status: status,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NeoDownloaderInfoPill(label: downloader.type.label),
              NeoDownloaderInfoPill(label: downloaderVersionLabel(downloader)),
              NeoDownloaderInfoPill(label: downloaderProtocolLabel(downloader)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _NeoDownloaderActionButton(
                  label: l10n.taskList,
                  isPrimary: true,
                  onTap: onOpenTasks,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _NeoDownloaderActionButton(
                  label: l10n.config,
                  onTap: onOpenConfig,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: NeoDownloaderMoreMenu(
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeoDownloaderActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _NeoDownloaderActionButton({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _NeoDownloaderActionDecoration(label: label, isPrimary: isPrimary),
    );
  }
}

/// Shared, non-gestural decoration used by both plain buttons and the
/// [PopupMenuButton] trigger. Keeping it gesture-free avoids the popup being
/// swallowed by a nested [GestureDetector].
class _NeoDownloaderActionDecoration extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _NeoDownloaderActionDecoration({
    required this.label,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.raisedSurface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: tokens.highlightColor.withValues(
              alpha: tokens.isDark ? 0.04 : 0.75,
            ),
            offset: const Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: tokens.shadowColor.withValues(
              alpha: tokens.isDark ? 0.28 : 0.24,
            ),
            offset: const Offset(4, 4),
            blurRadius: 9,
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isPrimary
              ? tokens.primaryAccent
              : Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// "更多" action that opens a popup with edit/delete options.
class NeoDownloaderMoreMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NeoDownloaderMoreMenu({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      tooltip: l10n.moreActions,
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            l10n.delete,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ],
      child: _NeoDownloaderActionDecoration(
        label: l10n.moreActions,
        isPrimary: false,
      ),
    );
  }
}

/// Neumorphic delete confirmation dialog. Pops with `true` when confirmed.
class NeoDownloaderDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelLabel;
  final String deleteLabel;

  const NeoDownloaderDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: NeoSurface(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(cancelLabel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(deleteLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state card shown when no downloaders are configured.
class NeoDownloaderEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const NeoDownloaderEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return NeoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Loading spinner shown while downloaders are being fetched.
class NeoDownloaderLoadingState extends StatelessWidget {
  const NeoDownloaderLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.xxxl),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
