import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/services/analytics_service.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/base_downloader_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit_service.dart';
import 'package:windwalker/services/transmission_service.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';

/// 任务管理控制器
/// 按照 flutter-managing-state skill 规范使用 ChangeNotifier
///
/// 全局共享任务状态：维护按下载器分组的任务缓存，
/// 确保 TasksPage、AllTasksTabPage、TaskDetailPage 保持同步。
class TaskController extends ChangeNotifier {
  TaskController({TaskDomainStore? taskDomainStore})
      : _taskDomainStore = taskDomainStore;

  // ── 共享任务缓存 ──
  final Map<String, List<DownloadTask>> _tasksByDownloader = {};
  final Map<String, bool> _loadingByDownloader = {};
  bool _isRefreshingAll = false;

  // ── 详情态 ──
  DownloadTask? _currentTask;
  bool _isLoadingDetail = false;
  String _currentDownloaderId = '';

  // ── 错误态（fail-fast：service 异常写入此处供 UI 感知）──
  String? _errorMessage;

  // ── 操作进行中标记（暂停/恢复/删除期间禁用按钮并显示 loading）──
  bool _isActionInProgress = false;

  /// 任务域单一事实来源。
  ///
  /// attach 后，qBit / Transmission 的共享任务读取委托给 Store；
  /// 未 attach 时回退到本地缓存（Aria2 加载路径）。
  TaskDomainStore? _taskDomainStore;

  /// 绑定任务域单一事实来源。生产环境通过 Provider 注入。
  void attachTaskDomainStore(TaskDomainStore store) {
    _taskDomainStore = store;
  }

  /// 兼容空操作：任务列表的实时刷新已迁移至全局 `RealtimeSyncController`。
  ///
  /// 保留方法签名以兼容旧测试桩与历史调用点；不再持有 timer。
  @Deprecated('实时刷新已迁移至 RealtimeSyncController，调用本方法无效果')
  void startAutoRefresh(DownloaderController downloaderController) {}

  /// 兼容空操作（见 [startAutoRefresh]）。
  @Deprecated('实时刷新已迁移至 RealtimeSyncController，调用本方法无效果')
  void stopAutoRefresh() {}

  // ── Getters ──

  /// 获取指定下载器的任务列表（不可变）。
  ///
  /// attach 了 [TaskDomainStore] 时委托 Store（qBit / Transmission 共享态）；
  /// 否则回退本地缓存（Aria2 加载路径）。
  List<DownloadTask> tasksForDownloader(String downloaderId) {
    final store = _taskDomainStore;
    if (store != null) return store.tasksForDownloader(downloaderId);
    return List.unmodifiable(_tasksByDownloader[downloaderId] ?? const []);
  }

