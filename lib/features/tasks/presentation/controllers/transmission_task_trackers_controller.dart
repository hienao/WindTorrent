import 'package:flutter/foundation.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_tracker.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/transmission_service.dart';

typedef TransmissionServiceFactory = TransmissionService Function(
  Downloader downloader,
);

/// Transmission 任务 Tracker 列表控制器。
///
/// 负责加载并持有当前任务的 tracker 列表，暴露 loading / error / data 三态。
class TransmissionTaskTrackersController extends ChangeNotifier {
  TransmissionTaskTrackersController({
    TransmissionServiceFactory? serviceFactory,
  }) : _serviceFactory =
            serviceFactory ?? ((downloader) => TransmissionService(downloader));

  final TransmissionServiceFactory _serviceFactory;

  List<TransmissionTaskTracker> _trackers = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TransmissionTaskTracker> get trackers => _trackers;
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

  void clear() {
    _trackers = const [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
