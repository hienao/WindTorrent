import 'package:flutter/foundation.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/aria2_realtime_snapshot.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';
import 'package:windwalker/models/transmission_realtime_snapshot.dart';

/// 下载器维度的实时摘要。
///
/// 由 [TaskDomainStore] 在每次轮询回写时派生，供页面与 controller 读取，
/// 不再让消费方各自保存第二份实时态。
class DownloaderRealtimeSummary {
  const DownloaderRealtimeSummary({
    required this.status,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.taskCount,
    required this.taskStats,
  });

  final DownloaderStatus status;
  final int downloadSpeed;
  final int uploadSpeed;
  final int taskCount;
  final Map<String, int> taskStats;
}

/// 任务域单一事实来源。
///
/// 接收 qBit / Transmission 的 typed 快照与 Aria2 手动加载的任务列表，
/// 保存标准化后的共享任务对象、下载器维度实时摘要与 qBit 元数据（categories / tags）。
/// 页面与下游 controller 通过只读 selector 派生展示态，不再自行轮询或缓存实时任务。
class TaskDomainStore extends ChangeNotifier {
  final Map<String, QBitRealtimeSnapshot> _qbitSnapshots = {};
  final Map<String, TransmissionRealtimeSnapshot> _transmissionSnapshots = {};
  final Map<String, Aria2RealtimeSnapshot> _aria2Snapshots = {};
  final Map<String, List<DownloadTask>> _tasksByDownloader = {};
  final Map<String, DownloaderRealtimeSummary> _summaries = {};

  // ─── 只读选择器 ──────────────────────────────────────────────

  /// qBit 指定下载器的最新快照（无数据返回 null）。
  QBitRealtimeSnapshot? qbitSnapshot(String downloaderId) =>
      _qbitSnapshots[downloaderId];

  /// Transmission 指定下载器的最新快照（无数据返回 null）。
  TransmissionRealtimeSnapshot? transmissionSnapshot(String downloaderId) =>
      _transmissionSnapshots[downloaderId];

  /// Aria2 指定下载器的最新快照（无数据返回 null）。
  Aria2RealtimeSnapshot? aria2Snapshot(String downloaderId) =>
      _aria2Snapshots[downloaderId];

  /// 指定下载器的任务列表（不可变）。
  List<DownloadTask> tasksForDownloader(String downloaderId) =>
      List.unmodifiable(_tasksByDownloader[downloaderId] ?? const []);

  /// 聚合所有下载器的任务，按下载速度降序排列。
  List<DownloadTask> get allTasks {
    final tasks = _tasksByDownloader.values.expand((e) => e).toList();
    tasks.sort((a, b) => b.downloadSpeed.compareTo(a.downloadSpeed));
    return tasks;
  }

