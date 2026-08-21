import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/utils/responsive_layout.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_overview_widgets.dart';
import 'package:windwalker/l10n/app_localizations.dart';

class DataTab extends StatelessWidget {
  final VoidCallback? onShowDownloaders;
  final void Function(TaskStatus?)? onShowTasks;

  const DataTab({super.key, this.onShowDownloaders, this.onShowTasks});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<DownloaderController>(
      builder: (context, controller, _) {
        final stats = controller.globalStats;
        final totalTasks = totalTaskCount(stats);
        final downloaders = controller.downloaders;
        final onlineCount = downloaders
            .where((downloader) => downloader.status == DownloaderStatus.online)
            .length;

        return RefreshIndicator(
          edgeOffset: 16,
          displacement: 28,
          onRefresh: () async {
            await controller.refreshAllStatus();
            await controller.refreshGlobalStats();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: ResponsiveContainer(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveLayout.getPadding(context).left,
                      AppSpacing.lg,
                      ResponsiveLayout.getPadding(context).right,
                      AppSpacing.md,
                    ),
                    child: NeoOverviewHeader(
                      title: l10n.data,
                      onlineCount: onlineCount,
                      totalCount: downloaders.length,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ResponsiveContainer(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveLayout.getPadding(context).left,
                  ),
                  child: NeoOverviewSummaryPanel(
                    stats: stats,
                    downloaders: downloaders,
                    onAddTask: () => context.push(AppConstants.addTaskRoute),
                    onShowDownloaders: onShowDownloaders,
                    onShowTasks: onShowTasks != null
                        ? () => onShowTasks!(null)
                        : null,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ResponsiveContainer(
                  padding: EdgeInsets.fromLTRB(
                    ResponsiveLayout.getPadding(context).left,
                    AppSpacing.xl,
                    ResponsiveLayout.getPadding(context).right,
                    0,
                  ),
                  child: NeoSection(
                    title: l10n.taskStatusOverview,
                    trailing: Text(
                      l10n.taskTotalKicker(totalTasks),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                      ),
                    ),
                    child: NeoStatusMatrix(
                      stats: stats,
                      onStatusTap: onShowTasks,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ResponsiveContainer(
                  padding: EdgeInsets.fromLTRB(
                    ResponsiveLayout.getPadding(context).left,
                    AppSpacing.xl,
                    ResponsiveLayout.getPadding(context).right,
                    120,
                  ),
                  child: NeoDownloaderDistribution(downloaders: downloaders),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
