import 'package:flutter/foundation.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

typedef Aria2ServiceFactory = Aria2Service Function(Downloader downloader);

/// Aria2 服务器/Tracker 子页面控制器。
///
/// 从 `aria2.tellStatus` 的 `bittorrent.announceList` 获取 Tracker 列表。
class Aria2TaskServersController extends ChangeNotifier {
  Aria2TaskServersController({Aria2ServiceFactory? serviceFactory})
      : _serviceFactory =
            serviceFactory ?? ((downloader) => Aria2Service(downloader));

  final Aria2ServiceFactory _serviceFactory;

  List<String> _trackers = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<String> get trackers => _trackers;
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
      _trackers = await _serviceFactory(downloader).getTaskTrackers(taskId);
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