  /// 获取指定下载器下的单个任务（共享缓存查找，无匹配返回 null）。
  ///
  /// 供详情页从全局快照派生任务态，避免页面侧重新发起请求。
  DownloadTask? taskForDownloader(String downloaderId, String taskId) {
    final store = _taskDomainStore;
    if (store != null) return store.task(downloaderId, taskId);
    final tasks = _tasksByDownloader[downloaderId];
    if (tasks == null) return null;
    for (final task in tasks) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  /// 聚合所有下载器的任务，按下载速度降序排列。
  List<DownloadTask> get allTasks {
    final store = _taskDomainStore;
    if (store != null) return store.allTasks;
    final all = _tasksByDownloader.values.expand((tasks) => tasks).toList();
    all.sort((a, b) => b.downloadSpeed.compareTo(a.downloadSpeed));
    return all;
  }

  /// 是否存在进行中的下载任务（downloading / waiting）。
  /// 用于更新提醒策略：有活跃下载时压制弹窗，只保留轻提示。
  bool get hasActiveTransfers => allTasks.any(
        (task) =>
            task.status == TaskStatus.downloading ||
            task.status == TaskStatus.waiting,
      );

  /// 指定下载器是否正在加载
  bool isLoadingDownloader(String downloaderId) =>
      _loadingByDownloader[downloaderId] ?? false;

  /// 是否正在全局刷新所有任务
  bool get isRefreshingAll => _isRefreshingAll;

  /// 最近一次操作的错误信息（null 表示无错误）。UI 可读取以显式区分「空数据」与「加载失败」。
  String? get errorMessage => _errorMessage;

  /// 清除错误状态
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Getters ──
  DownloadTask? get currentTask => _currentTask;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isActionInProgress => _isActionInProgress;

  /// 进入详情页时清理不属于当前页面的旧详情态。
  void clearCurrentTaskForDetail(String taskId, String downloaderId) {
    var changed = false;

    if (_currentDownloaderId != downloaderId) {
      _currentDownloaderId = downloaderId;
      changed = true;
    }

    final currentTask = _currentTask;
    if (currentTask != null &&
        (currentTask.id != taskId ||
            currentTask.downloaderId != downloaderId)) {
      _currentTask = null;
      changed = true;
    }

    if (_isLoadingDetail && _currentTask == null) {
      _isLoadingDetail = false;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  // ── 测试辅助方法 ──

  /// 仅用于测试：直接设置指定下载器的任务缓存
  void debugSetTasksForTest(String downloaderId, List<DownloadTask> tasks) {
    _tasksByDownloader[downloaderId] = tasks;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetCurrentTaskForTest(DownloadTask? task) {
    _currentTask = task;
    notifyListeners();
  }

  /// 记录错误到 errorState（service 抛出的异常 → UI 可感知的 errorMessage）。
  /// 这是 controller 的翻译层职责：service 已 fail-fast 抛异常，controller 捕获后
  /// 写入 errorState 供 UI 显示，避免异常冒泡导致 UI 崩溃。
  void _setError(Object e) {
    _errorMessage = e is DownloaderServiceException ? e.message : e.toString();
    Log.e('TaskController error', error: e);
  }

  // ── 共享刷新接口 ──

  /// 加载指定下载器的任务（写入共享缓存）
  Future<void> loadTasksForDownloader(
    String downloaderId,
    DownloaderController downloaderController, {
    bool force = false,
  }) async {
    _loadingByDownloader[downloaderId] = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final downloader = downloaderController.getDownloader(downloaderId);
      if (downloader == null) {
        _tasksByDownloader[downloaderId] = [];
        return;
      }

      final service = _createService(downloader);
      final result = await service.getTasks();
      _tasksByDownloader[downloaderId] = result;
    } catch (e) {
      _setError(e);
    } finally {
      _loadingByDownloader[downloaderId] = false;
      notifyListeners();
    }
  }

  /// 加载所有下载器的任务（聚合刷新）。
  ///
  /// qBit / Transmission 的任务列表由 `RealtimeSyncController` 全局轮询回写，
  /// 此处仅加载 Aria2（不纳入全局实时轮询）。调用方仍可读取所有下载器的共享缓存。
  Future<void> loadAllTasks(
    DownloaderController downloaderController, {
    bool force = false,
  }) async {
    _isRefreshingAll = true;
    notifyListeners();

    try {
      for (final downloader in downloaderController.downloaders) {
        if (downloader.type != DownloaderType.aria2) continue;
        await loadTasksForDownloader(
          downloader.id,
          downloaderController,
          force: force,
        );
      }
    } finally {
      _isRefreshingAll = false;
      notifyListeners();
    }
  }

  // ── 共享任务操作入口（事件驱动刷新） ──

  /// 添加下载任务并刷新目标下载器缓存
  ///
  /// 统一入口：支持 URL 和种子文件两种来源。
  /// 通过 [AddTaskRequest.hasUrlSource] / [hasTorrentSource]
  /// 由具体 Service 实现决定调用路径。
  Future<bool> addTask(
    AddTaskRequest request,
    DownloaderController downloaderController,
  ) async {
    final downloader = downloaderController.getDownloader(request.downloaderId);
    if (downloader == null) return false;

    final service = _createService(downloader);
    final source = request.hasTorrentSource
        ? 'torrent'
        : request.hasUrlSource
              ? 'url'
              : 'unknown';
    final baseParams = <String, Object>{
      'source': source,
      'downloader_type': downloader.type.name,
      'has_save_path': request.savePath != null,
    };

    try {
      final result = await service.addTask(request);
      if (result.isEmpty) {
        await AnalyticsService.instance.track(
          'task_add_result',
          params: <String, Object>{...baseParams, 'result': 'failed'},
        );
        return false;
      }

      await loadTasksForDownloader(request.downloaderId, downloaderController,
          force: true);
      await AnalyticsService.instance.track(
        'task_add_result',
        params: <String, Object>{...baseParams, 'result': 'success'},
      );
      return true;
    } catch (e) {
      _setError(e);
      await AnalyticsService.instance.track(
        'task_add_result',
        params: <String, Object>{
          ...baseParams,
          'result': 'failed',
          'error_type': e.runtimeType.toString(),
        },
      );
      return false;
    }
  }

  /// 暂停任务并刷新指定下载器缓存
  Future<void> pauseTaskForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController,
  ) async {
    final downloader = downloaderController.getDownloader(downloaderId);
    if (downloader == null) return;

    final service = _createService(downloader);
    final type = downloader.type.name;

    _isActionInProgress = true;
    notifyListeners();

    try {
      await service.pauseTask(taskId);
      await loadTasksForDownloader(downloaderId, downloaderController,
          force: true);
      await loadTaskDetailForDownloader(
          taskId, downloaderId, downloaderController);
      await AnalyticsService.instance.track(
        'task_action_result',
        params: <String, Object>{
          'action': 'pause',
          'result': 'success',
          'downloader_type': type,
        },
      );
    } catch (e) {
      _setError(e);
      await AnalyticsService.instance.track(
        'task_action_result',
        params: <String, Object>{
          'action': 'pause',
          'result': 'failed',
          'downloader_type': type,
          'error_type': e.runtimeType.toString(),
        },
      );
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  /// 恢复任务并刷新指定下载器缓存
  Future<void> resumeTaskForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController,
  ) async {
    final downloader = downloaderController.getDownloader(downloaderId);
    if (downloader == null) return;

    final service = _createService(downloader);
    final type = downloader.type.name;

    _isActionInProgress = true;
    notifyListeners();

    try {
      await service.resumeTask(taskId);
      await loadTasksForDownloader(downloaderId, downloaderController,
          force: true);
      await loadTaskDetailForDownloader(
          taskId, downloaderId, downloaderController);
      await AnalyticsService.instance.track(
        'task_action_result',
        params: <String, Object>{
          'action': 'resume',
          'result': 'success',
          'downloader_type': type,
        },
      );
    } catch (e) {
      _setError(e);
      await AnalyticsService.instance.track(
        'task_action_result',
        params: <String, Object>{
          'action': 'resume',
          'result': 'failed',
          'downloader_type': type,
          'error_type': e.runtimeType.toString(),
        },
      );
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  /// 删除任务并刷新指定下载器缓存
  Future<void> removeTaskForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController, {
    bool deleteFiles = false,
  }) async {
    final downloader = downloaderController.getDownloader(downloaderId);
    if (downloader == null) return;

    final service = _createService(downloader);
    final type = downloader.type.name;

    try {
      await service.removeTask(taskId, deleteFiles: deleteFiles);
      await loadTasksForDownloader(downloaderId, downloaderController,
          force: true);
      await AnalyticsService.instance.track(
        'task_action_result',
        params: <String, Object>{
          'action': 'remove',
          'result': 'success',
          'downloader_type': type,
          'delete_files': deleteFiles,
        },
      );
    } catch (e) {
      _setError(e);
      await AnalyticsService.instance.track(
        'task_action_result',
        params: <String, Object>{
          'action': 'remove',
          'result': 'failed',
          'downloader_type': type,
          'delete_files': deleteFiles,
          'error_type': e.runtimeType.toString(),
        },
      );
    }
  }

  /// 加载单个任务详情（显式传入 downloaderId，共享接口）
  Future<void> loadTaskDetailForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController,
  ) async {
    clearCurrentTaskForDetail(taskId, downloaderId);
    _isLoadingDetail = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final downloader = downloaderController.getDownloader(downloaderId);
      if (downloader == null) {
        Log.w(
            'TaskController.loadTaskDetailForDownloader: downloader not found, id=$downloaderId');
        return;
      }

      final service = _createService(downloader);
      final result = await service.getTaskDetail(taskId);
      _currentTask = result;
    } catch (e) {
      _setError(e);
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  /// 创建对应的服务
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
}

