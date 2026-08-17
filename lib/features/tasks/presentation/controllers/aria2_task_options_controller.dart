import 'package:flutter/foundation.dart';
import 'package:windwalker/models/aria2/aria2_task_options.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

typedef Aria2ServiceFactory = Aria2Service Function(Downloader downloader);

/// Aria2 选项子页面控制器。
class Aria2TaskOptionsController extends ChangeNotifier {
  Aria2TaskOptionsController({Aria2ServiceFactory? serviceFactory})
      : _serviceFactory =
            serviceFactory ?? ((downloader) => Aria2Service(downloader));

  final Aria2ServiceFactory _serviceFactory;

  Aria2TaskOptions? _options;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  Aria2TaskOptions? get options => _options;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _options = await _serviceFactory(downloader).getTaskOptions(taskId);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save({
    required String taskId,
    required Downloader downloader,
    required Map<String, String> options,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _serviceFactory(downloader).updateTaskOptions(taskId, options);
      _isSaving = false;
      // 重新加载以获取最新状态
      await load(taskId: taskId, downloader: downloader);
      return true;
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
      _isSaving = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
