import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';
import 'package:windwalker/models/qbit_task_detail.dart';
import 'package:windwalker/models/qbit_task_file_node.dart';
import 'package:windwalker/models/qbit_task_options.dart';
import 'package:windwalker/models/qbit_task_options_update.dart';
import 'package:windwalker/models/qbit_task_peer.dart';
import 'package:windwalker/models/qbit_task_source.dart';

/// qBittorrent 操作的 adapter 契约。
///
/// 版本无关的接口，由 QBitV4Adapter / QBitV5Adapter 实现；
/// QBitService 作为 facade 委托给具体 adapter。
abstract class QBitApiAdapter {
  Future<List<DownloadTask>> getTasks();

  Future<Map<String, dynamic>> getGlobalStat();

  /// 从 `/api/v2/sync/maindata?rid=X` 获取全量/增量实时快照。
  ///
  /// [rid] 为 0 时返回 `full_update` 全量快照，>0 时返回增量（仅变化字段），
  /// 调用方负责在本地 merge。
  Future<QBitRealtimeSnapshot> getRealtimeSnapshot({required int rid});

  /// 从 `/api/v2/sync/maindata?rid=X` 获取原始 JSON（保留增量字段语义）。
  ///
  /// 供全局轮询控制器做精确 mergeJson：增量响应中缺省的字段不会被 `fromJson`
  /// 的默认值污染。返回的 Map 含 `rid` / `full_update` / `server_state` /
  /// `torrents` / `torrents_removed` / `categories` / `tags` 等原始键。
  Future<Map<String, dynamic>> getRealtimeMainData({required int rid});

  Future<String> addTask(AddTaskRequest request);

  Future<String> addDownload(String url, {String? savePath});

  Future<String> getDefaultSavePath();

  Future<void> pauseTask(String taskId);

  Future<void> resumeTask(String taskId);

  Future<void> removeTask(String taskId, {bool deleteFiles = false});

  Future<DownloaderSpeedConfig> getSpeedConfig();

  Future<bool> setSpeedConfig(DownloaderSpeedConfig config);

  Future<DownloadTask?> getTaskDetail(String taskId);

  /// 合并 `/torrents/info` + `/properties` + `/trackers` + `/webseeds`
  /// 得到 qBit 信息主页读模型。
  Future<QBitTaskDetail?> getTaskFullDetail(String taskId);

  /// 从 `/sync/maindata?rid=X` 获取指定任务的动态数据增量。
  ///
  /// [rid] 为 0 时返回全量快照，>0 时返回增量（仅变化字段）。
  /// 返回 `(newRid, torrentSyncMap)`；torrentSyncMap 为 null 表示该任务无变化。
  Future<(int rid, Map<String, dynamic>?)> getTaskSyncUpdate(
      String taskId, int rid);

  /// 解析 `/torrents/files` 为只读文件树。
  Future<List<QBitTaskFileNode>> getTaskFiles(String taskId);

  /// 解析 `/trackers` 中的伪 tracker（DHT/PeX/LSD）为来源卡片。
  Future<List<QBitTaskSource>> getTaskSources(String taskId);

  /// 解析 `/sync/torrentPeers`（rid=0）为对端行。
  Future<List<QBitTaskPeer>> getTaskPeers(String taskId);

  /// 读取队列位置、分类、标签及可选目录。
  Future<QBitTaskOptions> getTaskOptions(String taskId);

  /// 按差异写队列动作、分类、标签。
  Future<void> updateTaskOptions(
    String taskId, {
    required QBitTaskOptions current,
    required QBitTaskOptionsUpdate update,
  });
}
