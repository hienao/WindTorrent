import 'package:windwalker/services/qbit/qbit_base_api_adapter.dart';

/// qBittorrent 5.0+ adapter。
///
/// 暂停/恢复使用 modern 的 stop/start 端点。
class QBitV5Adapter extends QBitBaseApiAdapter {
  QBitV5Adapter(super.session);

  @override
  Future<void> pauseTask(String taskId) =>
      postTaskAction('/api/v2/torrents/stop', taskId);

  @override
  Future<void> resumeTask(String taskId) =>
      postTaskAction('/api/v2/torrents/start', taskId);
}
