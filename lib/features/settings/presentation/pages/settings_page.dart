import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/core/utils/responsive_layout.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_backup_controller.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader_backup_version.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _lastSeenError;
  String? _lastSeenSummary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: SafeArea(
        child: Consumer2<SettingsController, SettingsBackupController>(
          builder: (context, settings, backup, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              if (backup.errorMessage != null &&
                  backup.errorMessage != _lastSeenError) {
                _lastSeenError = backup.errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(backup.errorMessage!),
                    action: SnackBarAction(
                      label: l10n.cancel,
                      onPressed: () => backup.clearError(),
                    ),
                  ),
                );
              }
              if (backup.lastOperationSummary != null &&
                  backup.lastOperationSummary != _lastSeenSummary) {
                _lastSeenSummary = backup.lastOperationSummary;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(backup.lastOperationSummary!)),
                );
              }
            });

            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                NeoPageHeader(
                  title: l10n.settings,
                  subtitle: l10n.generalSettings,
                  onBack: () => context.pop(),
                ),
                ResponsiveContainer(
                  child: Column(
                    children: [
                      NeoSettingRow(
                        icon: Icons.palette_outlined,
                        title: l10n.themeMode,
                        subtitle: _themeModeLabel(
                          context,
                          settings.appThemeMode,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showThemeModePicker(context, settings),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      NeoSettingRow(
                        icon: Icons.language_rounded,
                        title: l10n.language,
                        subtitle: _localeLabel(context, settings.appLocale),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showLanguagePicker(context, settings),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _sectionLabel(context, l10n.backupRestore),
                      NeoSettingRow(
                        icon: Icons.cloud_outlined,
                        title: l10n.webDavServer,
                        subtitle:
                            backup.configSummary ?? l10n.webDavNotConfigured,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/settings/webdav'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      NeoSettingRow(
                        icon: Icons.cloud_upload_outlined,
                        title: l10n.backupToWebDav,
                        subtitle: _backupExportSubtitle(l10n, backup),
                        trailing: backup.isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: backup.isExporting
                            ? null
                            : () => _handleBackupExport(context, backup),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      NeoSettingRow(
                        icon: Icons.restore_page_outlined,
                        title: l10n.restoreFromWebDav,
                        subtitle: _backupRestoreSubtitle(l10n, backup),
                        trailing: backup.isImporting || backup.isLoadingVersions
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: backup.isImporting || backup.isLoadingVersions
                            ? null
                            : () => _openBackupVersions(context, backup),
                      ),
                      if (backup.canUndoLastRestore) ...[
                        const SizedBox(height: AppSpacing.sm),
                        NeoSettingRow(
                          icon: Icons.undo_rounded,
                          title: l10n.undoLastRestore,
                          subtitle: l10n.restoreCreatesRollbackSnapshot,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: backup.undoLastRestore,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _themeModeLabel(BuildContext context, AppThemeMode mode) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case AppThemeMode.system:
        return l10n.themeModeSystem;
      case AppThemeMode.light:
        return l10n.themeModeLight;
      case AppThemeMode.dark:
        return l10n.themeModeDark;
    }
  }

  String _localeLabel(BuildContext context, AppLocale locale) {
    final l10n = AppLocalizations.of(context)!;
    switch (locale) {
      case AppLocale.system:
        return l10n.languageSystem;
      case AppLocale.en:
        return l10n.languageEnglish;
      case AppLocale.zh:
        return l10n.languageChinese;
      case AppLocale.ja:
        return l10n.languageJapanese;
    }
  }

  String _backupExportSubtitle(
    AppLocalizations l10n,
    SettingsBackupController backup,
  ) {
    if (!backup.hasConfig) {
      return l10n.configureWebDavToUseBackup;
    }
    return l10n.backupIncludesCredentials;
  }

  String _backupRestoreSubtitle(
    AppLocalizations l10n,
    SettingsBackupController backup,
  ) {
    if (!backup.hasConfig) {
      return l10n.configureWebDavToUseBackup;
    }
    return l10n.restoreCreatesRollbackSnapshot;
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _handleBackupExport(
    BuildContext context,
    SettingsBackupController backup,
  ) async {
    if (!backup.hasConfig) {
      await context.push('/settings/webdav');
      return;
    }
    await backup.exportBackup();
  }

  Future<void> _openBackupVersions(
    BuildContext context,
    SettingsBackupController backup,
  ) async {
    if (!backup.hasConfig) {
      await context.push('/settings/webdav');
      return;
    }

    await backup.loadAvailableBackups();
    if (!context.mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.82;
        return ChangeNotifierProvider<SettingsBackupController>.value(
          value: backup,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: NeoCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Consumer<SettingsBackupController>(
                  builder: (context, backupState, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.selectBackupVersion,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (backupState.availableBackups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            child: Center(child: Text(l10n.noBackupsAvailable)),
                          )
                        else
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  for (final version
                                      in backupState.availableBackups) ...[
                                    _buildBackupVersionRow(
                                      context,
                                      backup: backupState,
                                      version: version,
                                    ),
                                    if (version !=
                                        backupState.availableBackups.last)
                                      const SizedBox(height: AppSpacing.sm),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackupVersionRow(
    BuildContext context, {
    required SettingsBackupController backup,
    required DownloaderBackupVersion version,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final title = version.isLatest
        ? '${l10n.latestBackupLabel} · ${_formatAbsoluteTime(version.createdAt)}'
        : _formatAbsoluteTime(version.createdAt);
    final subtitle =
        '${version.appVersion} · ${l10n.backupDownloaderCount(version.downloaderCount)}';

    return NeoSettingRow(
      icon: version.isLatest ? Icons.history_toggle_off_rounded : Icons.history,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (version.isLatest) ...[
            NeoBadge(
              label: l10n.latestBackupChip,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: l10n.delete,
            onPressed: backup.isDeletingBackup
                ? null
                : () => _confirmDeleteBackup(context, backup, version),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () => _confirmRestoreBackup(context, backup, version),
    );
  }

  Future<void> _confirmRestoreBackup(
    BuildContext context,
    SettingsBackupController backup,
    DownloaderBackupVersion version,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
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
                l10n.confirmRestoreAndReplace,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.restoreWillReplaceAllDownloaders),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.restoreCreatesRollbackSnapshot),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: NeoButton.secondary(
                      onPressed: () => Navigator.pop(ctx, false),
                      label: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: NeoButton.primary(
                      onPressed: () => Navigator.pop(ctx, true),
                      label: Text(l10n.restoreFromWebDav),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }

    await backup.restoreBackup(fileId: version.fileId);
    if (context.mounted && backup.errorMessage == null) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDeleteBackup(
    BuildContext context,
    SettingsBackupController backup,
    DownloaderBackupVersion version,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
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
                l10n.confirmDeleteBackupVersion,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.deleteBackupVersionMessage),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: NeoButton.secondary(
                      onPressed: () => Navigator.pop(ctx, false),
                      label: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: NeoButton.primary(
                      onPressed: () => Navigator.pop(ctx, true),
                      label: Text(l10n.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }
    await backup.deleteBackup(fileId: version.fileId);
  }

  String _formatAbsoluteTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  void _showThemeModePicker(BuildContext context, SettingsController settings) {
    final l10n = AppLocalizations.of(context)!;
    _showNeoPickerSheet<AppThemeMode>(
      context: context,
      title: l10n.themeMode,
      selectedValue: settings.appThemeMode,
      values: AppThemeMode.values,
      labelBuilder: (ctx, mode) => _themeModeLabel(ctx, mode),
      iconBuilder: (mode) => switch (mode) {
        AppThemeMode.system => Icons.brightness_auto_rounded,
        AppThemeMode.light => Icons.light_mode_outlined,
        AppThemeMode.dark => Icons.dark_mode_outlined,
      },
      onSelected: settings.setAppThemeMode,
    );
  }

  void _showLanguagePicker(BuildContext context, SettingsController settings) {
    final l10n = AppLocalizations.of(context)!;
    _showNeoPickerSheet<AppLocale>(
      context: context,
      title: l10n.language,
      selectedValue: settings.appLocale,
      values: AppLocale.values,
      labelBuilder: (ctx, locale) => _localeLabel(ctx, locale),
      iconBuilder: (locale) => switch (locale) {
        AppLocale.system => Icons.language_rounded,
        AppLocale.en => Icons.translate_rounded,
        AppLocale.zh => Icons.translate_rounded,
        AppLocale.ja => Icons.translate_rounded,
      },
      onSelected: settings.setAppLocale,
    );
  }

  void _showNeoPickerSheet<T>({
    required BuildContext context,
    required String title,
    required T selectedValue,
    required List<T> values,
    required String Function(BuildContext context, T value) labelBuilder,
    required IconData Function(T value) iconBuilder,
    required ValueChanged<T> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.72;
        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: NeoCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final value in values) ...[
                            NeoSettingRow(
                              icon: iconBuilder(value),
                              title: labelBuilder(ctx, value),
                              trailing: value == selectedValue
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () {
                                onSelected(value);
                                Navigator.pop(ctx);
                              },
                            ),
                            if (value != values.last)
                              const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
