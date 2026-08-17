import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/core/utils/responsive_layout.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_backup_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';

class WebDavConfigPage extends StatefulWidget {
  const WebDavConfigPage({super.key});

  @override
  State<WebDavConfigPage> createState() => _WebDavConfigPageState();
}

class _WebDavConfigPageState extends State<WebDavConfigPage> {
  final _rootUrlController = TextEditingController();
  final _remoteDirectoryController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _didSeedFields = false;
  String? _localError;

  @override
  void dispose() {
    _rootUrlController.dispose();
    _remoteDirectoryController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: SafeArea(
        child: Consumer<SettingsBackupController>(
          builder: (context, backup, _) {
            if (!_didSeedFields) {
              _didSeedFields = true;
              final config = backup.config;
              if (config != null) {
                _rootUrlController.text = config.rootUrl;
                _remoteDirectoryController.text = config.remoteDirectory;
                _usernameController.text = config.username;
                _passwordController.text = config.password;
              } else {
                _remoteDirectoryController.text = 'WindTorrent/Backups';
              }
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                NeoPageHeader(
                  title: l10n.webDavServer,
                  subtitle: l10n.webDavConfigSubtitle,
                  onBack: () => Navigator.pop(context),
                ),
                ResponsiveContainer(
                  child: Column(
                    children: [
                      NeoCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_localError != null) ...[
                              Text(
                                _localError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            _buildField(
                              context: context,
                              controller: _rootUrlController,
                              label: l10n.webDavRootUrl,
                              icon: Icons.link_rounded,
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildField(
                              context: context,
                              controller: _remoteDirectoryController,
                              label: l10n.webDavDirectory,
                              icon: Icons.folder_outlined,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildField(
                              context: context,
                              controller: _usernameController,
                              label: l10n.username,
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildField(
                              context: context,
                              controller: _passwordController,
                              label: l10n.webDavPasswordOrToken,
                              icon: Icons.key_outlined,
                              obscureText: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: NeoButton.secondary(
                              onPressed: backup.isTestingConfig
                                  ? null
                                  : () => _testConnection(backup),
                              label: Text(
                                backup.isTestingConfig
                                    ? l10n.testingConnection
                                    : l10n.testConnection,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: NeoButton.primary(
                              onPressed: backup.isSavingConfig
                                  ? null
                                  : () => _saveConfig(backup),
                              label: Text(
                                backup.isSavingConfig
                                    ? l10n.saving
                                    : l10n.saveConfigButton,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return NeoInputShell(
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Future<void> _testConnection(SettingsBackupController backup) async {
    final config = _buildConfig();
    if (config == null) {
      return;
    }
    await backup.testConnection(config);
  }

  Future<void> _saveConfig(SettingsBackupController backup) async {
    final config = _buildConfig();
    if (config == null) {
      return;
    }
    await backup.saveConfig(config);
    if (mounted && backup.errorMessage == null) {
      Navigator.pop(context);
    }
  }

  WebDavConfig? _buildConfig() {
    final l10n = AppLocalizations.of(context)!;
    final rootUrl = _rootUrlController.text.trim();
    final directory = _remoteDirectoryController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (rootUrl.isEmpty || Uri.tryParse(rootUrl)?.hasScheme != true) {
      setState(() {
        _localError = l10n.webDavRootUrlInvalid;
      });
      return null;
    }
    if (directory.isEmpty) {
      setState(() {
        _localError = l10n.webDavDirectoryRequired;
      });
      return null;
    }
    if (username.isEmpty) {
      setState(() {
        _localError = l10n.usernameRequired;
      });
      return null;
    }
    if (password.isEmpty) {
      setState(() {
        _localError = l10n.webDavPasswordRequired;
      });
      return null;
    }

    setState(() {
      _localError = null;
    });
    return WebDavConfig(
      rootUrl: rootUrl,
      remoteDirectory: directory,
      username: username,
      password: password,
    );
  }
}
