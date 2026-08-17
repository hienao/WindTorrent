import 'package:http/http.dart' as http;
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/models/speed_config_descriptor.dart';
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
import 'package:windwalker/services/base_downloader_service.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/transmission/transmission_legacy_rpc_adapter.dart';
import 'package:windwalker/services/transmission/transmission_modern_rpc_adapter.dart';
import 'package:windwalker/services/transmission/transmission_protocol_detector.dart';
import 'package:windwalker/services/transmission/transmission_protocol_info.dart';
import 'package:windwalker/services/transmission/transmission_rpc_adapter.dart';

/// Transmission 下载器服务（facade）。
///
/// 自动识别服务器协议（modern / legacy），缓存 adapter，
/// 将所有业务调用委托给对应协议的 `TransmissionRpcAdapter` 实现。
///
/// 对外仍然暴露统一的 `DownloaderService` 接口，
/// controller 和 UI 不感知协议分叉。
class TransmissionService extends DownloaderService {
  TransmissionService(super.downloader, {http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  TransmissionRpcAdapter? _adapter;
  bool _didRetryDetection = false;

  /// 获取已缓存的 adapter，首次使用时通过 detector 完成协议识别。
  Future<TransmissionRpcAdapter> _getAdapter() async {
    if (_adapter != null) return _adapter!;

    final detection =
        await TransmissionProtocolDetector(downloader, client: _client)
            .detect();

    if (!detection.isSuccess) {
      final category =
          detection.failureCategory == TransmissionDetectionFailure.authFailed
              ? DownloaderServiceErrorCategory.auth
              : DownloaderServiceErrorCategory.protocol;
      throw DownloaderServiceException(
        'Transmission 协议识别失败: ${detection.failureCategory}',
        category: category,
      );
    }

    _adapter = switch (detection.protocol) {
      TransmissionProtocol.modern => TransmissionModernRpcAdapter(
          downloader: downloader,
          client: _client,
          protocolInfo: detection.info!,
        ),
      TransmissionProtocol.legacy => TransmissionLegacyRpcAdapter(
          downloader: downloader,
          client: _client,
          protocolInfo: detection.info!,
        ),
    };

    return _adapter!;
  }

  // ─── DownloaderService 接口（委托给 adapter）──────────────────

  @override
  Future<ConnectionResult> testConnection() async {
    try {
      final adapter = await _getAdapter();
      final result = await adapter.testConnection();

      // 若 adapter 返回失败且尚未重探测过，清除缓存重试一次
      if (result is ConnectionFailure && _shouldRetryDetection(result)) {
        _adapter = null;
        _didRetryDetection = true;
        final retriedAdapter = await _getAdapter();
        return retriedAdapter.testConnection();
      }
      return result;
    } on DownloaderServiceException catch (e) {
      // _getAdapter 阶段的协议识别失败 → 映射为 ConnectionFailure
      if (e.category == DownloaderServiceErrorCategory.auth) {
        return const ConnectionFailure(
          ConnectionFailureCategory.authFailed,
          'Transmission 用户名/密码错误',
        );
      }
      return const ConnectionFailure(
        ConnectionFailureCategory.networkError,
        '无法连接 Transmission',
      );
    } catch (e) {
      Log.e('Transmission testConnection error', error: e);
      return const ConnectionFailure(
        ConnectionFailureCategory.networkError,
        '无法连接 Transmission',
      );
    }
  }

  bool _shouldRetryDetection(ConnectionResult result) =>
      !_didRetryDetection &&
      result is ConnectionFailure &&
      result.category == ConnectionFailureCategory.unknown;

  @override
  Future<List<DownloadTask>> getTasks() async {
    final adapter = await _getAdapter();
    return adapter.getTasks();
  }

  @override
  Future<DownloadTask?> getTaskDetail(String taskId) async {
    final adapter = await _getAdapter();
    return adapter.getTaskDetail(taskId);
  }

  /// Transmission 专属：加载单任务完整详情（文件/服务器/节点/选项所需字段）。
  ///
  /// 非 `DownloaderService` 接口方法，仅 Transmission 详情页使用。
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async {
    final adapter = await _getAdapter();
    return adapter.getTaskFullDetail(taskId);
  }

  /// Transmission 专属：一次 `torrent-get` 获取全量实时快照。
  ///
  /// 供全局轮询 `RealtimeSyncController` 使用，modern/legacy 自动适配字段命名。
  Future<TransmissionRealtimeSnapshot> getRealtimeSnapshot() async {
    final adapter = await _getAdapter();
    return adapter.getRealtimeSnapshot();
  }

  // ─── 子页面数据方法（Transmission 专属）──────────────────────

  Future<List<TransmissionTaskFileNode>> getTaskFiles(String taskId) async {
    final adapter = await _getAdapter();
    return adapter.getTaskFiles(taskId);
  }

  Future<List<TransmissionTaskTracker>> getTaskTrackers(String taskId) async {
    final adapter = await _getAdapter();
    return adapter.getTaskTrackers(taskId);
  }

  Future<List<TransmissionTaskPeer>> getTaskPeers(String taskId) async {
    final adapter = await _getAdapter();
    return adapter.getTaskPeers(taskId);
  }

  Future<TransmissionTaskOptions> getTaskOptions(String taskId) async {
    final adapter = await _getAdapter();
    return adapter.getTaskOptions(taskId);
  }

  Future<void> updateTaskOptions(
    String taskId,
    TransmissionTaskOptionsUpdate update,
  ) async {
    final adapter = await _getAdapter();
    return adapter.updateTaskOptions(taskId, update);
  }

  @override
  Future<Map<String, dynamic>> getGlobalStat() async {
    final adapter = await _getAdapter();
    return adapter.getGlobalStat();
  }

  @override
  Future<String> addTask(AddTaskRequest request) async {
    final adapter = await _getAdapter();
    return adapter.addTask(request);
  }

  @override
  Future<String> addDownload(String url, {String? savePath}) async {
    final adapter = await _getAdapter();
    return adapter.addTask(
      AddTaskRequest(
        downloaderId: downloader.id,
        url: url,
        savePath: savePath,
      ),
    );
  }

  @override
  Future<void> pauseTask(String taskId) async {
    final adapter = await _getAdapter();
    return adapter.pauseTask(taskId);
  }

  @override
  Future<void> resumeTask(String taskId) async {
    final adapter = await _getAdapter();
    return adapter.resumeTask(taskId);
  }

  @override
  Future<void> removeTask(String taskId, {bool deleteFiles = false}) async {
    final adapter = await _getAdapter();
    return adapter.removeTask(taskId, deleteFiles: deleteFiles);
  }

  @override
  Future<DownloaderSpeedConfig> getSpeedConfig() async {
    final adapter = await _getAdapter();
    return adapter.getSpeedConfig();
  }

  @override
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config) async {
    final adapter = await _getAdapter();
    return adapter.setSpeedConfig(config);
  }

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
              type: ConfigFieldType.toggle,
            ),
          ],
        ),
        ConfigSection(
          title: '正常限速',
          fields: [
            ConfigField(
              key: 'downloadLimitKB',
              label: '下载限速',
              type: ConfigFieldType.kbps,
            ),
            ConfigField(
              key: 'uploadLimitKB',
              label: '上传限速',
              type: ConfigFieldType.kbps,
            ),
          ],
        ),
        ConfigSection(
          title: '备用限速 (Turtle Mode)',
          description: '速度限制模式启用时使用此速度配置',
          enabledBy: 'speedLimitModeEnabled',
          fields: [
            ConfigField(
              key: 'altDownloadLimitKB',
              label: '下载限速',
              type: ConfigFieldType.kbps,
            ),
            ConfigField(
              key: 'altUploadLimitKB',
              label: '上传限速',
              type: ConfigFieldType.kbps,
            ),
          ],
        ),
      ],
    );
  }
}
