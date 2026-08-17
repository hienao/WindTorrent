import 'package:flutter/material.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_detail_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_task_file_node.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit_service.dart';

/// qBit 文件子页面控制器。
///
/// 管理文件树加载态（loading / files / error）与目录展开状态。
/// 复用 [QBitServiceFactory] 注入点（与 [QBitTaskDetailController] 同一约定）。
class QBitTaskFilesController extends ChangeNotifier {
  QBitTaskFilesController({QBitServiceFactory? serviceFactory})
      : _serviceFactory =
            serviceFactory ?? ((downloader) => QBitService(downloader));

  final QBitServiceFactory _serviceFactory;
  final Set<String> _expandedPaths = <String>{};
  List<QBitTaskFileNode> _files = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<QBitTaskFileNode> get files => _files;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool isExpanded(String path) => _expandedPaths.contains(path);

  /// 加载文件树。
  ///
  /// 与 Transmission 文件页不同，qBit 文件树默认全部折叠（顶层目录亦然），
  /// 让用户按需展开——qBit 任务常含大量顶层文件，默认展开会刷屏。此为有意决定。
  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _files = await _serviceFactory(downloader).getTaskFiles(taskId);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 切换目录展开/折叠。
  void toggleExpanded(String path) {
    if (!_expandedPaths.add(path)) {
      _expandedPaths.remove(path);
    }
    notifyListeners();
  }
}
