import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/core/utils/app_version.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/core/utils/responsive_layout.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: Consumer<UpdateController>(
        builder: (context, update, _) {
          return ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top,
              bottom: AppSpacing.xl,
            ),
            children: [
              NeoPageHeader(title: l10n.my),
              ResponsiveContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeoCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: tokens.primaryAccent.withValues(
                              alpha: 0.14,
                            ),
                            child: Icon(
                              Icons.download_rounded,
                              color: tokens.primaryAccent,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.multiProtocolDownloaders,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withValues(alpha: 0.68),
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                FutureBuilder<String>(
                                  future: AppVersion.displayVersion(),
                                  builder: (context, snapshot) {
                                    final version = snapshot.data ?? '--';
                                    final meta = update.hasUpdate
                                        ? '$version · ${l10n.updateAvailableBadge}'
                                        : version;
                                    return Text(
                                      meta,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: update.hasUpdate
                                                ? tokens.primaryAccent
                                                : Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color
                                                      ?.withValues(alpha: 0.68),
                                            fontWeight: FontWeight.w700,
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
                    _sectionTitle(context, l10n.supportSectionTitle),
                    NeoSettingRow(
                      icon: Icons.privacy_tip_outlined,
                      title: l10n.privacyPolicy,
                      subtitle: l10n.privacyPolicyDesc,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openPrivacyPolicy(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    NeoSettingRow(
                      icon: Icons.mail_outline_rounded,
                      title: l10n.contactDeveloper,
                      subtitle: l10n.contactDeveloperDesc,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _contactDeveloper(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    NeoSettingRow(
                      icon: Icons.share_outlined,
                      title: l10n.shareApp,
                      subtitle: l10n.shareAppDesc,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _shareApp(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _sectionTitle(context, l10n.appSectionTitle),
                    NeoSettingRow(
                      icon: Icons.settings_outlined,
                      title: l10n.settings,
                      subtitle: l10n.settingsSubtitle,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/settings'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    NeoSettingRow(
                      icon: Icons.info_outline_rounded,
                      title: l10n.aboutWindTorrent,
                      subtitle: update.hasUpdate
                          ? l10n.updateAvailableBadge
                          : l10n.aboutSubtitle,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FutureBuilder<String>(
                            future: AppVersion.displayVersion(),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? '--',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(
            context,
          ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final ok = await launchUrl(
        Uri.parse(AppConstants.privacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        _showSnackBar(context, l10n.openLinkFailed);
      }
    } catch (e, st) {
      Log.e('打开隐私政策失败', error: e, stackTrace: st);
      if (context.mounted) {
        _showSnackBar(context, l10n.openLinkFailed);
      }
    }
  }

  Future<void> _contactDeveloper(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.parse(
      'mailto:${AppConstants.developerEmail}?subject=${Uri.encodeComponent(l10n.contactEmailSubject)}',
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        _showSnackBar(context, l10n.openLinkFailed);
      }
    } catch (e, st) {
      Log.e('打开邮件客户端失败', error: e, stackTrace: st);
      if (context.mounted) {
        _showSnackBar(context, l10n.openLinkFailed);
      }
    }
  }

  Future<void> _shareApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Share.share(
        l10n.shareAppMessage(l10n.appName, AppConstants.playStoreUrl),
      );
    } catch (e, st) {
      Log.e('分享失败', error: e, stackTrace: st);
      if (context.mounted) {
        _showSnackBar(context, l10n.shareFailed);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
