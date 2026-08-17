import 'package:flutter/material.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_detail_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_task_peer.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit_service.dart';

/// qBit 节点(对端)子页面控制器。
///
/// 管理对端行加载态（loading / peers / error）。
/// 复用 [QBitServiceFactory] 注入点。
class QBitTaskPeersController extends ChangeNotifier {
  QBitTaskPeersController({QBitServiceFactory? serviceFactory})
      : _serviceFactory =
            serviceFactory ?? ((downloader) => QBitService(downloader));

  final QBitServiceFactory _serviceFactory;
  List<QBitTaskPeer> _peers = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<QBitTaskPeer> get peers => _peers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 加载对端列表。
  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _peers = await _serviceFactory(downloader).getTaskPeers(taskId);
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
