import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/backup/data/backup_storage_api.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/models/downloader_backup_version.dart';
import 'package:windwalker/services/downloader_backup_service.dart';

class _FakeStorageApi implements BackupStorageApi {
  _FakeStorageApi({
    this.versionsToReturn = const <DownloaderBackupVersion>[],
    this.downloadedBytes = const <int>[],
    this.uploadError,
  });

  final List<DownloaderBackupVersion> versionsToReturn;
  final List<int> downloadedBytes;
  final Object? uploadError;

  DownloaderBackupBundle? uploadedBundle;
  final List<String> deletedIds = <String>[];

  @override
  Future<void> testConnection() async {}

  @override
  Future<List<DownloaderBackupVersion>> listVersions() async =>
      versionsToReturn;

  @override
  Future<void> uploadBackup(DownloaderBackupBundle bundle) async {
    if (uploadError != null) throw uploadError!;
    uploadedBundle = bundle;
  }

  @override
  Future<List<int>> downloadBackup(String fileId) async => downloadedBytes;

  @override
  Future<void> deleteBackup(String fileId) async {
    deletedIds.add(fileId);
  }
}

Downloader _downloader({String id = 'd1', String name = 'Test'}) {
  return Downloader(
    id: id,
    name: name,
    type: DownloaderType.aria2,
    host: 'localhost',
    port: 6800,
  );
}

DownloaderBackupService _buildService({
  required DownloaderController controller,
  required BackupStorageApi storageApi,
}) {
  return DownloaderBackupService(
    storageApi: storageApi,
    downloaderController: controller,
    currentAppVersion: () async => '1.1.1',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return '/tmp/test_windwalker';
            }
            if (methodCall.method == 'getApplicationSupportDirectory') {
              return '/tmp/test_windwalker';
            }
            return null;
          },
        );
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().remove('downloaders');
    await GetStorage().remove('downloaders_import_rollback_snapshot');
  });

  group('DownloaderBackupService', () {
    test(
      'exportBackup uploads bundle and deletes versions beyond newest two',
      () async {
        final controller = DownloaderController();
        controller.setTestDownloadersForTest(<Downloader>[_downloader()]);
        final storageApi = _FakeStorageApi(
          versionsToReturn: <DownloaderBackupVersion>[
            DownloaderBackupVersion(
              fileId: 'oldest',
              fileName: 'oldest.json',
              backupId: 'b1',
              createdAt: DateTime.parse('2026-07-01T00:00:00Z'),
              appVersion: '1.0.0',
              downloaderCount: 1,
              isLatest: false,
            ),
            DownloaderBackupVersion(
              fileId: 'old',
              fileName: 'old.json',
              backupId: 'b2',
              createdAt: DateTime.parse('2026-07-02T00:00:00Z'),
              appVersion: '1.0.0',
              downloaderCount: 1,
              isLatest: false,
            ),
            DownloaderBackupVersion(
              fileId: 'new',
              fileName: 'new.json',
              backupId: 'b3',
              createdAt: DateTime.parse('2026-07-03T00:00:00Z'),
              appVersion: '1.0.0',
              downloaderCount: 1,
              isLatest: true,
            ),
          ],
        );

        final service = _buildService(
          controller: controller,
          storageApi: storageApi,
        );
        await service.exportBackup();

        expect(storageApi.uploadedBundle, isNotNull);
        expect(storageApi.uploadedBundle!.downloaders.single.id, 'd1');
        expect(storageApi.deletedIds, <String>['oldest']);
      },
    );

    test('exportBackup keeps old versions when upload fails', () async {
      final controller = DownloaderController();
      controller.setTestDownloadersForTest(<Downloader>[_downloader()]);
      final storageApi = _FakeStorageApi(
        versionsToReturn: <DownloaderBackupVersion>[
          DownloaderBackupVersion(
            fileId: 'old',
            fileName: 'old.json',
            backupId: 'b1',
            createdAt: DateTime.parse('2026-07-01T00:00:00Z'),
            appVersion: '1.0.0',
            downloaderCount: 1,
            isLatest: true,
          ),
        ],
        uploadError: Exception('upload failed'),
      );

      final service = _buildService(
        controller: controller,
        storageApi: storageApi,
      );

      expect(() => service.exportBackup(), throwsException);
      expect(storageApi.deletedIds, isEmpty);
    });

    test('restoreBackup replaces controller downloaders', () async {
      final controller = DownloaderController();
      controller.setTestDownloadersForTest(<Downloader>[
        _downloader(id: 'old'),
      ]);
      final bundle = DownloaderBackupBundle(
        schemaVersion: DownloaderBackupBundle.supportedSchemaVersion,
        backupId: 'backup-1',
        createdAt: DateTime.parse('2026-07-04T10:00:00Z'),
        appVersion: '1.1.1',
        downloaders: <Downloader>[_downloader(id: 'new')],
      );
      final storageApi = _FakeStorageApi(
        downloadedBytes: utf8.encode(jsonEncode(bundle.toJson())),
      );

      final service = _buildService(
        controller: controller,
        storageApi: storageApi,
      );
      await service.restoreBackup(fileId: 'file-1');

      expect(controller.downloaders.single.id, 'new');
    });

    test('pickFilesToDeleteBeforeUpload keeps newest two versions', () {
      final result = DownloaderBackupService.pickFilesToDeleteBeforeUpload(
        <DownloaderBackupVersion>[
          DownloaderBackupVersion(
            fileId: '1',
            fileName: '1.json',
            backupId: 'b1',
            createdAt: DateTime.parse('2026-07-01T00:00:00Z'),
            appVersion: '1.0.0',
            downloaderCount: 1,
            isLatest: false,
          ),
          DownloaderBackupVersion(
            fileId: '2',
            fileName: '2.json',
            backupId: 'b2',
            createdAt: DateTime.parse('2026-07-02T00:00:00Z'),
            appVersion: '1.0.0',
            downloaderCount: 1,
            isLatest: false,
          ),
          DownloaderBackupVersion(
            fileId: '3',
            fileName: '3.json',
            backupId: 'b3',
            createdAt: DateTime.parse('2026-07-03T00:00:00Z'),
            appVersion: '1.0.0',
            downloaderCount: 1,
            isLatest: true,
          ),
        ],
      );

      expect(result.map((version) => version.fileId), <String>['1']);
    });
  });
}
