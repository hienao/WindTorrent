import 'package:flutter/foundation.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_file_node.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/transmission_service.dart';

typedef TransmissionServiceFactory = TransmissionService Function(
  Downloader downloader,
);

/// Transmission 任务文件树控制器。
///
/// 负责文件子页面的「文件列表」加载态（loading / files / error），
/// 与跨下载器共享的 [TaskController] 互不干扰。
///
/// 错误传播：service fail-fast 抛异常 → 此处捕获并写入 errorMessage 供 UI 显示。
class TransmissionTaskFilesController extends ChangeNotifier {
  TransmissionTaskFilesController({
    TransmissionServiceFactory? serviceFactory,
  }) : _serviceFactory =
            serviceFactory ?? ((downloader) => TransmissionService(downloader));

  final TransmissionServiceFactory _serviceFactory;

  List<TransmissionTaskFileNode> _files = const [];
  final Set<String> _expandedPaths = <String>{};
  bool _isLoading = false;
  String? _errorMessage;

  List<TransmissionTaskFileNode> get files => _files;
  Set<String> get expandedPaths => _expandedPaths;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 加载指定任务的文件树。
  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _files = await _serviceFactory(downloader).getTaskFiles(taskId);
      // 默认展开第一层目录
      _expandedPaths.clear();
      for (final node in _files) {
        if (node.isDirectory) {
          _expandedPaths.add(node.path);
        }
      }
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 展开/折叠指定路径的目录节点。
  void toggleExpanded(String path) {
    if (_expandedPaths.contains(path)) {
      _expandedPaths.remove(path);
    } else {
      _expandedPaths.add(path);
    }
    notifyListeners();
  }

  /// 清空当前文件态（离开页面时调用）。
  void clear() {
    _files = const [];
    _expandedPaths.clear();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
