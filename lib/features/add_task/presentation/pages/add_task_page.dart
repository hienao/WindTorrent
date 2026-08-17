import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/core/utils/review_manager.dart';
import 'package:windwalker/features/add_task/presentation/services/qbit_link_input_normalizer.dart';
import 'package:windwalker/features/add_task/presentation/services/torrent_file_picker.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/downloaders/presentation/widgets/downloader_type_icon.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/qbit_service.dart';

class AddTaskPage extends StatefulWidget {
  final String? initialUrl;
  final TorrentFilePicker? torrentFilePicker;
  final Future<String?> Function(Downloader downloader)?
      defaultSavePathLoader;

  const AddTaskPage({
    super.key,
    this.initialUrl,
    this.torrentFilePicker,
    this.defaultSavePathLoader,
  });

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _urlController = TextEditingController();
  final _savePathController = TextEditingController();

  String? _selectedDownloaderId;
  bool _submitting = false;

  Uint8List? _torrentBytes;
  String? _torrentFileName;

  /// 缓存「下载器 id → 默认保存路径 Future」，避免每次 build 重新发起请求。
  /// 切换下载器时换 key；旧 key 的 Future 结果被 FutureBuilder 忽略。
  final Map<String, Future<String?>> _defaultSavePathFutures = {};

  TorrentFilePicker get _torrentFilePicker =>
      widget.torrentFilePicker ?? const TorrentFilePicker();

  bool _isQBitDownloader(Downloader? downloader) =>
      downloader?.type == DownloaderType.qbittorrent;

  Future<String?> _defaultSavePathFuture(Downloader downloader) {
    return _defaultSavePathFutures.putIfAbsent(
      downloader.id,
      () => _fetchDefaultSavePath(downloader),
    );
  }

