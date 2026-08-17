import 'package:http/http.dart' as http;
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
import 'package:windwalker/models/speed_config_descriptor.dart';
import 'package:windwalker/services/base_downloader_service.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit/qbit_api_adapter.dart';
import 'package:windwalker/services/qbit/qbit_api_generation.dart';
import 'package:windwalker/services/qbit/qbit_server_profile.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';
import 'package:windwalker/services/qbit/qbit_v4_adapter.dart';
import 'package:windwalker/services/qbit/qbit_v5_adapter.dart';
import 'package:windwalker/services/qbit/qbit_version_detector.dart';

/// qBittorrent 下载器服务（facade）。
///
/// 自动探测服务端代际（4.1–4.6.x legacy / 5.0+ modern），委托给对应版本
/// adapter，对调用方完全透明。探测结果与 adapter 实例按服务实例缓存，
/// 避免重复探测。所有操作经 adapter，公共 API 保持稳定，调用方无需迁移。
class QBitService extends DownloaderService {
  final http.Client _client;

  // facade 缓存：探测后的 profile 与按代际选择的 adapter
  QBitSession? _session;
  QBitServerProfile? _profile;
  QBitApiAdapter? _adapter;

  QBitService(super.downloader, {http.Client? client})
      : _client = client ?? http.Client();

  QBitSession get _resolvedSession =>
      _session ??= QBitSession(downloader, client: _client);

  /// 解析（并缓存）版本 adapter。首次调用触发一次探测，后续复用。
  Future<QBitApiAdapter> _resolveAdapter() async {
    if (_adapter != null) {
      return _adapter!;
    }
    _profile ??= await QBitVersionDetector(_resolvedSession).detect();
    _adapter = switch (_profile!.apiGeneration) {
      QBitApiGeneration.v4Legacy => QBitV4Adapter(_resolvedSession),
      QBitApiGeneration.v5Modern => QBitV5Adapter(_resolvedSession),
    };
    return _adapter!;
  }

