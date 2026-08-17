import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';

void main() {
  testWidgets('同一任务在列表页和详情页共享同一份状态', (tester) async {
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
              'upspeed': 20,
              'total_size': 1000,
              'downloaded': 200,
              'uploaded': 50,
              'save_path': '/ptd',
            }
          },
        },
      ),
    );

    expect(store.task('q1', 'abc')!.progress, 0.2);

    store.debugApplyQBitSnapshot(
      store.qbitSnapshot('q1')!.mergeJson({
        'rid': 2,
        'torrents': {
          'abc': {'progress': 0.5, 'dlspeed': 200},
        },
      }),
    );

    expect(store.task('q1', 'abc')!.progress, 0.5);
    expect(store.tasksForDownloader('q1').single.progress, 0.5);
  });
}
