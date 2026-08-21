import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/connection_result.dart';

/// 可注入 testConnection 结果的测试用 controller。
class TestableDownloaderController extends DownloaderController {
  ConnectionResult _result;
  TestableDownloaderController(this._result) : super();

  void setTestResult(ConnectionResult result) => _result = _result;

  @override
  Future<ConnectionResult> testConnection(Downloader downloader) async =>
      _result;
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

class DelayedStatusDownloaderController extends DownloaderController {
  final Completer<ConnectionResult> statusResult = Completer();
  int globalStatsRefreshCount = 0;

  @override
  Future<ConnectionResult> testConnection(Downloader downloader) =>
      statusResult.future;

  @override
  Future<void> refreshGlobalStats() async {
    globalStatsRefreshCount++;
  }
}

class PerDownloaderStatusController extends DownloaderController {
  final Map<String, Completer<ConnectionResult>> _results = {};

  @override
  Future<ConnectionResult> testConnection(Downloader downloader) => _results
      .putIfAbsent(downloader.id, Completer<ConnectionResult>.new)
      .future;

  void complete(String id, ConnectionResult result) {
    _results[id]!.complete(result);
  }
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
    id: 'd1',
    name: 'D1',
    type: DownloaderType.aria2,
    host: 'h',
    port: 6800,
  );

  test('版本不符时不保存且返回 versionUnsupported', () async {
    final c = TestableDownloaderController(
      const ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        '版本过低',
        actualVersion: '1.35.0',
        minVersion: '1.36',
      ),
    );
    final result = await c.addDownloader(sample());
    expect(result, isA<ConnectionFailure>());
    expect((result as ConnectionFailure).isVersionUnsupported, isTrue);
    expect(c.downloaders, isEmpty); // 未保存
  });

  test('成功时保存、写入 version、状态 online', () async {
    final c = TestableDownloaderController(
      const ConnectionSuccess(serverVersion: '1.36.0'),
    );
    final result = await c.addDownloader(sample());
    expect(result.isSuccess, isTrue);
    expect(c.downloaders.length, 1);
    expect(c.downloaders.first.version, '1.36.0');
    expect(c.downloaders.first.status, DownloaderStatus.online);
  });

  test('认证失败时不保存', () async {
    final c = TestableDownloaderController(
      const ConnectionFailure(ConnectionFailureCategory.authFailed, '认证失败'),
    );
    await c.addDownloader(sample());
    expect(c.downloaders, isEmpty);
  });

  test('legacy Transmission success should still save downloader', () async {
    final c = TestableDownloaderController(
      const ConnectionSuccess(serverVersion: '4.0.3'),
    );

    final result = await c.addDownloader(
      Downloader(
        id: 'tx',
        name: 'Legacy Transmission',
        type: DownloaderType.transmission,
        host: 'localhost',
        port: 9091,
        username: 'u',
        password: 'p',
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(c.downloaders.single.version, '4.0.3');
  });

  group('下载器列表刷新', () {
    test('先展示本地配置，状态探测完成后再更新，且不刷新任务统计', () async {
      final downloader = sample();
      await GetStorage().write('downloaders', [downloader.toJson()]);
      final controller = DelayedStatusDownloaderController();

      final refresh = controller.loadDownloaders();
      await Future<void>.delayed(Duration.zero);

      expect(controller.downloaders.single.id, downloader.id);
      expect(controller.downloaders.single.status, DownloaderStatus.offline);
      expect(controller.isRefreshingStatus, isTrue);
      expect(controller.globalStatsRefreshCount, 0);

      controller.statusResult.complete(
        const ConnectionSuccess(serverVersion: '1.37.0'),
      );
      await refresh;

      expect(controller.downloaders.single.status, DownloaderStatus.online);
      expect(controller.downloaders.single.version, '1.37.0');
      expect(controller.isRefreshingStatus, isFalse);
      expect(controller.globalStatsRefreshCount, 0);
    });

    test('所有下载器探测完成后一次性提交状态', () async {
      final first = sample();
      final second = Downloader(
        id: 'd2',
        name: 'D2',
        type: DownloaderType.qbittorrent,
        host: 'qbit',
        port: 8080,
      );
      await GetStorage().write('downloaders', [
        first.toJson(),
        second.toJson(),
      ]);
      final controller = PerDownloaderStatusController();

      final refresh = controller.loadDownloaders();
      await Future<void>.delayed(Duration.zero);
      controller.complete(
        first.id,
        const ConnectionSuccess(serverVersion: '1.37.0'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.downloaders.map((item) => item.status),
        everyElement(DownloaderStatus.offline),
      );

      controller.complete(
        second.id,
        const ConnectionSuccess(serverVersion: '5.1.0'),
      );
      await refresh;

      expect(
        controller.downloaders.map((item) => item.status),
        everyElement(DownloaderStatus.online),
      );
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

    test(
      'saveRollbackSnapshot and restoreRollbackSnapshot round-trip',
      () async {
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
      },
    );

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
      expect(
        GetStorage().read('downloaders_import_rollback_snapshot'),
        isNotNull,
      );

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
