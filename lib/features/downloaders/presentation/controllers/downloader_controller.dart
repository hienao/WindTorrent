import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/core/utils/review_manager.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/analytics_service.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/speed_config_descriptor.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/base_downloader_service.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/qbit_service.dart';
import 'package:windwalker/services/transmission_service.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';

/// 下载器管理控制器
/// 按照 flutter-managing-state skill 规范使用 ChangeNotifier 实现 MVVM
class DownloaderController extends ChangeNotifier {
  static const String _storageKey = 'downloaders';

  final GetStorage _storage;

  // observable 状态
  List<Downloader> _downloaders = [];
  bool _isLoading = false;

  bool _notifyScheduled = false;
  final Map<String, int> _statusFailureCount = {};
  static const int _offlineFailureThreshold = 3;

  /// 构造函数 - 不执行任何初始化操作
  DownloaderController({GetStorage? storage})
    : _storage = storage ?? GetStorage();

  void _notifySafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }

    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// 初始化 - 应在 UI 层调用
  ///
  /// 全局 qBit / Transmission 实时轮询由 `RealtimeSyncController` 接管
  /// （在 `HomeTabContainer` 中 `start()`）。本方法只负责加载本地数据，
  /// 并刷新 Aria2 的连接状态与全局统计（Aria2 不纳入全局实时轮询）。
  void init() {
    // 只加载本地数据
    _loadDownloaders();
    // 延迟刷新状态，避免阻塞启动
    Future.delayed(const Duration(milliseconds: 500), () {
      refreshLegacyAria2State();
      _syncDownloaderUserProperties();
    });
  }

  /// 刷新 Aria2 下载器状态与全局统计。
  ///
  /// Aria2 不纳入全局实时轮询，保留其原有的连接探测 / 统计刷新路径。
  /// qBit / Transmission 的实时状态由 `RealtimeSyncController` 回写。
  Future<void> refreshLegacyAria2State() async {
    await refreshAllStatus();
    await refreshGlobalStats();
  }

  /// 兼容空操作：全局轮询已迁移至 `RealtimeSyncController`。
  ///
  /// 保留方法签名以兼容旧测试桩与历史调用点；不再持有 timer。
  @Deprecated('全局轮询已迁移至 RealtimeSyncController，调用本方法无效果')
  void stopPeriodicRefresh() {}

  // Getters
  List<Downloader> get downloaders => List.unmodifiable(_downloaders);
  bool get isLoading => _isLoading;

  /// 仅用于测试：直接覆盖下载器列表（跳过存储加载）。
  @visibleForTesting
  void setTestDownloadersForTest(List<Downloader> downloaders) {
    _downloaders = List<Downloader>.from(downloaders);
  }

  /// 加载下载器列表（仅本地数据）
  Future<void> _loadDownloaders() async {
    try {
      final data = _storage.read<List>(_storageKey);
      if (data != null) {
        _downloaders = data
            .map((e) => Downloader.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _notifySafely();
      }
    } catch (e) {
      Log.e('加载下载器失败: $e', error: e);
    }
  }

  /// 加载下载器列表（包括刷新状态）
  Future<void> loadDownloaders() async {
    _isLoading = true;
    _notifySafely();

    try {
      await _loadDownloaders();
      await refreshAllStatus();
      await refreshGlobalStats();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  /// 保存下载器列表
  Future<void> _saveDownloaders() async {
    await _storage.write(
      _storageKey,
      _downloaders.map((e) => e.toJson()).toList(),
    );
  }

  /// 刷新所有下载器状态
  Future<void> refreshAllStatus() async {
    for (int i = 0; i < _downloaders.length; i++) {
      await refreshStatus(_downloaders[i].id, notify: false);
    }
    _notifySafely();
  }

  /// 刷新单个下载器状态
  Future<void> refreshStatus(String id, {bool notify = true}) async {
    final index = _downloaders.indexWhere((d) => d.id == id);
    if (index == -1) return;

    final downloader = _downloaders[index];
    final previousStatus = downloader.status;
    final service = _createService(downloader);

    try {
      final result = await service.testConnection();
      if (result is! ConnectionSuccess) {
        final failCount = (_statusFailureCount[id] ?? 0) + 1;
        _statusFailureCount[id] = failCount;
        if (failCount >= _offlineFailureThreshold) {
          _downloaders[index] = downloader.copyWith(
            status: DownloaderStatus.offline,
          );
          _trackStatusChanged(downloader.type, previousStatus, DownloaderStatus.offline, failCount);
        }
        if (notify) _notifySafely();
        return;
      }

      final stat = await service.getGlobalStat();
      _statusFailureCount[id] = 0;

      _downloaders[index] = downloader.copyWith(
        status: DownloaderStatus.online,
        downloadSpeed: _toInt(stat['downloadSpeed']),
        uploadSpeed: _toInt(stat['uploadSpeed']),
        taskCount: _toInt(
          stat['torrentCount'] ?? stat['numActive'] ?? downloader.taskCount,
        ),
      );
      _trackStatusChanged(downloader.type, previousStatus, DownloaderStatus.online, 0);
      if (notify) _notifySafely();
    } catch (e) {
      final failCount = (_statusFailureCount[id] ?? 0) + 1;
      _statusFailureCount[id] = failCount;
      if (failCount >= _offlineFailureThreshold) {
        _downloaders[index] = downloader.copyWith(
          status: DownloaderStatus.offline,
        );
        _trackStatusChanged(downloader.type, previousStatus, DownloaderStatus.offline, failCount);
      }
      if (notify) _notifySafely();
    }
  }

  /// 测试连接
  Future<ConnectionResult> testConnection(Downloader downloader) async {
    final service = _createService(downloader);
    return await service.testConnection();
  }

  /// 创建服务
  DownloaderService _createService(Downloader downloader) {
    switch (downloader.type) {
      case DownloaderType.aria2:
        return Aria2Service(downloader);
      case DownloaderType.qbittorrent:
        return QBitService(downloader);
      case DownloaderType.transmission:
        return TransmissionService(downloader);
    }
  }

  /// 添加下载器（硬门禁：连接失败或版本不符均不保存）
  Future<ConnectionResult> addDownloader(Downloader downloader) async {
    final result = await testConnection(downloader);
    if (result is ConnectionSuccess) {
      _downloaders.add(
        downloader.copyWith(
          status: DownloaderStatus.online,
          version: result.serverVersion,
        ),
      );
      await _saveDownloaders();
      _notifySafely();
      await AnalyticsService.instance.track(
        'downloader_add_result',
        params: <String, Object>{
          'result': 'success',
          'type': downloader.type.name,
          'use_https': downloader.useHttps,
        },
      );
      await _syncDownloaderUserProperties();
    } else {
      final category = result is ConnectionFailure
          ? _failureCategoryName(result.category)
          : 'unknown';
      await AnalyticsService.instance.track(
        'downloader_add_result',
        params: <String, Object>{
          'result': 'failed',
          'type': downloader.type.name,
          'failure_category': category,
          'use_https': downloader.useHttps,
        },
      );
    }
    return result;
  }

  /// 更新下载器（硬门禁：连接失败或版本不符不更新）
  Future<ConnectionResult> updateDownloader(Downloader downloader) async {
    final result = await testConnection(downloader);
    if (result is ConnectionSuccess) {
      final updated = downloader.copyWith(
        status: DownloaderStatus.online,
        version: result.serverVersion,
      );
      final index = _downloaders.indexWhere((d) => d.id == downloader.id);
      if (index != -1) {
        _downloaders[index] = updated;
        await _saveDownloaders();
        _notifySafely();
        await AnalyticsService.instance.track(
          'downloader_update_result',
          params: <String, Object>{
            'result': 'success',
            'type': downloader.type.name,
            'use_https': downloader.useHttps,
          },
        );
        await _syncDownloaderUserProperties();
      }
    } else {
      final category = result is ConnectionFailure
          ? _failureCategoryName(result.category)
          : 'unknown';
      await AnalyticsService.instance.track(
        'downloader_update_result',
        params: <String, Object>{
          'result': 'failed',
          'type': downloader.type.name,
          'failure_category': category,
          'use_https': downloader.useHttps,
        },
      );
    }
    return result;
  }

  /// 删除下载器
  Future<void> removeDownloader(String id) async {
    final downloader = getDownloader(id);
    final type = downloader?.type.name ?? 'unknown';

    _downloaders.removeWhere((d) => d.id == id);
    _statusFailureCount.remove(id);
    await _saveDownloaders();
    _notifySafely();

    await AnalyticsService.instance.track(
      'downloader_remove',
      params: <String, Object>{'type': type},
    );
    await _syncDownloaderUserProperties();
  }

  /// 上报下载器状态翻转事件（仅 online↔offline 翻转时触发）。
  void _trackStatusChanged(
    DownloaderType type,
    DownloaderStatus previous,
    DownloaderStatus current,
    int consecutiveFailures,
  ) {
    if (previous == current) return;
    final transition = current == DownloaderStatus.online
        ? 'offline_to_online'
        : 'online_to_offline';
    AnalyticsService.instance.track(
      'downloader_status_changed',
      params: <String, Object>{
        'type': type.name,
        'transition': transition,
        'consecutive_failures': consecutiveFailures,
      },
    );
  }

  /// 将 ConnectionFailureCategory 映射为埋点友好的字符串。
  String _failureCategoryName(ConnectionFailureCategory c) {
    switch (c) {
      case ConnectionFailureCategory.versionUnsupported:
        return 'version_unsupported';
      case ConnectionFailureCategory.authFailed:
        return 'auth';
      case ConnectionFailureCategory.networkError:
        return 'network';
      case ConnectionFailureCategory.unknown:
        return 'unknown';
    }
  }

  /// 同步下载器画像到 user_property。
  Future<void> _syncDownloaderUserProperties() async {
    final count = _downloaders.length;
    final types = _downloaders.map((d) => d.type.name).toSet();
    final typeLabel = count == 0
        ? 'none'
        : types.length == 1
              ? types.first
              : 'multiple';
    final hasOnline = _downloaders.any(
      (d) => d.status == DownloaderStatus.online,
    );

    await AnalyticsService.instance.setUserProperty(
      'downloader_count',
      count.toString(),
    );
    await AnalyticsService.instance.setUserProperty(
      'downloader_types',
      typeLabel,
    );
    await AnalyticsService.instance.setUserProperty(
      'has_online_downloader',
      hasOnline.toString(),
    );
  }

  /// 根据ID获取下载器
  Downloader? getDownloader(String id) {
    return _downloaders.where((d) => d.id == id).firstOrNull;
  }

  // ── 备份导出 / 原子替换 / 回滚快照 ──────────────────────────────

  /// 导出当前下载器列表为 JSON（供备份使用）。
  List<Map<String, dynamic>> exportDownloadersForBackup() {
    return _downloaders.map((e) => e.toJson()).toList(growable: false);
  }

  /// 原子全量替换下载器列表（备份恢复入口）。
  ///
  /// 替换前自动保存回滚快照，失败时快照可用。
  Future<void> replaceAllDownloadersFromBackup({
    required List<Downloader> downloaders,
    required String sourceBackupId,
  }) async {
    await saveRollbackSnapshot(sourceBackupId: sourceBackupId);
    _downloaders = List<Downloader>.from(downloaders);
    await _saveDownloaders();
    _notifySafely();
  }

  /// 保存回滚快照到本地存储。
  Future<void> saveRollbackSnapshot({required String sourceBackupId}) async {
    await _storage.write('downloaders_import_rollback_snapshot', {
      'sourceBackupId': sourceBackupId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'downloaders': _downloaders.map((e) => e.toJson()).toList(),
    });
  }

  /// 回滚快照是否存在（UI 用于决定是否显示"撤销"按钮）。
  bool get hasRollbackSnapshot =>
      _storage.read<Map>('downloaders_import_rollback_snapshot') != null;

  /// 恢复回滚快照。
  ///
  /// 返回 true 表示恢复成功，false 表示无快照可恢复。
  Future<bool> restoreRollbackSnapshot() async {
    final json = _storage.read<Map>('downloaders_import_rollback_snapshot');
    if (json == null) return false;
    _downloaders = (json['downloaders'] as List<dynamic>)
        .map((e) => Downloader.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    await _storage.remove('downloaders_import_rollback_snapshot');
    await _saveDownloaders();
    _notifySafely();
    return true;
  }

  /// 任务域单一事实来源（实时摘要派生源）。
  ///
  /// attach 后，qBit / Transmission 的实时摘要可经 [realtimeSummary] 读取；
  /// 未 attach 时返回 null。
  TaskDomainStore? _taskDomainStore;

  /// 绑定任务域单一事实来源。生产环境通过 Provider 注入。
  void attachTaskDomainStore(TaskDomainStore store) {
    _taskDomainStore = store;
  }

  /// 读取下载器维度的实时摘要（来自 [TaskDomainStore]）。
  ///
  /// qBit / Transmission 的速度 / 任务数 / 在线状态由全局轮询写入 Store；
  /// 列表与卡片可优先读此处派生展示态。无数据返回 null。
  DownloaderRealtimeSummary? realtimeSummary(String downloaderId) =>
      _taskDomainStore?.summary(downloaderId);

  /// 根据类型获取下载器
  List<Downloader> getDownloadersByType(DownloaderType type) {
    return _downloaders.where((d) => d.type == type).toList();
  }

  /// 获取速度配置描述符
  SpeedConfigDescriptor? getSpeedConfigDescriptor(String downloaderId) {
    final downloader = getDownloader(downloaderId);
    if (downloader == null) return null;
    final service = _createService(downloader);
    return service.getSpeedConfigDescriptor();
  }

  /// 获取下载器速度配置
  ///
  /// catch 作为翻译层：service 异常 → null（失败信号）+ 日志。
  Future<DownloaderSpeedConfig?> getSpeedConfig(String downloaderId) async {
    final downloader = getDownloader(downloaderId);
    if (downloader == null) return null;
    final service = _createService(downloader);
    try {
      return await service.getSpeedConfig();
    } catch (e) {
      Log.e('获取速度配置失败', error: e);
      return null;
    }
  }

  /// 设置下载器速度配置
  ///
  /// catch 作为翻译层：service 异常 → false（失败信号）+ 日志。
  Future<bool> setSpeedConfig(
    String downloaderId,
    DownloaderSpeedConfig config,
  ) async {
    final downloader = getDownloader(downloaderId);
    if (downloader == null) return false;
    final service = _createService(downloader);
    try {
      return await service.setSpeedConfig(config);
    } catch (e) {
      Log.e('设置速度配置失败', error: e);
      return false;
    }
  }

  /// 获取全局统计（异步，需要先调用 refreshGlobalStats）
  Map<String, int> get globalStats {
    return _globalStatsCache;
  }

  Map<String, int> _globalStatsCache = {
    'downloading': 0,
    'waiting': 0,
    'paused': 0,
    'seeding': 0,
    'completed': 0,
    'error': 0,
    'total': 0,
    'totalSpeed': 0,
    'uploadSpeed': 0,
    'uploading': 0,
    'downloaderCount': 0,
    'onlineCount': 0,
  };

  /// 刷新全局统计（从所有在线下载器获取真实任务数据）
  ///
  /// 单个下载器获取失败不影响全局统计（合理的故障隔离）。
  Future<void> refreshGlobalStats() async {
    Log.i(
      'refreshGlobalStats: starting for ${_downloaders.length} downloaders',
    );

    int downloading = 0;
    int waiting = 0;
    int paused = 0;
    int completed = 0;
    int error = 0;
    int seeding = 0;
    int total = 0;
    int totalSpeed = 0;
    int uploadSpeed = 0;

    for (int i = 0; i < _downloaders.length; i++) {
      final d = _downloaders[i];
      if (d.status == DownloaderStatus.online) {
        final service = _createService(d);
        try {
          final tasks = await service.getTasks();
          total += tasks.length;

          // 单个下载器的分类统计
          int dDownloading = 0;
          int dWaiting = 0;
          int dPaused = 0;
          int dSeeding = 0;
          int dCompleted = 0;
          int dError = 0;

          for (final task in tasks) {
            switch (task.status) {
              case TaskStatus.downloading:
                dDownloading++;
                downloading++;
                totalSpeed += task.downloadSpeed;
                break;
              case TaskStatus.waiting:
                dWaiting++;
                waiting++;
                break;
              case TaskStatus.paused:
                dPaused++;
                paused++;
                break;
              case TaskStatus.seeding:
                dSeeding++;
                seeding++;
                uploadSpeed += task.uploadSpeed;
                break;
              case TaskStatus.completed:
              case TaskStatus.removed:
                dCompleted++;
                completed++;
                break;
              case TaskStatus.error:
                dError++;
                error++;
                break;
              default:
                break;
            }
          }

          // 存储单个下载器的分类统计
          _downloaders[i] = d.copyWith(
            taskStats: {
              'downloading': dDownloading,
              'waiting': dWaiting,
              'paused': dPaused,
              'seeding': dSeeding,
              'completed': dCompleted,
              'error': dError,
            },
            taskCount: tasks.length,
          );
        } catch (e) {
          Log.e('Failed to get tasks from ${d.name}', error: e);
        }
      } else {
        // 离线下载器清空统计
        if (d.taskStats.isNotEmpty) {
          _downloaders[i] = d.copyWith(taskStats: {});
        }
      }
    }

    Log.i(
      'refreshGlobalStats: done - total=$total, downloading=$downloading, seeding=$seeding, completed=$completed',
    );

    _globalStatsCache = {
      'downloading': downloading,
      'waiting': waiting,
      'paused': paused,
      'completed': completed,
      'error': error,
      'seeding': seeding,
      'total': total,
      'totalSpeed': totalSpeed,
      'uploadSpeed': uploadSpeed,
      'downloaderCount': _downloaders.length,
      'onlineCount': _downloaders
          .where((d) => d.status == DownloaderStatus.online)
          .length,
    };

    unawaited(
      _recordReviewSignalsAfterStats(
        completedTaskCount: completed,
        errorTaskCount: error,
      ),
    );

    final hasActive = downloading > 0 || waiting > 0;
    unawaited(
      AnalyticsService.instance.setUserProperty(
        'has_active_task',
        hasActive.toString(),
      ),
    );

    _notifySafely();
  }

  Future<void> _recordReviewSignalsAfterStats({
    required int completedTaskCount,
    required int errorTaskCount,
  }) async {
    if (_downloaders.isEmpty) return;

    final reviewManager = ReviewManager();
    await reviewManager.recordCompletedTaskSeenAndMaybeRequestReview(
      completedTaskCount: completedTaskCount,
    );
    await reviewManager.recordHealthyUsageDayAndMaybeRequestReview(
      hasErrorState:
          errorTaskCount > 0 ||
          _downloaders.any((d) => d.status != DownloaderStatus.online),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
