import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/features/backup/data/backup_storage_api.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';
import 'package:windwalker/features/backup/data/webdav_config_store.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_backup_controller.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/models/downloader_backup_version.dart';
import 'package:windwalker/services/downloader_backup_service.dart';

class _FakeStorageApi implements BackupStorageApi {
  _FakeStorageApi({this.versions = const <DownloaderBackupVersion>[]});

  List<DownloaderBackupVersion> versions;

  final deletedIds = <String>[];

  @override
  Future<void> testConnection() async {}

  @override
  Future<List<DownloaderBackupVersion>> listVersions() async => versions;

  @override
  Future<void> uploadBackup(DownloaderBackupBundle bundle) async {}

  @override
  Future<List<int>> downloadBackup(String fileId) async => const <int>[];

  @override
  Future<void> deleteBackup(String fileId) async {
    deletedIds.add(fileId);
  }
}

SettingsBackupController _buildController({
  required _FakeStorageApi storageApi,
  DownloaderController? downloaderController,
  WebDavConfigStore? configStore,
}) {
  final controller = SettingsBackupController(
    configStore: configStore ?? WebDavConfigStore(storage: GetStorage()),
  );
  controller.attach(
    backupService: DownloaderBackupService(
      storageApi: storageApi,
      downloaderController: downloaderController ?? DownloaderController(),
      currentAppVersion: () async => '1.0.0',
    ),
    downloaderController: downloaderController ?? DownloaderController(),
  );
  return controller;
}

DownloaderBackupVersion _version({
  String fileId = 'file-1',
  String backupId = 'backup-1',
  bool isLatest = true,
}) {
  return DownloaderBackupVersion(
    fileId: fileId,
    fileName: '$backupId.json',
    backupId: backupId,
    createdAt: DateTime.parse('2026-07-04T12:00:00Z'),
    appVersion: '1.0.0',
    downloaderCount: 2,
    isLatest: isLatest,
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
    await GetStorage().erase();
  });

  group('SettingsBackupController', () {
    test('saveConfig persists WebDAV config and exposes summary', () async {
      final controller = _buildController(storageApi: _FakeStorageApi());

      await controller.saveConfig(
        const WebDavConfig(
          rootUrl: 'https://dav.example.com/root/',
          remoteDirectory: 'WindTorrent/Backups',
          username: 'alice',
          password: 'secret',
        ),
      );

      expect(controller.hasConfig, isTrue);
      expect(controller.configSummary, contains('alice'));
    });

    test('testConnection reports success summary', () async {
      final controller = _buildController(storageApi: _FakeStorageApi());

      await controller.testConnection(
        const WebDavConfig(
          rootUrl: 'https://dav.example.com/root/',
          remoteDirectory: 'WindTorrent/Backups',
          username: 'alice',
          password: 'secret',
        ),
      );

      expect(controller.errorMessage, isNull);
      expect(controller.lastOperationSummary, contains('WebDAV'));
    });

    test('exportBackup requires config before exporting', () async {
      final controller = _buildController(storageApi: _FakeStorageApi());

      await controller.exportBackup();

      expect(controller.errorMessage, contains('WebDAV'));
    });

    test('loadAvailableBackups populates remote versions', () async {
      final controller = _buildController(
        storageApi: _FakeStorageApi(
          versions: <DownloaderBackupVersion>[
            _version(fileId: 'f1', backupId: 'b1'),
            _version(fileId: 'f2', backupId: 'b2', isLatest: false),
          ],
        ),
      );
      await controller.saveConfig(
        const WebDavConfig(
          rootUrl: 'https://dav.example.com/root/',
          remoteDirectory: 'WindTorrent/Backups',
          username: 'alice',
          password: 'secret',
        ),
      );

      await controller.loadAvailableBackups();

      expect(controller.availableBackups, hasLength(2));
      expect(controller.availableBackups.first.fileId, 'f1');
    });

    test('deleteBackup removes version from local list', () async {
      final controller = _buildController(
        storageApi: _FakeStorageApi(
          versions: <DownloaderBackupVersion>[
            _version(fileId: 'f1'),
            _version(fileId: 'f2', backupId: 'b2', isLatest: false),
          ],
        ),
      );
      await controller.saveConfig(
        const WebDavConfig(
          rootUrl: 'https://dav.example.com/root/',
          remoteDirectory: 'WindTorrent/Backups',
          username: 'alice',
          password: 'secret',
        ),
      );
      await controller.loadAvailableBackups();

      await controller.deleteBackup(fileId: 'f1');

      expect(
        controller.availableBackups.map((backup) => backup.fileId),
        <String>['f2'],
      );
    });
  });
}
