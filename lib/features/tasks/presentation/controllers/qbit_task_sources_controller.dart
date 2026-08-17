import 'package:flutter/material.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_detail_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_task_source.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit_service.dart';

/// qBit 服务器(来源)子页面控制器。
///
/// 管理来源卡片（DHT/PeX/LSD 等伪 tracker）加载态（loading / sources / error）。
/// 复用 [QBitServiceFactory] 注入点。
class QBitTaskSourcesController extends ChangeNotifier {
  QBitTaskSourcesController({QBitServiceFactory? serviceFactory})
      : _serviceFactory =
            serviceFactory ?? ((downloader) => QBitService(downloader));

  final QBitServiceFactory _serviceFactory;
  List<QBitTaskSource> _sources = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<QBitTaskSource> get sources => _sources;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 加载来源列表。
  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sources = await _serviceFactory(downloader).getTaskSources(taskId);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
