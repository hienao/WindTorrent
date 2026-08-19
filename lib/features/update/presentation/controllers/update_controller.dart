import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/config/build_channel_config.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/update/data/update_repository.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/domain/update_prompt_policy.dart';
import 'package:windwalker/services/analytics_service.dart';

class UpdateController extends ChangeNotifier {
  UpdateController({
    UpdateRepository? repository,
    BuildChannelConfig? buildConfig,
    GetStorage? storage,
    TaskController? taskController,
    UpdatePromptPolicy? policy,
  }) : _buildConfig = buildConfig ?? BuildChannelConfig.fromBuildEnvironment(),
       _repository =
           repository ??
           ChannelUpdateRepository.forBuild(
             buildConfig ?? BuildChannelConfig.fromBuildEnvironment(),
           ),
       _storage = storage ?? GetStorage(),
       _taskController = taskController,
       _policy = policy ?? const UpdatePromptPolicy();

  static const _lastPromptAtKey = 'last_update_prompt_at';
  static const _lastPromptDayKey = 'last_update_prompt_day';
  static const _dismissedVersionCodeKey = 'dismissed_update_version_code';

  final BuildChannelConfig _buildConfig;
  final UpdateRepository _repository;
  final GetStorage _storage;
  final UpdatePromptPolicy _policy;
  TaskController? _taskController;

  UpdateCheckResult _lastResult = const UpdateCheckResult.unknown();
  bool _isChecking = false;
  bool _dialogConsumedInSession = false;
  bool _shouldOfferUpdateDialog = false;

  bool get isChecking => _isChecking;
  bool get hasUpdate => _lastResult.hasUpdate;
  UpdateCheckStatus get status => _lastResult.status;
  UpdateSource get updateSource => _repository.source;
  ReleaseTrack get releaseTrack => _buildConfig.releaseTrack;
  int? get availableVersionCode => _lastResult.availableVersionCode;
  String? get availableVersionName => _lastResult.availableVersionName;
  bool get shouldShowUpdateBadge => _lastResult.hasUpdate;
  bool get shouldOfferUpdateDialog => _shouldOfferUpdateDialog;

  void attachTaskController(TaskController taskController) {
    _taskController = taskController;
    _recomputeDecision();
  }

  Future<void> runSilentCheck({DateTime? now}) async {
    _isChecking = true;
    notifyListeners();
    _lastResult = await _repository.checkForUpdate();
    _isChecking = false;
    _recomputeDecision(now: now);
    await _trackCheckResult(source: 'silent');
  }

  Future<void> checkForUpdatesManually() async {
    _lastResult = await _repository.checkForUpdate();
    _recomputeDecision();
    await _trackCheckResult(source: 'manual');
  }

  Future<void> openUpdatePage() async {
    await _repository.openUpdatePage(_lastResult);
    _recordPromptAccepted(DateTime.now());
    await AnalyticsService.instance.track(
      'update_prompt_response',
      params: <String, Object>{
        'response': 'accepted',
        'update_source': _repository.source.analyticsValue,
        if (_lastResult.availableVersionCode != null)
          'available_version_code': _lastResult.availableVersionCode!,
      },
    );
  }

  void dismissCurrentVersion({DateTime? now}) {
    final versionCode = _lastResult.availableVersionCode;
    if (versionCode != null) {
      _storage.write(_dismissedVersionCodeKey, versionCode);
    }
    _recordPromptShown(now ?? DateTime.now());
    _dialogConsumedInSession = true;
    _recomputeDecision(now: now);
    AnalyticsService.instance.track(
      'update_prompt_response',
      params: <String, Object>{
        'response': 'dismissed',
        'update_source': _repository.source.analyticsValue,
        'available_version_code': ?versionCode,
      },
    );
  }

  Future<void> _trackCheckResult({required String source}) async {
    await AnalyticsService.instance.track(
      'update_check_result',
      params: <String, Object>{
        'result': _lastResult.status.name,
        'source': source,
        'update_source': _repository.source.analyticsValue,
        if (_repository.source == UpdateSource.githubRelease)
          'source_branch': _buildConfig.releaseTrack.sourceBranch,
        if (_lastResult.availableVersionCode != null)
          'available_version_code': _lastResult.availableVersionCode!,
      },
    );
  }

  void _recordPromptAccepted(DateTime now) {
    _recordPromptShown(now);
    _dialogConsumedInSession = true;
    _recomputeDecision(now: now);
  }

  void _recordPromptShown(DateTime now) {
    _storage.write(_lastPromptAtKey, now.millisecondsSinceEpoch);
    _storage.write(_lastPromptDayKey, _policy.dayKey(now));
  }

  void _recomputeDecision({DateTime? now}) {
    final current = now ?? DateTime.now();
    final lastPromptAtMillis = _storage.read<int>(_lastPromptAtKey);
    final lastPromptAt = lastPromptAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastPromptAtMillis);

    final decision = _policy.evaluate(
      result: _lastResult,
      now: current,
      hasActiveDownloads: _taskController?.hasActiveTransfers ?? false,
      dialogConsumedInSession: _dialogConsumedInSession,
      lastPromptAt: lastPromptAt,
      lastPromptDayKey: _storage.read<String>(_lastPromptDayKey),
      dismissedVersionCode: _storage.read<int>(_dismissedVersionCodeKey),
    );

    _shouldOfferUpdateDialog = decision == UpdatePromptDecision.dialogAllowed;
    notifyListeners();
  }
}
