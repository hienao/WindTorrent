import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';

void main() {
  test('qBit full_update 后可被 incremental 响应正确合并', () {
    final full = QBitRealtimeSnapshot.fromJson(
      downloaderId: 'qb-1',
      json: {
        'rid': 6953,
        'full_update': true,
        'server_state': {'dl_info_speed': 2062475},
        'categories': {
          'radarr': {'name': 'radarr', 'savePath': ''}
        },
        'tags': ['RENAME'],
        'torrents': {
          '8762': {
            'name': '三国',
            'progress': 0.1636,
            'dlspeed': 1587920,
            'upspeed': 21939,
            'state': 'downloading',
            'save_path': '/ptd',
          }
        },
      },
    );

    final merged = full.mergeJson({
      'rid': 6954,
      'server_state': {'dl_info_speed': 1880811},
      'torrents': {
        '8762': {
          'progress': 0.16364,
          'dlspeed': 1712727,
          'upspeed': 16661,
        }
      },
    });

    expect(merged.rid, 6954);
    expect(merged.serverState.downloadSpeed, 1880811);
    expect(merged.torrents['8762']!.name, '三国');
    expect(merged.torrents['8762']!.downloadSpeed, 1712727);
    expect(merged.torrents['8762']!.savePath, '/ptd');
  });

  test('qBit incremental 响应包含 removed 集合时会删除旧任务', () {
    final full = QBitRealtimeSnapshot.fromJson(
      downloaderId: 'qb-1',
      json: {
        'rid': 10,
        'full_update': true,
        'server_state': {},
        'torrents': {
          'a': {'name': 'A', 'state': 'pausedUP'},
          'b': {'name': 'B', 'state': 'downloading'},
        },
      },
    );

    final merged = full.mergeJson({
      'rid': 11,
      'torrents_removed': ['a'],
    });

    expect(merged.torrents.containsKey('a'), isFalse);
    expect(merged.torrents.containsKey('b'), isTrue);
  });
}
