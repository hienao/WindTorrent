import 'package:flutter/foundation.dart';
import 'package:windwalker/models/aria2/aria2_task_file_node.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

typedef Aria2ServiceFactory = Aria2Service Function(Downloader downloader);

/// Aria2 文件子页面控制器。
///
/// 管理文件树加载态与目录展开状态，与 [QBitTaskFilesController] 同构。
class Aria2TaskFilesController extends ChangeNotifier {
  Aria2TaskFilesController({Aria2ServiceFactory? serviceFactory})
      : _serviceFactory =
            serviceFactory ?? ((downloader) => Aria2Service(downloader));

  final Aria2ServiceFactory _serviceFactory;
  final Set<String> _expandedPaths = <String>{};

  List<Aria2TaskFileNode> _files = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Aria2TaskFileNode> get files => _files;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool isExpanded(String path) => _expandedPaths.contains(path);

  /// 加载文件树。
  ///
  /// [taskName] 用作根目录节点名称，使单目录任务也能展示为可展开的树。
  Future<void> load({
    required String taskId,
    required Downloader downloader,
    String? taskName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final service = _serviceFactory(downloader);
      final rawFiles = await service.getTaskFilesRaw(taskId);
      _files = Aria2TaskFileNode.buildTree(rawFiles, taskName: taskName);
      // 根目录默认展开
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

  /// 切换目录展开/折叠。
  void toggleExpanded(String path) {
    if (!_expandedPaths.add(path)) {
      _expandedPaths.remove(path);
    }
    notifyListeners();
  }
}
