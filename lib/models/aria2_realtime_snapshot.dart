import 'package:windwalker/models/download_task.dart';

/// Aria2 全量轮询快照。
///
/// Aria2 不支持增量接口（无 rid），每次轮询获取全量任务列表与全局统计，
/// 由 [RealtimeSyncController] 定时调用并写入 TaskDomainStore。
class Aria2RealtimeSnapshot {
  const Aria2RealtimeSnapshot({
    required this.downloaderId,
    required this.tasks,
    required this.downloadSpeed,
    required this.uploadSpeed,
  });

  final String downloaderId;
  final List<DownloadTask> tasks;
  final int downloadSpeed;
  final int uploadSpeed;

  int get taskCount => tasks.length;
}
