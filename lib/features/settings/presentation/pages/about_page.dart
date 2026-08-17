import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/core/utils/app_version.dart';
import 'package:windwalker/core/utils/responsive_layout.dart';
import 'package:windwalker/core/utils/review_manager.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final update = context.watch<UpdateController>();
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            NeoPageHeader(
              title: l10n.aboutWindTorrent,
              subtitle: AppConstants.appName,
              onBack: () => context.pop(),
            ),
            ResponsiveContainer(
              child: Column(
                children: [
                  NeoCard(
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: tokens.primaryAccent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Icon(
                            Icons.air_rounded,
                            color: tokens.primaryAccent,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.appName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              FutureBuilder<String>(
                                future: AppVersion.displayVersion(),
                                builder: (context, snapshot) {
                                  return Text(
                                    '${l10n.version} ${snapshot.data ?? '--'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withValues(alpha: 0.68),
                                        ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NeoSettingRow(
                    icon: Icons.system_update_alt_rounded,
                    title: l10n.checkForUpdates,
                    subtitle: _updateStatusLabel(l10n, update.status),
                    trailing: update.isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => _checkForUpdates(context, l10n),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  NeoSettingRow(
                    icon: Icons.star_outline_rounded,
                    title: l10n.rateApp,
                    subtitle: l10n.rateAppDesc,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => ReviewManager().openStoreListing(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _updateStatusLabel(AppLocalizations l10n, UpdateCheckStatus status) {
    return switch (status) {
      UpdateCheckStatus.available => l10n.newVersionAvailable,
      UpdateCheckStatus.upToDate => l10n.upToDate,
      UpdateCheckStatus.unknown => l10n.updateCheckUnavailable,
      UpdateCheckStatus.unsupported => l10n.updateCheckNotSupported,
    };
  }

  Future<void> _checkForUpdates(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    await context.read<UpdateController>().checkForUpdatesManually();
    if (!context.mounted) return;
    if (context.read<UpdateController>().hasUpdate) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: NeoCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.updateAvailableTitle,
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.updateAvailableMessage),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: NeoButton.secondary(
                        onPressed: () => Navigator.pop(ctx, false),
                        label: Text(l10n.later),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: NeoButton.primary(
                        onPressed: () => Navigator.pop(ctx, true),
                        label: Text(l10n.updateNow),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (!context.mounted) return;
      if (go == true) {
        await context.read<UpdateController>().openStorePage();
      }
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (context.read<UpdateController>().status) {
            UpdateCheckStatus.available => l10n.upToDate,
            UpdateCheckStatus.upToDate => l10n.upToDate,
            UpdateCheckStatus.unknown => l10n.updateCheckUnavailable,
            UpdateCheckStatus.unsupported => l10n.updateCheckNotSupported,
          }),
        ),
      );
    }
  }
}
