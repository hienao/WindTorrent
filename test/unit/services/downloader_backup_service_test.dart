import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/backup/data/backup_exceptions.dart';
import 'package:windwalker/features/backup/data/backup_file_api.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/services/downloader_backup_service.dart';

class _FakeBackupFileApi implements BackupFileApi {
  PickedBackupFile? pickedFile;
  bool saveResult = true;
  String? savedFileName;
  Uint8List? savedBytes;

  @override
  Future<PickedBackupFile?> pickBackup() async => pickedFile;

  @override
  Future<bool> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) async {
    savedFileName = fileName;
    savedBytes = bytes;
    return saveResult;
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

Map<String, dynamic> _validBackupJson({
  String type = 'aria2',
  Object port = 6800,
  String id = 'new',
}) {
  return <String, dynamic>{
    'schemaVersion': 1,
    'backupId': 'backup-1',
    'createdAt': '2026-08-22T10:00:00Z',
    'appVersion': '1.1.4',
    'downloaders': <Object?>[
      <String, dynamic>{
        'id': id,
        'name': 'Imported',
        'type': type,
        'host': '127.0.0.1',
        'port': port,
        'secret': null,
        'username': null,
        'password': null,
        'useHttps': false,
        'version': null,
      },
    ],
  };
}

DownloaderBackupService _buildService({
  required DownloaderController controller,
  required _FakeBackupFileApi fileApi,
}) {
  return DownloaderBackupService(
    fileApi: fileApi,
    downloaderController: controller,
    currentAppVersion: () async => '1.1.4',
  );
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
    await GetStorage().remove('downloaders');
    await GetStorage().remove('downloaders_import_rollback_snapshot');
  });

  group('DownloaderBackupService', () {
    test(
      'exports a readable JSON backup through the system file API',
      () async {
        final controller = DownloaderController()
          ..setTestDownloadersForTest(<Downloader>[_downloader()]);
        final fileApi = _FakeBackupFileApi();
        final service = _buildService(controller: controller, fileApi: fileApi);

        expect(await service.exportBackup(), isTrue);
        expect(fileApi.savedFileName, endsWith('.json'));

        final decoded = jsonDecode(utf8.decode(fileApi.savedBytes!));
        final bundle = DownloaderBackupBundle.fromJson(
          Map<String, dynamic>.from(decoded as Map),
        );
        expect(bundle.downloaders.single.id, 'd1');
        expect(bundle.schemaVersion, 1);
      },
    );

    test('valid import replaces configurations after validation', () async {
      final controller = DownloaderController()
        ..setTestDownloadersForTest(<Downloader>[_downloader(id: 'old')]);
      final fileApi = _FakeBackupFileApi()
        ..pickedFile = PickedBackupFile(
          fileName: 'backup.json',
          bytes: Uint8List.fromList(
            utf8.encode(jsonEncode(_validBackupJson())),
          ),
        );
      final service = _buildService(controller: controller, fileApi: fileApi);

      final bundle = await service.importBackup();

      expect(bundle, isNotNull);
      expect(controller.downloaders.single.id, 'new');
      expect(controller.hasRollbackSnapshot, isTrue);
    });

    test('malformed JSON is rejected without changing current data', () async {
      final controller = DownloaderController()
        ..setTestDownloadersForTest(<Downloader>[_downloader(id: 'old')]);
      final fileApi = _FakeBackupFileApi()
        ..pickedFile = PickedBackupFile(
          fileName: 'invalid.json',
          bytes: Uint8List.fromList(utf8.encode('{not-json')),
        );
      final service = _buildService(controller: controller, fileApi: fileApi);

      await expectLater(
        service.importBackup(),
        throwsA(
          isA<BackupException>().having(
            (error) => error.reason,
            'reason',
            BackupFailureReason.parseFailed,
          ),
        ),
      );
      expect(controller.downloaders.single.id, 'old');
      expect(controller.hasRollbackSnapshot, isFalse);
    });

    test(
      'unsupported downloader type is rejected before replacement',
      () async {
        final controller = DownloaderController()
          ..setTestDownloadersForTest(<Downloader>[_downloader(id: 'old')]);
        final fileApi = _FakeBackupFileApi()
          ..pickedFile = PickedBackupFile(
            fileName: 'invalid.json',
            bytes: Uint8List.fromList(
              utf8.encode(jsonEncode(_validBackupJson(type: 'unknown'))),
            ),
          );
        final service = _buildService(controller: controller, fileApi: fileApi);

        await expectLater(
          service.importBackup(),
          throwsA(isA<BackupException>()),
        );
        expect(controller.downloaders.single.id, 'old');
        expect(controller.hasRollbackSnapshot, isFalse);
      },
    );

    test('out-of-range port is rejected before replacement', () async {
      final bytes = utf8.encode(jsonEncode(_validBackupJson(port: 70000)));

      expect(
        () => DownloaderBackupService.decodeAndValidate(bytes),
        throwsA(isA<BackupException>()),
      );
    });

    test('duplicate downloader ids are rejected', () async {
      final json = _validBackupJson();
      final first = Map<String, dynamic>.from(
        (json['downloaders'] as List<dynamic>).single as Map,
      );
      (json['downloaders'] as List<dynamic>).add(first);

      expect(
        () => DownloaderBackupService.decodeAndValidate(
          utf8.encode(jsonEncode(json)),
        ),
        throwsA(isA<BackupException>()),
      );
    });

    test('empty and oversized files are rejected', () {
      expect(
        () => DownloaderBackupService.decodeAndValidate(const <int>[]),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => DownloaderBackupService.decodeAndValidate(
          Uint8List(DownloaderBackupService.maxBackupFileBytes + 1),
        ),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
