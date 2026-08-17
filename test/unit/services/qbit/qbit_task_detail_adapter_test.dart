import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_task_options.dart';
import 'package:windwalker/models/qbit_task_options_update.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';
import 'package:windwalker/services/qbit/qbit_v5_adapter.dart';

void main() {
  Downloader qbit() => Downloader(
    id: 'q',
    name: 'q',
    type: DownloaderType.qbittorrent,
    host: 'localhost',
    port: 8080,
    username: 'admin',
    password: 'admin',
  );

  /// Builds a QBitV5Adapter backed by a MockClient that returns canned
  /// payloads for the qBit WebUI endpoints touched by the detail surface.
  /// [onPost] captures POST writes for assertion.
  QBitV5Adapter buildAdapter({
    List<Map<String, dynamic>> torrentInfo = const [],
    Map<String, dynamic>? properties,
    List<Map<String, dynamic>> trackers = const [],
    List<Map<String, dynamic>> webSeeds = const [],
    List<Map<String, dynamic>> files = const [],
    Map<String, dynamic>? peers,
    Map<String, dynamic> categories = const {},
    List<dynamic> tags = const [],
    void Function(String path, Map<String, String> body)? onPost,
  }) {
    // qBit 响应含 μTP / 中文等非 Latin1 字符，必须显式按 UTF-8 编码并声明
    // charset，否则 http.Response 默认按 Latin1 解码导致乱码或编码异常。
    http.Response jsonResponse(Object? body, {int status = 200}) {
      return http.Response.bytes(
        Uint8List.fromList(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.method == 'POST') {
        if (onPost != null) {
          final body = request.body;
          final parsed = Uri.splitQueryString(body);
          onPost(path, parsed);
        }
        return http.Response('', 200);
      }

      // GETs
      if (path.endsWith('/api/v2/torrents/info')) {
        return jsonResponse(torrentInfo);
      }
      if (path.contains('/api/v2/torrents/properties')) {
        return jsonResponse(properties ?? {});
      }
      if (path.contains('/api/v2/torrents/trackers')) {
        return jsonResponse(trackers);
      }
      if (path.contains('/api/v2/torrents/webseeds')) {
        return jsonResponse(webSeeds);
      }
      if (path.contains('/api/v2/torrents/files')) {
        return jsonResponse(files);
      }
      if (path.contains('/api/v2/sync/torrentPeers')) {
        return jsonResponse(peers ?? {'peers': {}});
      }
      if (path.endsWith('/api/v2/torrents/categories')) {
        return jsonResponse(categories);
      }
      if (path.endsWith('/api/v2/torrents/tags')) {
        return jsonResponse(tags);
      }
      return http.Response('', 404);
    });

    final session = QBitSession(qbit(), client: client);
    return QBitV5Adapter(session);
  }

  test('getTaskFullDetail merges info, properties, trackers, and webseeds',
      () async {
    final adapter = buildAdapter(
      torrentInfo: [
        {
          'hash': 'abc',
          'name': 'Three Kingdoms',
          'size': 114390000000,
          'progress': 0.12,
          'dlspeed': 0,
          'upspeed': 0,
          'state': 'stalledDL',
          'save_path': '/ptd',
          'category': 'tv',
          'tags': 'classic, chinese',
          'num_seeds': 0,
          'num_complete': 5,
          'num_leechs': 0,
          'num_incomplete': 30,
          'priority': 1,
        },
      ],
      properties: {
        'total_wasted': 0,
        'total_downloaded': 171730000,
        'total_uploaded': 71310000,
        'dl_speed_avg': 161180,
        'up_speed_avg': 66930,
        'eta': 8640000,
        'share_ratio': 0.42,
        'popularity': 1000.98,
        'reannounce': 0,
        'last_seen': 1782045647,
        'addition_date': 1782036622,
        'completion_date': -1,
        'creation_date': 1262304000,
        'time_elapsed': 1080,
        'seeding_time': 0,
        'piece_size': 8388608,
        'pieces_num': 14643,
        'pieces_have': 1757,
        'comment': '',
        'created_by': '',
        'nb_connections': 5,
        'nb_connections_limit': 300,
        'progress': 0.1596,
        'peers': 3,
        'peers_total': 125,
        'seeds': 2,
        'seeds_total': 8,
        'total_size': 114390000000,
        'hash': 'abc',
        'infohash_v1': 'abc',
        'infohash_v2': '',
        'total_downloaded_session': 0,
        'total_uploaded_session': 65536,
      },
      trackers: [
        {
          'url': 'https://tracker.example/announce',
          'status': 2,
          'tier': 0,
          'num_seeds': 5,
          'num_leeches': 30,
          'num_downloaded': 0,
        },
        {
          'url': '** [DHT] **',
          'status': 2,
          'num_peers': 0,
          'num_seeds': 0,
          'num_leeches': 0,
          'num_downloaded': 0,
        },
      ],
      webSeeds: [
        {'url': 'https://cdn.example/file1'},
        {'url': 'https://cdn.example/file2'},
      ],
    );

    final detail = await adapter.getTaskFullDetail('abc');

    expect(detail!.taskId, 'abc');
    expect(detail.category, 'tv');
    expect(detail.httpSourceCount, 2);
    expect(detail.sourceCount, 1);
    // properties 优先读取
    expect(detail.progress, closeTo(0.1596, 0.001));
    expect(detail.peerCount, 3); // props['peers']
    expect(detail.leechs, 125); // props['peers_total']
    expect(detail.seeds, 8); // props['seeds_total']
    expect(detail.connections, 5);
    expect(detail.connectionsLimit, 300);
    expect(detail.completedPieceCount, 1757);
    expect(detail.infoHashV1, 'abc');
    expect(detail.infoHashV2, isEmpty);
  });

  test(
      'getTaskFiles, getTaskSources, getTaskPeers, and getTaskOptions parse qBit payloads',
      () async {
    final adapter = buildAdapter(
      files: [
        {
          'name': 'demo/EP01.mkv',
          'size': 100,
          'progress': 0.0,
          'priority': 1,
          'index': 0
        },
        {
          'name': 'demo/subs/EP01.srt',
          'size': 10,
          'progress': 1.0,
          'priority': 1,
          'index': 1
        },
      ],
      trackers: [
        {
          'url': '** [DHT] **',
          'status': 2,
          'num_peers': 7,
          'num_seeds': 0,
          'num_leeches': 0,
          'num_downloaded': 0
        },
        {
          'url': '** [PeX] **',
          'status': 2,
          'num_peers': 3,
          'num_seeds': 0,
          'num_leeches': 0,
          'num_downloaded': 0
        },
      ],
      // Local 4.1 / 5.0 API docs leave torrentPeers response undocumented.
      // A real incremental sample showed `rid`, `peers_removed`, and sparse peer
      // objects, so the adapter must request `rid=0` for the page itself and use
      // the map key as the canonical endpoint id when nested `ip`/`port` are absent.
      peers: {
        'rid': 0,
        'peers': {
          '1.1.1.1:51413': {
            'ip': '1.1.1.1',
            'port': 51413,
            'connection': 'BT',
            'flags': 'HX',
            'dl_speed': 0,
            'up_speed': 12800,
            'downloaded': 0,
            'uploaded': 2048,
            'progress': 0.31,
            'relevance': 0.0002,
          }
        }
      },
      torrentInfo: [
        {
          'hash': 'abc',
          'name': 'demo',
          'category': 'tv',
          'tags': 'classic, chinese',
          'priority': 3,
        },
      ],
      categories: {
        'tv': {'name': 'tv', 'savePath': '/ptd/tv'},
        'movie': {'name': 'movie', 'savePath': '/ptd/movie'},
      },
      tags: ['classic', 'chinese', 'favorite'],
    );

    final files = await adapter.getTaskFiles('abc');
    final sources = await adapter.getTaskSources('abc');
    final peers = await adapter.getTaskPeers('abc');
    final options = await adapter.getTaskOptions('abc');

    // demo/EP01.mkv + demo/subs/EP01.srt → root `demo` has two children:
    // the EP01.mkv leaf and the `subs` directory (which holds EP01.srt).
    final demoDir = files.single;
    expect(demoDir.name, 'demo');
    expect(demoDir.isDirectory, isTrue);
    final subsDir = demoDir.children.firstWhere((n) => n.name == 'subs');
    expect(subsDir.isDirectory, isTrue);
    expect(subsDir.children.single.name, 'EP01.srt');
    expect(sources.first.name, 'DHT');
    // DHT pseudo-tracker: num_peers=7, num_downloaded=0 (累计完成).
    expect(sources.first.peerCount, 7);
    expect(sources.first.downloadedCount, 0);
    expect(peers.single.protocol, 'BT');
    expect(options.queuePosition, 3);
    expect(options.tags, ['classic', 'chinese']);
  });

  test(
      'getTaskPeers ignores removed peers and derives endpoint from sparse payloads',
      () async {
    final adapter = buildAdapter(
      peers: {
        'rid': 7,
        'peers': {
          '31.200.249.146:31876': {
            'client': '',
            'connection': 'μTP',
            'dl_speed': 0,
            'downloaded': 0,
            'files': '',
            'flags': 'H P',
            'flags_desc': 'H = 来自 DHT 的下载者\nP = μTP',
            'ip': '31.200.249.146',
            'port': 31876,
            'progress': 0,
            'relevance': 0,
            'up_speed': 0,
            'uploaded': 0,
          },
          '223.85.210.158:7682': {
            'relevance': 0.7725189795499624,
          },
        },
        'peers_removed': ['49.76.52.97:20014'],
      },
    );

    final peers = await adapter.getTaskPeers('abc');

    expect(peers.first.address, '31.200.249.146');
    expect(peers.first.port, 31876);
    expect(peers.first.protocol, 'μTP');
    expect(peers.last.address, '223.85.210.158');
    expect(peers.last.port, 7682);
  });

  test('updateTaskOptions uses queue action plus category/tag endpoints',
      () async {
    final recorder = <String>[];
    final adapter = buildAdapter(
      onPost: (path, body) => recorder.add('$path $body'),
    );

    await adapter.updateTaskOptions(
      'abc',
      current: const QBitTaskOptions(
        queuePosition: 3,
        category: 'tv',
        tags: ['classic'],
        availableCategories: ['tv'],
        availableTags: ['classic'],
      ),
      update: const QBitTaskOptionsUpdate(
        queueAction: QBitQueuePriorityAction.top,
        category: 'drama',
        tags: ['classic', 'favorite'],
      ),
    );

    expect(recorder, contains('/api/v2/torrents/topPrio {hashes: abc}'));
    expect(
        recorder, contains('/api/v2/torrents/createCategory {category: drama}'));
    expect(recorder,
        contains('/api/v2/torrents/setCategory {hashes: abc, category: drama}'));
    expect(
        recorder, contains('/api/v2/torrents/createTags {tags: favorite}'));
    expect(recorder,
        contains('/api/v2/torrents/addTags {hashes: abc, tags: favorite}'));
  });
}
