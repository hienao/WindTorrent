import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/core/utils/review_manager.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/downloaders/presentation/utils/downloader_host_input.dart';
import 'package:windwalker/features/downloaders/presentation/widgets/downloader_type_icon.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/connection_result.dart';

class DownloaderEditorPage extends StatefulWidget {
  final String? downloaderId;

  const DownloaderEditorPage({super.key, this.downloaderId});

  @override
  State<DownloaderEditorPage> createState() => _DownloaderEditorPageState();
}

class _DownloaderEditorPageState extends State<DownloaderEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _secretController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  Downloader? _existing;
  DownloaderType _type = DownloaderType.aria2;
  bool _https = false;
  bool _saving = false;

  bool get _isEdit => _existing != null;

  @override
  void initState() {
    super.initState();

    final controller = context.read<DownloaderController>();
    _existing = widget.downloaderId == null
        ? null
        : controller.getDownloader(widget.downloaderId!);

    final e = _existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _hostController = TextEditingController(text: e?.host ?? '');
    _portController = TextEditingController(
      text:
          e?.port.toString() ??
          AppConstants.defaultPorts[DownloaderType.aria2.name].toString(),
    );
    _secretController = TextEditingController(text: e?.secret ?? '');
    _usernameController = TextEditingController(text: e?.username ?? '');
    _passwordController = TextEditingController(text: e?.password ?? '');
    _type = e?.type ?? DownloaderType.aria2;
    _https = e?.useHttps ?? false;

    if (widget.downloaderId != null && _existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.downloaderNotExistDeleted)));
        Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              NeoPageHeader(
                title: _isEdit ? l10n.editDownloader : l10n.addDownloaderTitle,
                subtitle: l10n.basicInfo,
                onBack: () => Navigator.of(context).maybePop(),
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              ),
              const SizedBox(height: AppSpacing.sm),
              NeoSection(
                title: l10n.basicInfo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _textFieldShell(
                      label: l10n.downloaderNameField,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: _neoInputDecoration(),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.pleaseEnterDownloaderName
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.downloaderTypeField,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Column(
                      children: [
                        for (final type in DownloaderType.values) ...[
                          _DownloaderTypeCard(
                            type: type,
                            selected: _type == type,
                            onTap: () => _selectType(type),
                          ),
                          if (type != DownloaderType.values.last)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _textFieldShell(
                      label: l10n.serverAddressField,
                      child: TextFormField(
                        controller: _hostController,
                        decoration: _neoInputDecoration(),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.pleaseEnterServerAddress
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _textFieldShell(
                      label: l10n.port,
                      child: TextFormField(
                        controller: _portController,
                        decoration: _neoInputDecoration(),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return l10n.pleaseEnterPort;
                          }
                          final p = int.tryParse(v);
                          if (p == null || p <= 0 || p > 65535) {
                            return l10n.portInvalid;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _HttpsToggle(
                      value: _https,
                      onChanged: (v) => setState(() => _https = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_type == DownloaderType.aria2) ...[
                      _textFieldShell(
                        label: 'RPC Secret',
                        child: TextFormField(
                          controller: _secretController,
                          decoration: _neoInputDecoration(),
                        ),
                      ),
                    ] else ...[
                      _textFieldShell(
                        label: l10n.usernameField,
                        child: TextFormField(
                          controller: _usernameController,
                          decoration: _neoInputDecoration(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _textFieldShell(
                        label: l10n.passwordField,
                        child: TextFormField(
                          controller: _passwordController,
                          decoration: _neoInputDecoration(),
                          obscureText: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NeoActionBar(
        child: NeoButton.primary(
          onPressed: _saving ? null : _save,
          label: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.saveConfigButton),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final normalizedHost = normalizeDownloaderHostInput(_hostController.text);
    if (normalizedHost != _hostController.text) {
      _hostController.value = TextEditingValue(
        text: normalizedHost,
        selection: TextSelection.collapsed(offset: normalizedHost.length),
      );
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final controller = context.read<DownloaderController>();
      final port = int.parse(_portController.text.trim());

      final downloader = Downloader(
        id: _existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        type: _type,
        host: _hostController.text.trim(),
        port: port,
        secret: _type == DownloaderType.aria2
            ? _secretController.text.trim().ifEmptyToNull
            : null,
        username: _type != DownloaderType.aria2
            ? _usernameController.text.trim().ifEmptyToNull
            : null,
        password: _type != DownloaderType.aria2
            ? _passwordController.text.trim().ifEmptyToNull
            : null,
        useHttps: _https,
      );

      final result = _isEdit
          ? await controller.updateDownloader(downloader)
          : await controller.addDownloader(downloader);

      if (!mounted) return;

      switch (result) {
        case ConnectionSuccess():
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.connectionSuccess)));
          if (!_isEdit && controller.downloaders.length == 1) {
            unawaited(
              ReviewManager().recordFirstDownloaderAddedAndMaybeRequestReview(),
            );
          }
          Navigator.of(context).pop();
        case ConnectionFailure(
          :final category,
          :final reason,
          :final actualVersion,
          :final minVersion,
        ):
          final l10n = AppLocalizations.of(context)!;
          final message = switch (category) {
            ConnectionFailureCategory.versionUnsupported =>
              (actualVersion != null && minVersion != null)
                  ? l10n.versionTooLow(actualVersion, minVersion)
                  : reason,
            ConnectionFailureCategory.authFailed => l10n.authFailedCheck,
            ConnectionFailureCategory.networkError => l10n.cannotConnect,
            ConnectionFailureCategory.unknown => reason,
          };
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectType(DownloaderType type) {
    setState(() {
      _type = type;
      _portController.text =
          AppConstants.defaultPorts[type.name]?.toString() ??
          _portController.text;
    });
  }

  Widget _textFieldShell({required String label, required Widget child}) {
    return NeoFormFieldShell(label: label, child: child);
  }

  InputDecoration _neoInputDecoration() {
    return const InputDecoration(
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

class _DownloaderTypeCard extends StatelessWidget {
  final DownloaderType type;
  final bool selected;
  final VoidCallback onTap;

  const _DownloaderTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final textTheme = Theme.of(context).textTheme;

    return NeoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          DownloaderTypeIcon(type: type, size: DownloaderTypeIconSize.medium),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              type.label,
              style: textTheme.titleSmall?.copyWith(
                color: selected ? tokens.primaryAccent : null,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected
                ? tokens.primaryAccent
                : Theme.of(context).hintColor.withValues(alpha: 0.74),
          ),
        ],
      ),
    );
  }
}

class _HttpsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _HttpsToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return NeoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'HTTPS',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

extension on String {
  String? get ifEmptyToNull => trim().isEmpty ? null : trim();
}