  /// 指定下载器下的单个任务（无匹配返回 null）。
  DownloadTask? task(String downloaderId, String taskId) {
    for (final task
        in _tasksByDownloader[downloaderId] ?? const <DownloadTask>[]) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  /// qBit 指定下载器的分类名列表（来自快照的 categories）。
  List<String> qbitCategories(String downloaderId) =>
      qbitSnapshot(downloaderId)?.categories.values.toList() ?? const [];

  /// qBit 指定下载器的标签列表（来自快照的 tags）。
  List<String> qbitTags(String downloaderId) =>
      qbitSnapshot(downloaderId)?.tags ?? const [];

  /// 下载器维度的实时摘要（无数据返回 null）。
  DownloaderRealtimeSummary? summary(String downloaderId) =>
      _summaries[downloaderId];

  // ─── 写入口（由 RealtimeSyncController 调用）─────────────────

  /// 写入 qBit 快照，同步更新任务列表、摘要与 qBit 元数据。
  void applyQBitSnapshot(QBitRealtimeSnapshot snapshot) {
    final tasks = snapshot.tasks;
    _qbitSnapshots[snapshot.downloaderId] = snapshot;
    _tasksByDownloader[snapshot.downloaderId] = List<DownloadTask>.from(tasks);
    _summaries[snapshot.downloaderId] = DownloaderRealtimeSummary(
      status: DownloaderStatus.online,
      downloadSpeed: snapshot.serverState.downloadSpeed,
      uploadSpeed: snapshot.serverState.uploadSpeed,
      taskCount: tasks.length,
      taskStats: _aggregate(tasks),
    );
    notifyListeners();
  }

  /// 写入 Transmission 快照，同步更新任务列表与摘要。
  void applyTransmissionSnapshot(TransmissionRealtimeSnapshot snapshot) {
    final tasks = snapshot.tasks;
    _transmissionSnapshots[snapshot.downloaderId] = snapshot;
    _tasksByDownloader[snapshot.downloaderId] = List<DownloadTask>.from(tasks);
    _summaries[snapshot.downloaderId] = DownloaderRealtimeSummary(
      status: DownloaderStatus.online,
      downloadSpeed: snapshot.totalDownloadSpeed,
      uploadSpeed: snapshot.totalUploadSpeed,
      taskCount: tasks.length,
      taskStats: _aggregate(tasks),
    );
    notifyListeners();
  }

  /// 写入 Aria2 全量轮询快照，同步更新任务列表与摘要。
  ///
  /// 由 [RealtimeSyncController] 定时调用，与 qBit / Transmission 路径一致。
  void applyAria2Snapshot(Aria2RealtimeSnapshot snapshot) {
    _aria2Snapshots[snapshot.downloaderId] = snapshot;
    _tasksByDownloader[snapshot.downloaderId] =
        List<DownloadTask>.from(snapshot.tasks);
    _summaries[snapshot.downloaderId] = DownloaderRealtimeSummary(
      status: DownloaderStatus.online,
      downloadSpeed: snapshot.downloadSpeed,
      uploadSpeed: snapshot.uploadSpeed,
      taskCount: snapshot.taskCount,
      taskStats: _aggregate(snapshot.tasks),
    );
    notifyListeners();
  }

  /// 清除指定下载器的任务数据与摘要（下载器被删除时调用）。
  void removeDownloader(String downloaderId) {
    _tasksByDownloader.remove(downloaderId);
    _summaries.remove(downloaderId);
    _qbitSnapshots.remove(downloaderId);
    _transmissionSnapshots.remove(downloaderId);
    _aria2Snapshots.remove(downloaderId);
    notifyListeners();
  }

  /// 标记下载器离线：清零速度与任务数，状态置为 offline。
  void markDownloaderOffline(String downloaderId) {
    _summaries[downloaderId] = const DownloaderRealtimeSummary(
      status: DownloaderStatus.offline,
      downloadSpeed: 0,
      uploadSpeed: 0,
      taskCount: 0,
      taskStats: {},
    );
    notifyListeners();
  }

  // ─── 测试辅助 ────────────────────────────────────────────────

  /// 直接写入 qBit 快照（测试用，供 selector / 联动测试使用）。
  @visibleForTesting
  void debugApplyQBitSnapshot(QBitRealtimeSnapshot snapshot) =>
      applyQBitSnapshot(snapshot);

  /// 直接写入指定下载器的任务列表（测试用，供页面联动测试 seed 数据）。
  @visibleForTesting
  void debugSetTasksForDownloader(
    String downloaderId,
    List<DownloadTask> tasks,
  ) {
    _tasksByDownloader[downloaderId] = List<DownloadTask>.from(tasks);
    notifyListeners();
  }

  // ─── 内部 ────────────────────────────────────────────────────

  Map<String, int> _aggregate(List<DownloadTask> tasks) {
    final stats = <String, int>{
      'downloading': 0,
      'waiting': 0,
      'paused': 0,
      'seeding': 0,
      'completed': 0,
      'error': 0,
    };
    for (final task in tasks) {
      switch (task.status) {
        case TaskStatus.downloading:
          stats['downloading'] = stats['downloading']! + 1;
          break;
        case TaskStatus.waiting:
          stats['waiting'] = stats['waiting']! + 1;
          break;
        case TaskStatus.paused:
          stats['paused'] = stats['paused']! + 1;
          break;
        case TaskStatus.seeding:
          stats['seeding'] = stats['seeding']! + 1;
          break;
        case TaskStatus.completed:
        case TaskStatus.removed:
          stats['completed'] = stats['completed']! + 1;
          break;
        case TaskStatus.error:
          stats['error'] = stats['error']! + 1;
          break;
        case TaskStatus.unknown:
          break;
      }
    }
    return stats;
  }
}
