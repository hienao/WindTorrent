import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_options.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_options_controller.dart';
import 'package:windwalker/services/transmission_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

Downloader trans() => Downloader(
      id: 'trans-1',
      name: 'Test',
      type: DownloaderType.transmission,
      host: 'localhost',
      port: 9091,
    );

const _defaultOptions = TransmissionTaskOptions(
  bandwidthPriority: 0,
  honorsSessionLimits: true,
  downloadLimited: true,
  downloadLimitKBps: 100,
  uploadLimited: true,
  uploadLimitKBps: 3000,
  seedRatioMode: TransmissionLimitMode.global,
  seedRatioLimit: 0,
  idleLimitMode: TransmissionLimitMode.global,
  idleLimitMinutes: 0,
);

class _FakeTransmissionService extends TransmissionService {
  _FakeTransmissionService({
    this.throwOnSave = false,
    this.throwOnLoad = false,
  }) : options = _defaultOptions, super(Downloader(
          id: 'trans-1',
          name: 'Test',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  final TransmissionTaskOptions options;
  final bool throwOnSave;
  final bool throwOnLoad;

  @override
  Future<TransmissionTaskOptions> getTaskOptions(String taskId) async {
    if (throwOnLoad) {
      throw DownloaderServiceException('load failed');
    }
    return options;
  }

  @override
  Future<void> updateTaskOptions(
    String taskId,
    dynamic update,
  ) async {
    if (throwOnSave) {
      throw DownloaderServiceException('save failed');
    }
  }
}

void main() {
  test('load populates draft from service', () async {
    final controller = TransmissionTaskOptionsController(
      serviceFactory: (_) => _FakeTransmissionService(),
    );

    await controller.load(taskId: '7', downloader: trans());

    expect(controller.draft, isNotNull);
    expect(controller.draft!.downloadLimitKBps, 100);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('updateDownloadLimit marks dirty', () async {
    final controller = TransmissionTaskOptionsController(
      serviceFactory: (_) => _FakeTransmissionService(),
    );

    await controller.load(taskId: '7', downloader: trans());
    expect(controller.isDirty, isFalse);

    controller.updateDownloadLimit('120');

    expect(controller.isDirty, isTrue);
    expect(controller.draft!.downloadLimitKBps, 120);
    expect(controller.draft!.downloadLimited, isTrue);
  });

  test('save clears dirty', () async {
    final controller = TransmissionTaskOptionsController(
      serviceFactory: (_) => _FakeTransmissionService(),
    );

    await controller.load(taskId: '7', downloader: trans());
    controller.updateDownloadLimit('120');
    expect(controller.isDirty, isTrue);

    await controller.save(taskId: '7', downloader: trans());

    expect(controller.isDirty, isFalse);
    expect(controller.isSaving, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('load error sets errorMessage', () async {
    final controller = TransmissionTaskOptionsController(
      serviceFactory: (_) => _FakeTransmissionService(throwOnLoad: true),
    );

    await controller.load(taskId: '7', downloader: trans());

    expect(controller.errorMessage, isNotNull);
    expect(controller.draft, isNull);
  });

  test('save error sets errorMessage', () async {
    final controller = TransmissionTaskOptionsController(
      serviceFactory: (_) => _FakeTransmissionService(throwOnSave: true),
    );

    await controller.load(taskId: '7', downloader: trans());
    controller.updateDownloadLimit('200');
    await controller.save(taskId: '7', downloader: trans());

    expect(controller.errorMessage, isNotNull);
    expect(controller.isSaving, isFalse);
  });
}
