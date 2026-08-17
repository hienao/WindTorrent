import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/aria2_task_options_controller.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_shell.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/aria2/aria2_task_options.dart';

/// Aria2 选项子页面。
///
/// 支持编辑最大下载速度、最大上传速度、最大连接节点数。
class Aria2TaskOptionsPage extends StatefulWidget {
  const Aria2TaskOptionsPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final Aria2TaskOptionsController? controller;

  @override
  State<Aria2TaskOptionsPage> createState() => _Aria2TaskOptionsPageState();
}

class _Aria2TaskOptionsPageState extends State<Aria2TaskOptionsPage> {
  late final Aria2TaskOptionsController _controller;
  bool _ownsController = false;

  // 编辑态控制器（生命周期由本 State 管理，避免每次 build 重建）
  late final TextEditingController _dlCtrl;
  late final TextEditingController _ulCtrl;
  late final TextEditingController _connCtrl;

  // 上一次同步的选项快照，用于检测是否需要更新 TextEditingController
  Aria2TaskOptions? _lastSyncedOptions;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _dlCtrl = TextEditingController();
    _ulCtrl = TextEditingController();
    _connCtrl = TextEditingController();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = Aria2TaskOptionsController();
      _ownsController = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _dlCtrl.dispose();
    _ulCtrl.dispose();
    _connCtrl.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final downloader = context
        .read<DownloaderController>()
        .getDownloader(widget.downloaderId);
    if (downloader == null) return;
    await _controller.load(taskId: widget.taskId, downloader: downloader);
  }

  /// 当控制器选项变化时同步到 TextEditingController。
  ///
  /// 在 build 中调用，通过比对引用避免重复同步。
  void _syncIfNeeded(Aria2TaskOptions? options) {
    if (options == null || identical(options, _lastSyncedOptions)) return;
    _lastSyncedOptions = options;
    _dlCtrl.text = options.maxDownloadLimit <= 0
        ? ''
        : (options.maxDownloadLimit / 1024).toStringAsFixed(1);
    _ulCtrl.text = options.maxUploadLimit <= 0
        ? ''
        : (options.maxUploadLimit / 1024).toStringAsFixed(1);
    _connCtrl.text = options.maxConnectionLimit <= 0
        ? ''
        : options.maxConnectionLimit.toString();
    _dirty = false;
  }

  Future<void> _save() async {
    final downloader = context
        .read<DownloaderController>()
        .getDownloader(widget.downloaderId);
    if (downloader == null) return;

    final options = <String, String>{
      'max-download-limit': _dlCtrl.text.isEmpty
          ? '0'
          : '${((double.tryParse(_dlCtrl.text) ?? 0) * 1024).round()}',
      'max-upload-limit': _ulCtrl.text.isEmpty
          ? '0'
          : '${((double.tryParse(_ulCtrl.text) ?? 0) * 1024).round()}',
      'bt-max-peers': _connCtrl.text.isEmpty ? '0' : _connCtrl.text,
    };

    final ok = await _controller.save(
      taskId: widget.taskId,
      downloader: downloader,
      options: options,
    );
    if (ok && mounted) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.aria2OptionsSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider<Aria2TaskOptionsController>.value(
      value: _controller,
      child: TaskDetailShell(
        taskId: widget.taskId,
        downloaderId: widget.downloaderId,
        taskName: widget.taskName,
        onRefresh: _load,
        body: Consumer<Aria2TaskOptionsController>(
          builder: (context, controller, _) {
            // 选项可用时立即同步（build 内同步，无需 postFrameCallback）
            _syncIfNeeded(controller.options);

            if (controller.isLoading && controller.options == null) {
              return NeoSection(
                title: l10n.taskOptionsEntry,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }
            if (controller.errorMessage != null &&
                controller.options == null) {
              return NeoSection(
                title: l10n.taskOptionsEntry,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      controller.errorMessage!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              );
            }

            return NeoSection(
              title: l10n.taskOptionsEntry,
              child: Column(
                children: [
                  _OptionField(
                    controller: _dlCtrl,
                    label: l10n.aria2MaxDlSpeed,
                    hint: l10n.aria2Unlimited,
                    onChanged: () =>
                        setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  _OptionField(
                    controller: _ulCtrl,
                    label: l10n.aria2MaxUlSpeed,
                    hint: l10n.aria2Unlimited,
                    onChanged: () =>
                        setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  _OptionField(
                    controller: _connCtrl,
                    label: l10n.aria2MaxConnections,
                    hint: l10n.aria2Unlimited,
                    onChanged: () =>
                        setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _dirty && !controller.isSaving ? _save : null,
                      child: controller.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.saveButton),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OptionField extends StatelessWidget {
  const _OptionField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (_) => onChanged(),
    );
  }
}
