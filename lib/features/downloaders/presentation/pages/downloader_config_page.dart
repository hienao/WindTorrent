import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/speed_config_descriptor.dart';

class DownloaderConfigPage extends StatefulWidget {
  final String downloaderId;

  const DownloaderConfigPage({super.key, required this.downloaderId});

  @override
  State<DownloaderConfigPage> createState() => _DownloaderConfigPageState();
}

class _DownloaderConfigPageState extends State<DownloaderConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _toggleValues = <String, bool>{};
  final _kbpsControllers = <String, TextEditingController>{};

  SpeedConfigDescriptor? _descriptor;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final c in _kbpsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final controller = context.read<DownloaderController>();
    try {
      final descriptor = controller.getSpeedConfigDescriptor(
        widget.downloaderId,
      );
      if (descriptor == null) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _loading = false;
          _loadError = l10n.downloaderNotSupportConfig;
        });
        return;
      }

      for (final section in descriptor.sections) {
        for (final field in section.fields) {
          if (field.type == ConfigFieldType.toggle) {
            _toggleValues[field.key] = false;
          }
          if (field.type == ConfigFieldType.kbps) {
            _kbpsControllers[field.key] = TextEditingController();
          }
        }
      }

      final config = await controller.getSpeedConfig(widget.downloaderId);
      if (!mounted) return;

      if (config == null) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _loading = false;
          _loadError = l10n.saveFailedRetry;
        });
        return;
      }

      _toggleValues['speedLimitModeEnabled'] = config.speedLimitModeEnabled;
      _kbpsControllers['downloadLimitKB']?.text =
          config.downloadLimitKB > 0 ? '${config.downloadLimitKB}' : '';
      _kbpsControllers['uploadLimitKB']?.text =
          config.uploadLimitKB > 0 ? '${config.uploadLimitKB}' : '';
      _kbpsControllers['altDownloadLimitKB']?.text =
          config.altDownloadLimitKB > 0 ? '${config.altDownloadLimitKB}' : '';
      _kbpsControllers['altUploadLimitKB']?.text =
          config.altUploadLimitKB > 0 ? '${config.altUploadLimitKB}' : '';

      setState(() {
        _descriptor = descriptor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final config = DownloaderSpeedConfig(
      speedLimitModeEnabled: _toggleValues['speedLimitModeEnabled'] ?? false,
      downloadLimitKB:
          int.tryParse(_kbpsControllers['downloadLimitKB']?.text ?? '') ?? 0,
      uploadLimitKB:
          int.tryParse(_kbpsControllers['uploadLimitKB']?.text ?? '') ?? 0,
      altDownloadLimitKB:
          int.tryParse(_kbpsControllers['altDownloadLimitKB']?.text ?? '') ?? 0,
      altUploadLimitKB:
          int.tryParse(_kbpsControllers['altUploadLimitKB']?.text ?? '') ?? 0,
    );

    final ok = await context.read<DownloaderController>().setSpeedConfig(
          widget.downloaderId,
          config,
        );
    if (!mounted) return;

    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.configSaveSuccess),
        ),
      );
    } else {
      setState(() {
        _saveError = AppLocalizations.of(context)!.saveFailedRetry;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final downloader = context.watch<DownloaderController>().getDownloader(
          widget.downloaderId,
        );
    // 监听 TaskDomainStore，使 hero 在线徽章随 qBit / Transmission 实时摘要更新。
    final summary =
        context.watch<TaskDomainStore>().summary(widget.downloaderId);
    final online =
        (summary?.status ?? downloader?.status) == DownloaderStatus.online;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                children: [
                  NeoPageHeader(
                    title: l10n.downloaderServiceSettings(
                      downloader?.name ?? l10n.downloader,
                    ),
                    subtitle: downloader == null
                        ? l10n.downloader
                        : '${downloader.host}:${downloader.port}',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_loadError != null)
                    _buildEmptyState(l10n, downloader)
                  else
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildDownloaderHero(downloader, l10n, online),
                          const SizedBox(height: 16),
                          if (_saveError != null) ...[
                            _buildSaveError(context, _saveError!),
                            const SizedBox(height: 16),
                          ],
                          ...?_descriptor?.sections.map(_buildSection),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : NeoActionBar(
              child: NeoButton.primary(
                onPressed: _saving ? null : _save,
                label: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.saveConfig),
              ),
            ),
    );
  }

  Widget _buildDownloaderHero(
      Downloader? downloader, AppLocalizations l10n, bool online) {
    final statusColor = online ? AppColors.success : AppColors.offline;

    return NeoStatusHeroCard(
      icon: _downloaderIcon(downloader?.type),
      title: downloader?.name ?? '--',
      subtitle:
          downloader == null ? '--' : '${downloader.host}:${downloader.port}',
      badge: NeoBadge(
        label: online ? l10n.online : l10n.offline,
        backgroundColor: statusColor.withValues(alpha: 0.16),
        foregroundColor: statusColor,
      ),
      leadingMeta: downloader?.type.label,
      trailingMeta: downloader?.version,
      iconColor: _downloaderColor(downloader?.type),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, Downloader? downloader) {
    return NeoEmptyState(
      icon: Icons.tune_rounded,
      title: _loadError ?? l10n.downloaderNotSupportConfig,
      subtitle: downloader == null
          ? l10n.downloader
          : '${downloader.host}:${downloader.port}',
    );
  }

  Widget _buildSaveError(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return NeoCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _downloaderIcon(DownloaderType? type) {
    return switch (type) {
      DownloaderType.aria2 => Icons.cloud_download_rounded,
      DownloaderType.qbittorrent => Icons.downloading_rounded,
      DownloaderType.transmission => Icons.file_download_rounded,
      null => Icons.storage_outlined,
    };
  }

  Color _downloaderColor(DownloaderType? type) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (type) {
      DownloaderType.aria2 => colorScheme.primary,
      DownloaderType.qbittorrent => AppColors.success,
      DownloaderType.transmission => AppColors.warning,
      null => colorScheme.primary,
    };
  }

  Widget _buildSection(ConfigSection section) {
    final enabled = section.enabledBy == null ||
        (_toggleValues[section.enabledBy!] ?? false);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeoSection(
        title: section.title,
        subtitle: section.description,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: section.fields.map((field) {
            if (field.type == ConfigFieldType.toggle) {
              return _toggleField(field);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: NeoFormFieldShell(
                label: field.label,
                suffix: 'KB/s',
                enabled: enabled,
                child: TextFormField(
                  controller: _kbpsControllers[field.key],
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: _neoInputDecoration(field.hint),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed < 0) {
                      return l10n.pleaseEnterNonNegativeNumber;
                    }
                    return null;
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _toggleField(ConfigField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: NeoCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    field.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (field.hint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      field.hint!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.64),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: _toggleValues[field.key] ?? false,
              onChanged: (v) => setState(() => _toggleValues[field.key] = v),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _neoInputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