  Future<String?> _fetchDefaultSavePath(Downloader downloader) async {
    try {
      if (widget.defaultSavePathLoader != null) {
        return widget.defaultSavePathLoader!(downloader);
      }
      if (downloader.type != DownloaderType.qbittorrent) return null;

      final path = await QBitService(downloader).getDefaultSavePath();
      return path.trim().isEmpty ? null : path.trim();
    } catch (e) {
      // hint 为次要展示字段，读取失败时降级为默认占位文案，不影响主流程
      Log.w('AddTaskPage: 读取默认保存路径失败: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _savePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: SafeArea(
        bottom: false,
        child: Consumer<DownloaderController>(
          builder: (context, downloaderController, _) {
            final downloaders = downloaderController.downloaders;
            final selectedIdExists = downloaders.any(
              (downloader) => downloader.id == _selectedDownloaderId,
            );
            if (downloaders.isEmpty) {
              _selectedDownloaderId = null;
            } else if (_selectedDownloaderId == null || !selectedIdExists) {
              _selectedDownloaderId = downloaders.first.id;
            }
            final selectedDownloader = _selectedDownloader(downloaders);

            return Column(
              children: [
                Expanded(
                  child: Form(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      children: [
                        NeoPageHeader(
                          title: l10n.addTaskButton,
                          subtitle: l10n.downloadLinkDesc,
                          onBack: () => context.pop(),
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                        ),
                        const SizedBox(height: 16),
                        _SectionLabel(
                          title: _stepTitle(l10n.selectDownloaderStep),
                          trailing: l10n.selectDownloaderDesc,
                        ),
                        const SizedBox(height: 12),
                        downloaders.isEmpty
                            ? _emptyDownloaders(l10n)
                            : _selectedDownloaderCard(selectedDownloader, l10n),
                        const SizedBox(height: 16),
                        _SectionLabel(
                          title: _stepTitle(l10n.downloadLinkStep),
                          trailing: _isQBitDownloader(selectedDownloader)
                              ? l10n.qbitBulkInputHint
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _urlInput(l10n, selectedDownloader),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SourceCard(
                                icon: Icons.link_rounded,
                                title: l10n.downloadLinkStep,
                                subtitle: l10n.pasteHint,
                                selected: _torrentBytes == null,
                                onTap: () {
                                  setState(() {
                                    _torrentBytes = null;
                                    _torrentFileName = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SourceCard(
                                icon: Icons.description_outlined,
                                title: l10n.selectTorrentFile,
                                subtitle: _torrentFileName ?? '.torrent',
                                selected: _torrentBytes != null,
                                onTap: _pickTorrentFile,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SectionLabel(
                          title: _stepTitle(l10n.savePathStep),
                          trailing: l10n.savePathDesc,
                        ),
                        const SizedBox(height: 12),
                        _savePathInput(l10n, selectedDownloader),
                      ],
                    ),
                  ),
                ),
                NeoActionBar(
                  child: NeoButton.primary(
                    onPressed: _submitting ? null : _submit,
                    label: _submitting
                        ? _submittingIndicator()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.download_rounded, size: 24),
                              const SizedBox(width: 8),
                              Text(l10n.startDownload),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _submittingIndicator() {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }

  Widget _emptyDownloaders(AppLocalizations l10n) {
    return NeoEmptyState(
      icon: Icons.download_for_offline_outlined,
      title: l10n.noDownloadersConfigured,
      subtitle: l10n.selectDownloaderDesc,
    );
  }

  Downloader? _selectedDownloader(List<Downloader> downloaders) {
    if (_selectedDownloaderId == null) return null;
    for (final downloader in downloaders) {
      if (downloader.id == _selectedDownloaderId) return downloader;
    }
    return null;
  }

  void _selectDownloader(Downloader downloader) {
    if (_selectedDownloaderId == downloader.id) return;
    setState(() {
      _selectedDownloaderId = downloader.id;
    });
  }

  String _savePathHint(
    AppLocalizations l10n,
    Downloader? selectedDownloader, {
    String? resolvedDefaultSavePath,
    bool isLoading = false,
  }) {
    if (_savePathController.text.isNotEmpty) {
      return l10n.defaultSavePath;
    }
    // qBittorrent 选中且路径尚未解析完成时统一显示加载文案；其余情况回落默认占位
    if (_isQBitDownloader(selectedDownloader)) {
      if (isLoading && resolvedDefaultSavePath == null) {
        return l10n.loadingDefaultSavePath;
      }
      return resolvedDefaultSavePath ?? l10n.defaultSavePath;
    }
    return l10n.defaultSavePath;
  }

  Widget _selectedDownloaderCard(
    Downloader? selectedDownloader,
    AppLocalizations l10n,
  ) {
    if (selectedDownloader == null) return _emptyDownloaders(l10n);
    final online = selectedDownloader.status == DownloaderStatus.online;

    return NeoStatusHeroCard(
      leading: DownloaderTypeIcon(
        type: selectedDownloader.type,
        size: DownloaderTypeIconSize.medium,
      ),
      title: selectedDownloader.name,
      subtitle: selectedDownloader.type.label,
      badge: NeoBadge(
        label: online ? l10n.online : l10n.offline,
        backgroundColor: (online ? AppColors.success : AppColors.offline)
            .withValues(alpha: 0.14),
        foregroundColor: online ? AppColors.success : AppColors.offline,
      ),
      leadingMeta: '${selectedDownloader.host}:${selectedDownloader.port}',
      trailingMeta: _stepTitle(l10n.selectDownloaderStep),
      onTap: _showDownloaderPicker,
    );
  }

  Widget _urlInput(AppLocalizations l10n, Downloader? selectedDownloader) {
    final isQBit = _isQBitDownloader(selectedDownloader);
    return NeoInputShell(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment:
            isQBit ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.link_rounded,
            color: Theme.of(context).hintColor,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _urlController,
              minLines: isQBit ? 5 : 1,
              maxLines: isQBit ? 5 : 1,
              decoration: InputDecoration(
                hintText: l10n.pasteHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120, maxHeight: 40),
            child: OutlinedButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: Text(l10n.paste),
              style: OutlinedButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savePathInput(AppLocalizations l10n, Downloader? selectedDownloader) {
    return NeoInputShell(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.folder_outlined,
            color: Theme.of(context).hintColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _savePathField(l10n, selectedDownloader),
          ),
        ],
      ),
    );
  }

  Widget _savePathField(AppLocalizations l10n, Downloader? selectedDownloader) {
    // 非 qBittorrent 不读取默认路径，直接回落占位文案，无需 FutureBuilder。
    if (!_isQBitDownloader(selectedDownloader)) {
      return _savePathTextFormField(
        l10n,
        hint: _savePathHint(l10n, selectedDownloader),
      );
    }

    final downloader = selectedDownloader!;
    return FutureBuilder<String?>(
      future: _defaultSavePathFuture(downloader),
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState != ConnectionState.done;
        return _savePathTextFormField(
          l10n,
          hint: _savePathHint(
            l10n,
            selectedDownloader,
            resolvedDefaultSavePath: snapshot.data,
            isLoading: isLoading,
          ),
        );
      },
    );
  }

  TextFormField _savePathTextFormField(AppLocalizations l10n,
      {required String hint}) {
    return TextFormField(
      controller: _savePathController,
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _showDownloaderPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final downloaders = context.read<DownloaderController>().downloaders;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: NeoCard(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.64,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SectionLabel(
                      title: _stepTitle(l10n.selectDownloaderStep),
                      trailing: l10n.selectDownloaderDesc,
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: downloaders.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final downloader = downloaders[index];
                          return NeoSettingRow(
                            leading: DownloaderTypeIcon(
                              type: downloader.type,
                              size: DownloaderTypeIconSize.medium,
                            ),
                            title: downloader.name,
                            subtitle:
                                '${downloader.type.label} · ${downloader.host}:${downloader.port}',
                            trailing: _selectedDownloaderId == downloader.id
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              _selectDownloader(downloader);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
      setState(() {});
    }
  }

  Future<void> _pickTorrentFile() async {
    final picked = await _torrentFilePicker.pick();
    if (!mounted || picked == null) return;

    setState(() {
      _torrentBytes = picked.bytes;
      _torrentFileName = picked.fileName;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedDownloaderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pleaseSelectDownloader)));
      return;
    }

    final request = await _resolveRequestBeforeSubmit();
    if (request == null || !mounted) return;

    setState(() => _submitting = true);

    final success = await context.read<TaskController>().addTask(
      request,
      context.read<DownloaderController>(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.taskAddedSuccess)));
      unawaited(ReviewManager().recordSuccessfulTaskAddAndMaybeRequestReview());
      context.pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.taskAddFailed)));
    }
  }

  Future<bool?> _showSourceChoiceDialog() async {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: NeoCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chooseTaskSourceTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(l10n.chooseTaskSourceMessage),
              const SizedBox(height: 18),
              NeoSettingRow(
                icon: Icons.link_rounded,
                title: l10n.useLinkSource,
                subtitle: l10n.downloadLinkDesc,
                onTap: () => Navigator.pop(context, false),
              ),
              const SizedBox(height: 10),
              NeoSettingRow(
                icon: Icons.description_outlined,
                title: l10n.useTorrentSource,
                subtitle: _torrentFileName ?? l10n.torrentUploadHint,
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<AddTaskRequest?> _resolveRequestBeforeSubmit() async {
    final l10n = AppLocalizations.of(context)!;

    final downloader = context.read<DownloaderController>().getDownloader(
      _selectedDownloaderId!,
    );

    final rawUrl = _urlController.text;
    // qBittorrent 多行输入：按行 trim + 去空行；其余类型仅整体 trim。
    final String? normalizedUrl;
    if (rawUrl.trim().isEmpty) {
      normalizedUrl = null;
    } else if (downloader?.type == DownloaderType.qbittorrent) {
      final value = normalizeQBitBulkInput(rawUrl);
      normalizedUrl = value.isEmpty ? null : value;
    } else {
      normalizedUrl = rawUrl.trim();
    }

    final baseRequest = AddTaskRequest(
      downloaderId: _selectedDownloaderId!,
      url: normalizedUrl,
      torrentFileBytes: _torrentBytes,
      torrentFileName: _torrentFileName,
      savePath: _savePathController.text.trim().isEmpty
          ? null
          : _savePathController.text.trim(),
    );

    if (!baseRequest.hasUrlSource && !baseRequest.hasTorrentSource) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enterLinkOrTorrentFile)));
      return null;
    }

    if (baseRequest.hasUrlSource && baseRequest.hasTorrentSource) {
      final useTorrent = await _showSourceChoiceDialog();
      if (useTorrent == null) return null;
      return useTorrent
          ? baseRequest.copyWith(clearUrl: true)
          : baseRequest.copyWith(clearTorrent: true);
    }

    return baseRequest;
  }

  String _stepTitle(String value) {
    return value.replaceFirst(RegExp(r'^\s*\d+[\.\u3001]\s*'), '');
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionLabel({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: tokens.primaryAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trailing!,
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? tokens.primaryAccent : colorScheme.onSurface;

    return NeoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: foreground),
              const Spacer(),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: foreground.withValues(alpha: selected ? 1 : 0.42),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}