  @override
  Future<ConnectionResult> testConnection() async {
    try {
      _profile ??= await QBitVersionDetector(_resolvedSession).detect();
      return ConnectionSuccess(serverVersion: _profile!.appVersion);
    } on UnsupportedError {
      // 版本低于 4.1：detect 已登录，复用会话重新读取原始版本号
      final rawVersion = await _resolvedSession.getText('/api/v2/app/version');
      final cleanVersion =
          rawVersion.trim().replaceFirst(RegExp(r'^[^0-9]+'), '');
      return ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        'qBittorrent 版本过低，需 4.1+',
        actualVersion: cleanVersion,
        minVersion: '4.1',
      );
    } on DownloaderServiceException catch (e) {
      final category = switch (e.category) {
        DownloaderServiceErrorCategory.auth =>
          ConnectionFailureCategory.authFailed,
        DownloaderServiceErrorCategory.network =>
          ConnectionFailureCategory.networkError,
        _ => ConnectionFailureCategory.unknown,
      };
      return ConnectionFailure(category, e.message);
    } on FormatException catch (e) {
      return ConnectionFailure(ConnectionFailureCategory.unknown, e.message);
    }
  }

  @override
  Future<List<DownloadTask>> getTasks() async =>
      (await _resolveAdapter()).getTasks();

  @override
  Future<Map<String, dynamic>> getGlobalStat() async =>
      (await _resolveAdapter()).getGlobalStat();

  /// 从 `/api/v2/sync/maindata` 获取实时全量/增量快照。
  Future<QBitRealtimeSnapshot> getRealtimeSnapshot({required int rid}) async =>
      (await _resolveAdapter()).getRealtimeSnapshot(rid: rid);

  /// 从 `/api/v2/sync/maindata` 获取原始 JSON（供全局轮询精确 merge）。
  Future<Map<String, dynamic>> getRealtimeMainData({required int rid}) async =>
      (await _resolveAdapter()).getRealtimeMainData(rid: rid);

  @override
  Future<String> addTask(AddTaskRequest request) async =>
      (await _resolveAdapter()).addTask(request);

  @override
  Future<String> addDownload(String url, {String? savePath}) async =>
      (await _resolveAdapter()).addDownload(url, savePath: savePath);

  Future<String> getDefaultSavePath() async =>
      (await _resolveAdapter()).getDefaultSavePath();

  @override
  Future<void> pauseTask(String taskId) async =>
      (await _resolveAdapter()).pauseTask(taskId);

  @override
  Future<void> resumeTask(String taskId) async =>
      (await _resolveAdapter()).resumeTask(taskId);

  @override
  Future<void> removeTask(String taskId, {bool deleteFiles = false}) async =>
      (await _resolveAdapter()).removeTask(taskId, deleteFiles: deleteFiles);

  @override
  Future<DownloaderSpeedConfig> getSpeedConfig() async =>
      (await _resolveAdapter()).getSpeedConfig();

  @override
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config) async =>
      (await _resolveAdapter()).setSpeedConfig(config);

  @override
  Future<DownloadTask?> getTaskDetail(String taskId) async =>
      (await _resolveAdapter()).getTaskDetail(taskId);

  /// qBit 详情主页读模型（合并 info/properties/trackers/webseeds）。
  Future<QBitTaskDetail?> getTaskFullDetail(String taskId) async =>
      (await _resolveAdapter()).getTaskFullDetail(taskId);

  /// 从 /sync/maindata 获取指定任务的动态数据增量。
  Future<(int rid, Map<String, dynamic>?)> getTaskSyncUpdate(
          String taskId, int rid) async =>
      (await _resolveAdapter()).getTaskSyncUpdate(taskId, rid);

  /// qBit 文件页只读树。
  Future<List<QBitTaskFileNode>> getTaskFiles(String taskId) async =>
      (await _resolveAdapter()).getTaskFiles(taskId);

  /// qBit 节点页来源卡片（伪 tracker）。
  Future<List<QBitTaskSource>> getTaskSources(String taskId) async =>
      (await _resolveAdapter()).getTaskSources(taskId);

  /// qBit 节点页对端行。
  Future<List<QBitTaskPeer>> getTaskPeers(String taskId) async =>
      (await _resolveAdapter()).getTaskPeers(taskId);

  /// qBit 选项页读模型。
  Future<QBitTaskOptions> getTaskOptions(String taskId) async =>
      (await _resolveAdapter()).getTaskOptions(taskId);

  /// qBit 选项页差异写（队列动作 / 分类 / 标签）。
  Future<void> updateTaskOptions(
    String taskId, {
    required QBitTaskOptions current,
    required QBitTaskOptionsUpdate update,
  }) async =>
      (await _resolveAdapter()).updateTaskOptions(
        taskId,
        current: current,
        update: update,
      );

  @override
  SpeedConfigDescriptor getSpeedConfigDescriptor() {
    return const SpeedConfigDescriptor(
      sections: [
        ConfigSection(
          title: '速度限制模式',
          fields: [
            ConfigField(
                key: 'speedLimitModeEnabled',
                label: '速度限制模式',
                type: ConfigFieldType.toggle),
          ],
        ),
        ConfigSection(
          title: '正常限速',
          fields: [
            ConfigField(
                key: 'downloadLimitKB',
                label: '下载限速',
                type: ConfigFieldType.kbps),
            ConfigField(
                key: 'uploadLimitKB',
                label: '上传限速',
                type: ConfigFieldType.kbps),
          ],
        ),
        ConfigSection(
          title: '备用限速',
          description: '速度限制模式启用时使用此速度配置',
          enabledBy: 'speedLimitModeEnabled',
          fields: [
            ConfigField(
                key: 'altDownloadLimitKB',
                label: '下载限速',
                type: ConfigFieldType.kbps),
            ConfigField(
                key: 'altUploadLimitKB',
                label: '上传限速',
                type: ConfigFieldType.kbps),
          ],
        ),
      ],
    );
  }
}
