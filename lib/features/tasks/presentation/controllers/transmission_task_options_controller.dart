import 'package:flutter/foundation.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_options.dart';
import 'package:windwalker/models/transmission_task_options_update.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/transmission_service.dart';

typedef TransmissionServiceFactory = TransmissionService Function(
  Downloader downloader,
);

/// Transmission 任务选项控制器。
///
/// 负责选项子页面的加载 / 编辑 / 保存 / dirty-state 管理。
/// 错误传播：service fail-fast 抛异常 → 此处捕获并写入 errorMessage 供 UI 显示。
class TransmissionTaskOptionsController extends ChangeNotifier {
  TransmissionTaskOptionsController({
    TransmissionServiceFactory? serviceFactory,
    this.onTaskChanged,
  }) : _serviceFactory =
            serviceFactory ?? ((downloader) => TransmissionService(downloader));

  final TransmissionServiceFactory _serviceFactory;

  /// 任务变更后回调（接收 downloaderId）。
  ///
  /// 保存成功后调用，供页面触发 `RealtimeSyncController.refreshNow(...)`，
  /// 使变更结果回流到 `TaskDomainStore`（任务域单一事实来源），保证跨页面同步。
  final void Function(String downloaderId)? onTaskChanged;

  TransmissionTaskOptions? _initial;
  TransmissionTaskOptions? _draft;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  TransmissionTaskOptions? get draft => _draft;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get isDirty => _initial != _draft;

  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final loaded = await _serviceFactory(downloader).getTaskOptions(taskId);
      _initial = loaded;
      _draft = loaded;
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateBandwidthPriority(int value) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(bandwidthPriority: value);
    notifyListeners();
  }

  void updateHonorsSessionLimits(bool value) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(honorsSessionLimits: value);
    notifyListeners();
  }

  void updateDownloadLimit(String raw) {
    final value = int.tryParse(raw);
    final draft = _draft;
    if (draft == null || value == null || value < 0) return;
    _draft = draft.copyWith(downloadLimited: true, downloadLimitKBps: value);
    notifyListeners();
  }

  void updateUploadLimit(String raw) {
    final value = int.tryParse(raw);
    final draft = _draft;
    if (draft == null || value == null || value < 0) return;
    _draft = draft.copyWith(uploadLimited: true, uploadLimitKBps: value);
    notifyListeners();
  }

  void updateSeedRatioMode(TransmissionLimitMode value) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(seedRatioMode: value);
    notifyListeners();
  }

  void updateSeedRatioLimit(String raw) {
    final value = double.tryParse(raw);
    final draft = _draft;
    if (draft == null || value == null || value < 0) return;
    _draft = draft.copyWith(seedRatioLimit: value);
    notifyListeners();
  }

  void updateIdleLimitMode(TransmissionLimitMode value) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(idleLimitMode: value);
    notifyListeners();
  }

  void updateIdleLimitMinutes(String raw) {
    final value = int.tryParse(raw);
    final draft = _draft;
    if (draft == null || value == null || value < 0) return;
    _draft = draft.copyWith(idleLimitMinutes: value);
    notifyListeners();
  }

  Future<void> save({
    required String taskId,
    required Downloader downloader,
  }) async {
    final draft = _draft;
    if (draft == null) return;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _serviceFactory(downloader).updateTaskOptions(
        taskId,
        TransmissionTaskOptionsUpdate.fromOptions(draft),
      );
      _initial = draft;
      onTaskChanged?.call(downloader.id);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
