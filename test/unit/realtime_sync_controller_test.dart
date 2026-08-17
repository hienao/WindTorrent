import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/realtime/presentation/controllers/realtime_sync_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/models/aria2_realtime_snapshot.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/transmission_realtime_snapshot.dart';

/// qBit 轮询测试用的固定下载器（与迁移基线测试共享）。
final Downloader fakeQBitDownloader = Downloader(
  id: 'q1',
  name: 'qbit',
  type: DownloaderType.qbittorrent,
  host: '127.0.0.1',
  port: 8080,
);

void main() {
  group('RealtimeSyncController tracking', () {
    test('debugBindDownloaders 后 _trackedDownloaders 包含所有下载器（含 Aria2）', () {
      final controller = RealtimeSyncController();
      final downloaders = [
        Downloader(
          id: 'a1',
          name: 'aria2',
          type: DownloaderType.aria2,
          host: '127.0.0.1',
          port: 6800,
        ),
        Downloader(
          id: 'q1',
          name: 'qbit',
          type: DownloaderType.qbittorrent,
          host: '127.0.0.1',
          port: 8080,
        ),
        Downloader(
          id: 't1',
          name: 'trans',
          type: DownloaderType.transmission,
          host: '127.0.0.1',
          port: 9091,
        ),
      ];

      controller.debugBindDownloaders(downloaders);

      expect(controller.debugTrackedDownloaderIds, {'a1', 'q1', 't1'});
    });

    test('重新绑定后旧下载器被替换', () {
      final controller = RealtimeSyncController();
      final q1 = Downloader(
        id: 'q1',
        name: 'qbit',
        type: DownloaderType.qbittorrent,
        host: '127.0.0.1',
        port: 8080,
      );
      controller.debugBindDownloaders([q1]);
      expect(controller.debugTrackedDownloaderIds, {'q1'});

      controller.debugBindDownloaders([]);
      expect(controller.debugTrackedDownloaderIds, <String>{});
    });
  });

  group('RealtimeSyncController qBit polling', () {
    test('首次 full_update 会写入完整快照与 rid', () async {
      final controller = RealtimeSyncController(
        qbitPollerFactory: (downloader, rid) async {
          return {
            'rid': 1,
            'full_update': true,
            'server_state': {
              'dl_info_speed': 100,
              'up_info_speed': 20,
            },
            'torrents': {
              'abc': {
                'name': 'demo',
                'state': 'downloading',
                'progress': 0.2,
                'dlspeed': 100,
                'upspeed': 20,
                'total_size': 1000,
                'downloaded': 200,
                'uploaded': 50,
                'save_path': '/ptd',
              }
            },
          };
        },
      );

      final q1 = Downloader(
        id: 'q1',
        name: 'qbit',
        type: DownloaderType.qbittorrent,
        host: '127.0.0.1',
        port: 8080,
      );
      controller.debugBindDownloaders([q1]);

      await controller.debugPollOnce(q1);

      expect(controller.qbitSnapshot('q1'), isNotNull);
      expect(controller.qbitSnapshot('q1')!.rid, 1);
      expect(controller.qbitSnapshot('q1')!.torrents['abc']!.name, 'demo');
    });

    test('连续 qBit 轮询会以增量 rid 请求下一次', () async {
      final requestedRids = <int>[];
      final controller = RealtimeSyncController(
        qbitPollerFactory: (downloader, rid) async {
          requestedRids.add(rid);
          final nextRid = rid == 0 ? 100 : rid + 1;
          return {
            'rid': nextRid,
            if (rid == 0) 'full_update': true,
            'torrents': {},
          };
        },
      );

      final q1 = Downloader(
        id: 'q1',
        name: 'qbit',
        type: DownloaderType.qbittorrent,
        host: '127.0.0.1',
        port: 8080,
      );
      controller.debugBindDownloaders([q1]);

      await controller.debugPollOnce(q1);
      await controller.debugPollOnce(q1);
      await controller.debugPollOnce(q1);

      expect(requestedRids, [0, 100, 101]);
    });

    test('增量响应会与上一轮 snapshot 合并，保留未变化的 torrent', () async {
      int call = 0;
      final controller = RealtimeSyncController(
        qbitPollerFactory: (downloader, rid) async {
          call++;
          if (call == 1) {
            return {
              'rid': 1,
              'full_update': true,
              'server_state': {'dl_info_speed': 100},
              'torrents': {
                'abc': {
                  'name': 'demo',
                  'state': 'downloading',
                  'progress': 0.2,
                  'dlspeed': 100,
                  'save_path': '/ptd',
                },
              },
            };
          }
          return {
            'rid': 2,
            'server_state': {'dl_info_speed': 200},
            'torrents': {
              'abc': {'progress': 0.4, 'dlspeed': 200},
            },
          };
        },
      );

      final q1 = Downloader(
        id: 'q1',
        name: 'qbit',
        type: DownloaderType.qbittorrent,
        host: '127.0.0.1',
        port: 8080,
      );
      controller.debugBindDownloaders([q1]);

      await controller.debugPollOnce(q1);
      await controller.debugPollOnce(q1);

      final snapshot = controller.qbitSnapshot('q1')!;
      expect(snapshot.rid, 2);
      expect(snapshot.serverState.downloadSpeed, 200);
      // 未在增量中出现的 name / save_path 保留
      expect(snapshot.torrents['abc']!.name, 'demo');
      expect(snapshot.torrents['abc']!.savePath, '/ptd');
      // 增量字段被覆盖
      expect(snapshot.torrents['abc']!.progress, 0.4);
      expect(snapshot.torrents['abc']!.downloadSpeed, 200);
    });
  });

  group('RealtimeSyncController Transmission polling', () {
    test('Transmission poll 成功后会更新 Transmission 快照', () async {
      final controller = RealtimeSyncController(
        transmissionPollerFactory: (downloader) async {
          return TransmissionRealtimeSnapshot.fromRpc(
            downloaderId: 't1',
            torrents: [
              {
                'id': 1,
                'name': 'demo',
                'status': 4,
                'percentDone': 0.5,
                'totalSize': 100,
                'leftUntilDone': 50,
                'rateDownload': 12,
                'rateUpload': 3,
                'downloadDir': '/ptd',
                'peersSendingToUs': 2,
                'peersGettingFromUs': 1,
                'trackerStats': [],
              },
            ],
          );
        },
      );

      final t1 = Downloader(
        id: 't1',
        name: 'trans',
        type: DownloaderType.transmission,
        host: '127.0.0.1',
        port: 9091,
      );
      controller.debugBindDownloaders([t1]);

      await controller.debugPollOnce(t1);

      expect(controller.transmissionSnapshot('t1'), isNotNull);
      expect(controller.transmissionSnapshot('t1')!.totalDownloadSpeed, 12);
    });

    test('Transmission detail selector 从全局快照返回当前任务详情', () {
      final controller = RealtimeSyncController();
      controller.debugSetTransmissionSnapshot(
        TransmissionRealtimeSnapshot.fromRpc(
          downloaderId: 'tr-1',
          torrents: [
            {
              'id': 7,
              'name': 'demo',
              'status': 6,
              'percentDone': 1.0,
              'totalSize': 100,
              'leftUntilDone': 0,
              'rateDownload': 0,
              'rateUpload': 8,
              'downloadDir': '/ptd',
              'peersSendingToUs': 0,
              'peersGettingFromUs': 1,
              'trackerStats': [],
            }
          ],
        ),
      );

      final detail = controller.transmissionDetail(
        downloaderId: 'tr-1',
        taskId: '7',
      );

      expect(detail, isNotNull);
      expect(detail!.name, 'demo');
      expect(detail.peerCount, 1);
    });

    test('Transmission detail selector 无快照时返回 null', () {
      final controller = RealtimeSyncController();
      expect(
        controller.transmissionDetail(downloaderId: 'none', taskId: '1'),
        isNull,
      );
    });
  });

  group('RealtimeSyncController Aria2 polling', () {
    test('Aria2 poll 成功后会更新 Aria2 快照并写入 TaskDomainStore', () async {
      final store = TaskDomainStore();
      final controller = RealtimeSyncController(
        aria2PollerFactory: (downloader) async {
          return Aria2RealtimeSnapshot(
            downloaderId: downloader.id,
            tasks: [
              DownloadTask(
                id: 'g1',
                gid: 'g1',
                name: 'test.iso',
                totalSize: 1000,
                downloaded: 500,
                progress: 0.5,
                downloadSpeed: 100,
                uploadSpeed: 10,
                status: TaskStatus.downloading,
                downloaderId: downloader.id,
              ),
            ],
            downloadSpeed: 100,
            uploadSpeed: 10,
          );
        },
      )..attachStore(store);

      final a1 = Downloader(
        id: 'a1',
        name: 'aria2',
        type: DownloaderType.aria2,
        host: '127.0.0.1',
        port: 6800,
      );
      controller.debugBindDownloaders([a1]);

      await controller.debugPollOnce(a1);

      expect(controller.aria2Snapshot('a1'), isNotNull);
      expect(controller.aria2Snapshot('a1')!.downloadSpeed, 100);
      expect(controller.aria2Snapshot('a1')!.tasks.length, 1);
      expect(store.task('a1', 'g1')?.name, 'test.iso');
      expect(store.summary('a1')?.downloadSpeed, 100);
    });
  });

  group('RealtimeSyncController qBit selectors', () {
    test('qbitTorrent 从全局快照返回指定任务', () async {
      final controller = RealtimeSyncController(
        qbitPollerFactory: (downloader, rid) async {
          return {
            'rid': 1,
            'full_update': true,
            'torrents': {
              'abc': {
                'name': 'demo',
                'state': 'downloading',
                'progress': 0.5,
                'dlspeed': 100,
                'upspeed': 20,
              },
            },
          };
        },
      );

      final q1 = Downloader(
        id: 'q1',
        name: 'qbit',
        type: DownloaderType.qbittorrent,
        host: '127.0.0.1',
        port: 8080,
      );
      controller.debugBindDownloaders([q1]);
      await controller.debugPollOnce(q1);

      final torrent = controller.qbitTorrent(downloaderId: 'q1', taskId: 'abc');
      expect(torrent, isNotNull);
      expect(torrent!.name, 'demo');
      expect(torrent.progress, 0.5);
    });
  });

  group('RealtimeSyncController -> TaskDomainStore', () {
    test('qBit poll 成功后写入 TaskDomainStore，而不是直接写 TaskController', () async {
      final store = TaskDomainStore();
      final controller = RealtimeSyncController(
        qbitPollerFactory: (downloader, rid) async => {
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
              'total_size': 1000,
              'downloaded': 200,
              'uploaded': 50,
              'save_path': '/ptd',
            }
          },
        },
      )..attachStore(store);

      controller.debugBindDownloaders([fakeQBitDownloader]);
      await controller.debugPollOnce(fakeQBitDownloader);

      expect(store.qbitSnapshot('q1')?.rid, 1);
      expect(store.task('q1', 'abc')?.name, 'demo');
    });
  });

  group('RealtimeSyncController lifecycle', () {
    testWidgets('app paused 时取消所有 timer，resumed 时重建并立即刷新',
        (tester) async {
      int pollCount = 0;
      final controller = RealtimeSyncController(
        qbitPollerFactory: (downloader, rid) async {
          pollCount++;
          return {
            'rid': pollCount,
            if (pollCount == 1) 'full_update': true,
            'torrents': {},
          };
        },
      );

      final q1 = Downloader(
        id: 'q1',
        name: 'qbit',
        type: DownloaderType.qbittorrent,
        host: '127.0.0.1',
        port: 8080,
      );
      controller.debugBindDownloaders([q1]);

      // 构建 widget 树以确保 WidgetsBinding 完全初始化
      await tester.pumpWidget(MaterialApp(home: Text('test')));
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final countAfterStart = pollCount;
      expect(countAfterStart, greaterThanOrEqualTo(1));

      // 模拟锁屏：paused — 取消所有 timer
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // paused 后等待，不应有新轮询
      await tester.pump(const Duration(seconds: 10));
      expect(pollCount, countAfterStart);

      // 模拟解锁：resumed — 重建 timer 并立即刷新
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(pollCount, greaterThan(countAfterStart));

      // 必须在 _verifyInvariants 前 dispose
      controller.dispose();
    });

    test('resumed 会清零退避状态，使下一次轮询立即执行', () async {
      int pollCount = 0;
      final controller = RealtimeSyncController(
        aria2PollerFactory: (downloader) async {
          pollCount++;
          if (pollCount <= 3) {
            throw Exception('simulated failure');
          }
          return Aria2RealtimeSnapshot(
            downloaderId: downloader.id,
            tasks: const [],
            downloadSpeed: 0,
            uploadSpeed: 0,
          );
        },
      );

      final a1 = Downloader(
        id: 'a1',
        name: 'aria2',
        type: DownloaderType.aria2,
        host: '127.0.0.1',
        port: 6800,
      );
      controller.debugBindDownloaders([a1]);

      // 第 1 次失败：触发 _onPollFailure 设置退避
      await controller.debugPollOnce(a1);
      expect(pollCount, 1);

      // 第 2 次：仍在退避期，被跳过（debugPollOnce bypassBackoff=false）
      await controller.debugPollOnce(a1);
      expect(pollCount, 1); // 被退避跳过

      // 手动调用 _clearAllBackoffState 模拟 resumed 的退避清除效果
      // （不调用 didChangeAppLifecycleState 以避免创建 periodic timer）
      // ignore: invalid_use_of_protected_member
      controller.clearBackoffForTest();

      // 退避已清零，下一次 debugPollOnce 应立即执行
      await controller.debugPollOnce(a1);
      expect(pollCount, greaterThan(1));
    });
  });
}
