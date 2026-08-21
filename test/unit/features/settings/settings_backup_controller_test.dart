import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/backup/data/backup_file_api.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_backup_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/downloader_backup_service.dart';

class _FakeBackupFileApi implements BackupFileApi {
  PickedBackupFile? pickedFile;
  bool saveResult = true;

  @override
  Future<PickedBackupFile?> pickBackup() async => pickedFile;

  @override
  Future<bool> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) async => saveResult;
}

SettingsBackupController _buildController({
  required _FakeBackupFileApi fileApi,
  required DownloaderController downloaderController,
}) {
  final controller = SettingsBackupController();
  controller.attach(
    backupService: DownloaderBackupService(
      fileApi: fileApi,
      downloaderController: downloaderController,
      currentAppVersion: () async => '1.1.4',
    ),
    downloaderController: downloaderController,
  );
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => '/tmp/test_windwalker',
        );
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
  });

  test('successful export exposes a completion summary', () async {
    final controller = _buildController(
      fileApi: _FakeBackupFileApi(),
      downloaderController: DownloaderController(),
    );

    await controller.exportBackup();

    expect(controller.errorMessage, isNull);
    expect(controller.lastOperationSummary, contains('已导出'));
  });

  test(
    'invalid file exposes a clear error and preserves configurations',
    () async {
      final downloaderController = DownloaderController()
        ..setTestDownloadersForTest(<Downloader>[
          Downloader(
            id: 'old',
            name: 'Existing',
            type: DownloaderType.aria2,
            host: 'localhost',
            port: 6800,
          ),
        ]);
      final fileApi = _FakeBackupFileApi()
        ..pickedFile = PickedBackupFile(
          fileName: 'invalid.json',
          bytes: Uint8List.fromList(utf8.encode('{bad-json')),
        );
      final controller = _buildController(
        fileApi: fileApi,
        downloaderController: downloaderController,
      );

      await controller.importBackup();

      expect(controller.errorMessage, contains('不是有效的'));
      expect(downloaderController.downloaders.single.id, 'old');
      expect(downloaderController.hasRollbackSnapshot, isFalse);
    },
  );
}
