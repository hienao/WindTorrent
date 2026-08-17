import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';
import 'package:windwalker/models/transmission_realtime_snapshot.dart';

void main() {
  group('TaskDomainStore qBit snapshot', () {
    test('applyQBitSnapshot 会同步更新 snapshot、任务列表、qBit categories 与 tags', () {
      final store = TaskDomainStore();

      store.applyQBitSnapshot(
        QBitRealtimeSnapshot.fromJson(
          downloaderId: 'q1',
          json: {
            'rid': 1,
            'full_update': true,
            'categories': {
              'radarr': {'name': 'radarr', 'savePath': ''},
            },
            'tags': ['RENAME'],
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
                'category': 'radarr',
                'tags': 'RENAME',
              },
            },
          },
        ),
      );

      expect(store.qbitSnapshot('q1')?.rid, 1);
      expect(store.tasksForDownloader('q1').single.name, 'demo');
      expect(store.qbitCategories('q1'), ['radarr']);
      expect(store.qbitTags('q1'), ['RENAME']);
    });

    test('qBit 摘要聚合下载器速度、任务数与状态统计', () {
      final store = TaskDomainStore();

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

      final summary = store.summary('q1')!;
      expect(summary.status, DownloaderStatus.online);
      expect(summary.downloadSpeed, 100);
      expect(summary.uploadSpeed, 20);
      expect(summary.taskCount, 1);
      expect(summary.taskStats['downloading'], 1);
    });

    test('task / tasksForDownloader 对未知下载器返回空与 null', () {
      final store = TaskDomainStore();
      expect(store.task('missing', 'abc'), isNull);
      expect(store.tasksForDownloader('missing'), isEmpty);
    });

    test('增量合并后任务字段同步更新', () {
      final store = TaskDomainStore();

      store.debugApplyQBitSnapshot(
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
                'save_path': '/ptd',
              },
            },
          },
        ),
      );

      store.debugApplyQBitSnapshot(
        store.qbitSnapshot('q1')!.mergeJson({
          'rid': 2,
          'torrents': {
            'abc': {'progress': 0.5, 'dlspeed': 200},
          },
        }),
      );

      expect(store.task('q1', 'abc')?.progress, 0.5);
      expect(store.tasksForDownloader('q1').single.downloadSpeed, 200);
    });
  });

  group('TaskDomainStore Transmission snapshot', () {
    test('applyTransmissionSnapshot 会写入任务列表与速度摘要', () {
      final store = TaskDomainStore();

      store.applyTransmissionSnapshot(
        TransmissionRealtimeSnapshot.fromRpc(
          downloaderId: 't1',
          torrents: [
            {
              'id': 7,
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
            }
          ],
        ),
      );

      expect(store.transmissionSnapshot('t1'), isNotNull);
      expect(store.task('t1', '7')?.name, 'demo');
      final summary = store.summary('t1')!;
      expect(summary.downloadSpeed, 12);
      expect(summary.uploadSpeed, 3);
      expect(summary.taskCount, 1);
    });
  });

  group('TaskDomainStore allTasks 与离线标记', () {
    test('allTasks 聚合多个下载器任务并按下载速度降序', () {
      final store = TaskDomainStore();
      store.applyQBitSnapshot(
        QBitRealtimeSnapshot.fromJson(
          downloaderId: 'q1',
          json: {
            'rid': 1,
            'full_update': true,
            'server_state': {'dl_info_speed': 0, 'up_info_speed': 0},
            'torrents': {
              'a': {
                'name': 'a',
                'state': 'downloading',
                'progress': 0.1,
                'dlspeed': 100,
                'save_path': '/ptd',
              },
            },
          },
        ),
      );
      store.applyTransmissionSnapshot(
        TransmissionRealtimeSnapshot.fromRpc(
          downloaderId: 't1',
          torrents: [
            {
              'id': 2,
              'name': 'b',
              'status': 4,
              'percentDone': 0.1,
              'totalSize': 1,
              'leftUntilDone': 0,
              'rateDownload': 300,
              'rateUpload': 0,
              'downloadDir': '/ptd',
              'peersSendingToUs': 0,
              'peersGettingFromUs': 0,
              'trackerStats': [],
            }
          ],
        ),
      );

      final all = store.allTasks;
      expect(all.length, 2);
      expect(all[0].downloadSpeed, greaterThan(all[1].downloadSpeed));
    });

    test('markDownloaderOffline 清零速度并标记离线', () {
      final store = TaskDomainStore();
      store.markDownloaderOffline('q1');

      final summary = store.summary('q1')!;
      expect(summary.status, DownloaderStatus.offline);
      expect(summary.downloadSpeed, 0);
      expect(summary.taskCount, 0);
    });
  });
}
