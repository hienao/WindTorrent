import 'package:flutter/material.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_task_detail.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit_service.dart';

/// 创建 QBitService 实例的工厂签名。
///
/// 默认按 [Downloader] 构造真实服务；测试可注入 fake 实现（见 FakeQBitService）。
typedef QBitServiceFactory = QBitService Function(Downloader downloader);

/// qBit 任务信息主页控制器。
///
/// 仅负责 qBit 详情主页的「完整详情」加载态（loading / detail / error），
/// 与跨下载器共享的 [TaskController] 互不干扰。
///
/// 错误传播：service fail-fast 抛异常 → 此处捕获并写入 errorState 供 UI 显示，
/// 与 [TaskController] 同一职责（controller 层翻译，避免异常冒泡崩 UI）。
class QBitTaskDetailController extends ChangeNotifier {
  QBitTaskDetailController({
    QBitServiceFactory? serviceFactory,
  }) : _serviceFactory =
            serviceFactory ?? ((downloader) => QBitService(downloader));

  final QBitServiceFactory _serviceFactory;

  QBitTaskDetail? _detail;
  bool _isLoading = false;
  String? _errorMessage;
  int _syncRid = 0;

  QBitTaskDetail? get detail => _detail;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 初始加载：从 /torrents/properties 获取完整详情。
  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _detail = await _serviceFactory(downloader).getTaskFullDetail(taskId);
      _syncRid = 0;
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刷新：从 /sync/maindata 获取动态字段增量，合并到已有详情。
  ///
  /// 若详情未加载（_detail 为 null），退化为 [load]。
  Future<void> refresh({
    required String taskId,
    required Downloader downloader,
  }) async {
    if (_detail == null) {
      return load(taskId: taskId, downloader: downloader);
    }

    try {
      final service = _serviceFactory(downloader);
      final (newRid, torrentData) =
          await service.getTaskSyncUpdate(taskId, _syncRid);
      _syncRid = newRid;
      if (torrentData != null) {
        _detail = _detail!.applySyncUpdate(torrentData);
        notifyListeners();
      }
    } catch (e) {
      // 刷新失败静默降级，不覆盖已有数据（与 TaskController 一致）
    }
  }
}
