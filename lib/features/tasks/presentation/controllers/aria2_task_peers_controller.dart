import 'package:flutter/foundation.dart';
import 'package:windwalker/models/aria2/aria2_task_peer.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

typedef Aria2ServiceFactory = Aria2Service Function(Downloader downloader);

/// Aria2 节点子页面控制器。
class Aria2TaskPeersController extends ChangeNotifier {
  Aria2TaskPeersController({Aria2ServiceFactory? serviceFactory})
      : _serviceFactory =
            serviceFactory ?? ((downloader) => Aria2Service(downloader));

  final Aria2ServiceFactory _serviceFactory;

  List<Aria2TaskPeer> _peers = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Aria2TaskPeer> get peers => _peers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
