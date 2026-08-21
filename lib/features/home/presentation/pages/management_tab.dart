import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/extensions/l10n_extensions.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/utils/responsive_layout.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_downloader_widgets.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';

class ManagementTab extends StatelessWidget {
  const ManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<DownloaderController>(
      builder: (context, controller, _) {
        return RefreshIndicator(
          onRefresh: controller.loadDownloaders,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ResponsiveLayout.getPadding(context).left,
              MediaQuery.paddingOf(context).top + AppSpacing.lg,
              ResponsiveLayout.getPadding(context).right,
              120,
            ),
            children: [
              _Header(
                title: l10n.downloadersTab,
                subtitle: l10n.manageConfiguredDownloaders,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle(label: l10n.configuredDownloaders),
              const SizedBox(height: AppSpacing.md),
              if (controller.isLoading && controller.downloaders.isEmpty)
                const NeoDownloaderLoadingState()
              else if (controller.downloaders.isEmpty)
                NeoDownloaderEmptyState(
                  title: l10n.noDownloadersYet,
                  subtitle: l10n.addDownloaderHint,
                )
              else
                ...controller.downloaders.map(
                  (downloader) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: NeoDownloaderCard(
                      downloader: downloader,
                      statusLabel: downloader.status.localizedLabel(context),
                      onOpenTasks: () => context.push(
                        '/tasks?id=${downloader.id}&type=${downloader.type.name}',
                      ),
                      onOpenConfig: () =>
                          context.push('/downloaders/${downloader.id}/config'),
                      onEdit: () =>
                          context.push('/downloaders/${downloader.id}/edit'),
                      onDelete: () => _confirmDelete(context, downloader),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Downloader downloader,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => NeoDownloaderDeleteDialog(
        title: l10n.deleteDownloader,
        message: l10n.confirmDeleteDownloader,
        cancelLabel: l10n.cancel,
        deleteLabel: l10n.delete,
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<DownloaderController>().removeDownloader(downloader.id);
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
