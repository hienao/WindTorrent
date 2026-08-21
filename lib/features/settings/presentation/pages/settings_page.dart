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
                        icon: Icons.file_upload_outlined,
                        title: l10n.exportConfigBackup,
                        subtitle: l10n.backupIncludesCredentials,
                        trailing: backup.isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: backup.isExporting ? null : backup.exportBackup,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      NeoSettingRow(
                        icon: Icons.file_download_outlined,
                        title: l10n.importConfigBackup,
                        subtitle: l10n.importBackupValidationNotice,
                        trailing: backup.isImporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: backup.isImporting
                            ? null
                            : () => _confirmImport(context, backup),
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

  Future<void> _confirmImport(
    BuildContext context,
    SettingsBackupController backup,
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
                      label: Text(l10n.selectBackupFile),
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
    await backup.importBackup();
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
