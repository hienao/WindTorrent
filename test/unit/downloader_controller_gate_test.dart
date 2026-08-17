import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';
import 'package:windwalker/services/connection_result.dart';

/// 可注入 testConnection 结果的测试用 controller。
class TestableDownloaderController extends DownloaderController {
  ConnectionResult _result;
  TestableDownloaderController(this._result) : super();

  void setTestResult(ConnectionResult result) => _result = _result;

  @override
  Future<ConnectionResult> testConnection(Downloader downloader) async => _result;
}

/// 预置下载器列表的测试用 controller（绕过存储加载）。
class PrefilledDownloaderController extends DownloaderController {
  PrefilledDownloaderController(List<Downloader> downloaders) : super() {
    setTestDownloadersForTest(downloaders);
  }

  @override
  Future<ConnectionResult> testConnection(Downloader downloader) async =>
      const ConnectionSuccess(serverVersion: 'test');
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
  });

  Downloader sample() => Downloader(
    id: 'd1', name: 'D1', type: DownloaderType.aria2,
    host: 'h', port: 6800,
  );

  test('版本不符时不保存且返回 versionUnsupported', () async {
    final c = TestableDownloaderController(const ConnectionFailure(
      ConnectionFailureCategory.versionUnsupported, '版本过低',
      actualVersion: '1.35.0', minVersion: '1.36',
    ));
    final result = await c.addDownloader(sample());
    expect(result, isA<ConnectionFailure>());
    expect((result as ConnectionFailure).isVersionUnsupported, isTrue);
    expect(c.downloaders, isEmpty); // 未保存
  });

  test('成功时保存、写入 version、状态 online', () async {
    final c = TestableDownloaderController(
        const ConnectionSuccess(serverVersion: '1.36.0'));
    final result = await c.addDownloader(sample());
    expect(result.isSuccess, isTrue);
    expect(c.downloaders.length, 1);
    expect(c.downloaders.first.version, '1.36.0');
    expect(c.downloaders.first.status, DownloaderStatus.online);
  });

  test('认证失败时不保存', () async {
    final c = TestableDownloaderController(const ConnectionFailure(
      ConnectionFailureCategory.authFailed, '认证失败',
    ));
    await c.addDownloader(sample());
    expect(c.downloaders, isEmpty);
  });

  test('legacy Transmission success should still save downloader', () async {
    final c = TestableDownloaderController(
        const ConnectionSuccess(serverVersion: '4.0.3'),
    );

    final result = await c.addDownloader(Downloader(
      id: 'tx',
      name: 'Legacy Transmission',
      type: DownloaderType.transmission,
      host: 'localhost',
      port: 9091,
      username: 'u',
      password: 'p',
    ));

    expect(result.isSuccess, isTrue);
    expect(c.downloaders.single.version, '4.0.3');
  });

  group('realtimeSummary (TaskDomainStore facade)', () {
    test('attach 后从 TaskDomainStore 派生下载器实时摘要', () {
      final controller = PrefilledDownloaderController([
        Downloader(
          id: 'q1',
          name: 'qbit',
          type: DownloaderType.qbittorrent,
          host: '127.0.0.1',
          port: 8080,
        ),
      ]);
      final store = TaskDomainStore();
      controller.attachTaskDomainStore(store);

      // 未写入快照时返回 null
      expect(controller.realtimeSummary('q1'), isNull);

      store.applyQBitSnapshot(
        QBitRealtimeSnapshot.fromJson(
          downloaderId: 'q1',
          json: {
            'rid': 1,
            'full_update': true,
            'server_state': {'dl_info_speed': 100, 'up_info_speed': 20},
            'torrents': {
              'abc': {
                'name': 'demo',
                'state': 'downloading',
                'progress': 0.2,
                'dlspeed': 100,
                'upspeed': 20,
                'save_path': '/ptd',
              },
            },
          },
        ),
      );

      final summary = controller.realtimeSummary('q1')!;
      expect(summary.status, DownloaderStatus.online);
      expect(summary.downloadSpeed, 100);
      expect(summary.uploadSpeed, 20);
      expect(summary.taskCount, 1);
    });

    test('未 attach Store 时 realtimeSummary 返回 null', () {
      final controller = PrefilledDownloaderController([
        Downloader(
          id: 'q1',
          name: 'qbit',
          type: DownloaderType.qbittorrent,
          host: '127.0.0.1',
          port: 8080,
        ),
      ]);
      expect(controller.realtimeSummary('q1'), isNull);
    });
  });

  group('备份导出 / 原子替换 / 回滚快照', () {
    test('exportDownloadersForBackup returns JSON list', () {
      final c = PrefilledDownloaderController([
        Downloader(
          id: 'd1',
          name: 'Test',
          type: DownloaderType.aria2,
          host: 'localhost',
          port: 6800,
          username: 'user',
          password: 'pass',
        ),
      ]);

      final json = c.exportDownloadersForBackup();
      expect(json, hasLength(1));
      expect(json.first['id'], 'd1');
      expect(json.first['host'], 'localhost');
      // 不包含运行时状态字段
      expect(json.first.containsKey('status'), isFalse);
      expect(json.first.containsKey('taskCount'), isFalse);
    });

    test('replaceAllDownloadersFromBackup replaces and persists', () async {
      final c = PrefilledDownloaderController([
        Downloader(
          id: 'old',
          name: 'Old',
          type: DownloaderType.aria2,
          host: 'old-host',
          port: 6800,
        ),
      ]);

      await c.replaceAllDownloadersFromBackup(
        downloaders: [
          Downloader(
            id: 'new',
            name: 'New',
            type: DownloaderType.qbittorrent,
            host: 'new-host',
            port: 8080,
          ),
        ],
        sourceBackupId: 'backup-123',
      );

      expect(c.downloaders.single.id, 'new');
      expect(c.downloaders.single.host, 'new-host');
    });

    test('saveRollbackSnapshot and restoreRollbackSnapshot round-trip', () async {
      final c = PrefilledDownloaderController([
        Downloader(
          id: 'before',
          name: 'Before',
          type: DownloaderType.aria2,
          host: 'before-host',
          port: 6800,
        ),
      ]);

      await c.saveRollbackSnapshot(sourceBackupId: 'snap-1');

      // 替换为新数据
      await c.replaceAllDownloadersFromBackup(
        downloaders: [
          Downloader(
            id: 'after',
            name: 'After',
            type: DownloaderType.aria2,
            host: 'after-host',
            port: 6800,
          ),
        ],
        sourceBackupId: 'backup-2',
      );
      expect(c.downloaders.single.id, 'after');

      // 恢复回滚快照
      final restored = await c.restoreRollbackSnapshot();
      expect(restored, isTrue);
      // 注意：saveRollbackSnapshot 保存的是调用时的列表，
      // 但 replaceAll 也会先保存快照，所以这里恢复的是 replaceAll 前的快照
      expect(c.downloaders.single.id, 'before');
    });

    test('restoreRollbackSnapshot returns false when no snapshot', () async {
      final c = PrefilledDownloaderController([
        Downloader(
          id: 'd1',
          name: 'D1',
          type: DownloaderType.aria2,
          host: 'h',
          port: 6800,
        ),
      ]);

      // 清除可能存在的快照
      await GetStorage().remove('downloaders_import_rollback_snapshot');

      final restored = await c.restoreRollbackSnapshot();
      expect(restored, isFalse);
      // 列表不变
      expect(c.downloaders.single.id, 'd1');
    });

    test('restoreRollbackSnapshot cleans up snapshot after use', () async {
      final c = PrefilledDownloaderController([
        Downloader(
          id: 'orig',
          name: 'Orig',
          type: DownloaderType.aria2,
          host: 'h',
          port: 6800,
        ),
      ]);

      await c.saveRollbackSnapshot(sourceBackupId: 'snap-cleanup');
      // 快照已写入
      expect(GetStorage().read('downloaders_import_rollback_snapshot'), isNotNull);

      // 替换为新数据
      await c.replaceAllDownloadersFromBackup(
        downloaders: [
          Downloader(
            id: 'replaced',
            name: 'Replaced',
            type: DownloaderType.aria2,
            host: 'h2',
            port: 6800,
          ),
        ],
        sourceBackupId: 'backup-cleanup',
      );

      final restored = await c.restoreRollbackSnapshot();
      expect(restored, isTrue);
      expect(c.downloaders.single.id, 'orig');

      // 快照已被消费，第二次恢复应返回 false
      expect(GetStorage().read('downloaders_import_rollback_snapshot'), isNull);
      final restored2 = await c.restoreRollbackSnapshot();
      expect(restored2, isFalse);
    });
  });
}
