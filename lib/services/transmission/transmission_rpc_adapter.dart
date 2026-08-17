import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/transmission_realtime_snapshot.dart';
import 'package:windwalker/models/transmission_task_detail.dart';
import 'package:windwalker/models/transmission_task_file_node.dart';
import 'package:windwalker/models/transmission_task_options.dart';
import 'package:windwalker/models/transmission_task_options_update.dart';
import 'package:windwalker/models/transmission_task_peer.dart';
import 'package:windwalker/models/transmission_task_tracker.dart';
import 'package:windwalker/services/connection_result.dart';

/// Transmission RPC adapter 统一接口。
///
/// modern / legacy 各自实现此接口，处理协议层的
/// 方法名、字段名、请求/响应结构差异，
/// 对外统一输出 `DownloadTask`、`DownloaderSpeedConfig`、`ConnectionResult`。
abstract class TransmissionRpcAdapter {
  Future<ConnectionResult> testConnection();
  Future<List<DownloadTask>> getTasks();
  Future<DownloadTask?> getTaskDetail(String taskId);
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId);
  Future<TransmissionRealtimeSnapshot> getRealtimeSnapshot();
  Future<Map<String, dynamic>> getGlobalStat();
  Future<String> addTask(AddTaskRequest request);
  Future<void> pauseTask(String taskId);
  Future<void> resumeTask(String taskId);
  Future<void> removeTask(String taskId, {bool deleteFiles = false});
  Future<DownloaderSpeedConfig> getSpeedConfig();
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config);

  // ─── 子页面数据方法 ──────────────────────────────────────────

  /// 获取任务的文件树（扁平列表，由上层构建树形结构）。
  Future<List<TransmissionTaskFileNode>> getTaskFiles(String taskId);

  /// 获取任务的 tracker 列表。
  Future<List<TransmissionTaskTracker>> getTaskTrackers(String taskId);

  /// 获取任务的 peer 列表。
  Future<List<TransmissionTaskPeer>> getTaskPeers(String taskId);

  /// 获取任务的选项设置。
  Future<TransmissionTaskOptions> getTaskOptions(String taskId);

  /// 更新任务的选项设置。
  Future<void> updateTaskOptions(
    String taskId,
    TransmissionTaskOptionsUpdate update,
  );
}
