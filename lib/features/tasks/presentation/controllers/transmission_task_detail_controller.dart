import 'package:flutter/foundation.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_detail.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/transmission_service.dart';

/// 创建 TransmissionService 实例的工厂签名。
///
/// 默认按 [Downloader] 构造真实服务；测试可注入 fake 实现。
typedef TransmissionServiceFactory = TransmissionService Function(
  Downloader downloader,
);

/// Transmission 任务完整详情控制器。
///
/// 仅负责 Transmission 详情页的「完整详情」加载态（loading / detail / error），
/// 与跨下载器共享的 [TaskController] 互不干扰。
///
/// 错误传播：service fail-fast 抛异常 → 此处捕获并写入 errorState 供 UI 显示，
/// 与 [TaskController._setError] 同一职责（controller 层翻译，避免异常冒泡崩 UI）。
class TransmissionTaskDetailController extends ChangeNotifier {
  TransmissionTaskDetailController({
    TransmissionServiceFactory? serviceFactory,
  }) : _serviceFactory =
            serviceFactory ?? ((downloader) => TransmissionService(downloader));

  final TransmissionServiceFactory _serviceFactory;

  TransmissionTaskDetail? _detail;
  bool _isLoading = false;
  String? _errorMessage;

  TransmissionTaskDetail? get detail => _detail;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 加载指定任务的完整详情。
  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _detail = await _serviceFactory(downloader).getTaskFullDetail(taskId);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清空当前详情态（离开页面或切换任务时调用）。
  void clear() {
    _detail = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
