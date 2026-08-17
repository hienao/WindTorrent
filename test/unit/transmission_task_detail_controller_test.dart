import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_detail_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_detail.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/transmission_service.dart';

void main() {
  Downloader trans() => Downloader(
        id: 'trans-1',
        name: 'Transmission',
        type: DownloaderType.transmission,
        host: 'localhost',
        port: 9091,
      );

  test('load stores detail on success', () async {
    const fakeDetail = TransmissionTaskDetail(
      taskId: '7',
      name: 'demo.iso',
      downloaderId: 'trans-1',
      totalSize: 1000,
      pieceCount: 20,
      pieceSize: 50,
      savePath: '/downloads',
      isPrivate: true,
      creator: 'Transmission',
      createdAt: null,
      magnet: 'magnet:?xt=urn:btih:abc',
      availablePercent: 1,
      downloadedEver: 1000,
      uploadedEver: 100,
      ratio: 0.1,
      averageSpeed: 10,
      addedAt: null,
      completedAt: null,
      lastActivityAt: null,
      downloadDuration: Duration.zero,
      seedingDuration: Duration.zero,
      fileCount: 1,
      trackerCount: 1,
      peerCount: 1,
      optionsEditable: true,
    );
    final controller = TransmissionTaskDetailController(
      serviceFactory: (_) => FakeTransmissionService.success(fakeDetail),
    );

    await controller.load(taskId: '7', downloader: trans());

    expect(controller.detail, fakeDetail);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('load exposes error message on failure', () async {
    final controller = TransmissionTaskDetailController(
      serviceFactory: (_) => FakeTransmissionService.failure(
        DownloaderServiceException('boom'),
      ),
    );

    await controller.load(taskId: '7', downloader: trans());

    expect(controller.detail, isNull);
    expect(controller.errorMessage, 'boom');
  });
}

class FakeTransmissionService extends TransmissionService {
  FakeTransmissionService.success(this._detail)
      : _error = null,
        super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  FakeTransmissionService.failure(this._error)
      : _detail = null,
        super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  final TransmissionTaskDetail? _detail;
  final Object? _error;

  @override
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async {
    if (_error != null) throw _error;
    return _detail!;
  }
}
