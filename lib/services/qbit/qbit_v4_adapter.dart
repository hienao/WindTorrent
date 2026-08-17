import 'package:windwalker/services/qbit/qbit_base_api_adapter.dart';

/// qBittorrent 4.1–4.6.x adapter。
///
/// 暂停/恢复使用 legacy 的 pause/resume 端点。
class QBitV4Adapter extends QBitBaseApiAdapter {
  QBitV4Adapter(super.session);

  @override
  Future<void> pauseTask(String taskId) =>
      postTaskAction('/api/v2/torrents/pause', taskId);

  @override
  Future<void> resumeTask(String taskId) =>
      postTaskAction('/api/v2/torrents/resume', taskId);
}
