# qBittorrent Task Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generic qBittorrent task detail fallback with a qBit-specific info homepage plus `文件 / 服务器 / 节点 / 选项` child pages, where files/sources/peers are read-only and options supports queue-priority action, category, and tags editing.

**Architecture:** Keep `TaskDetailShell` as the shared chrome, but move qBit-specific fields, child-page data, and save flows into a focused qBit detail stack instead of overloading `DownloadTask`. Use page-local qBit controllers, Transmission-style child routes, and qBit service facade methods that merge `/torrents/info`, `/properties`, `/trackers`, `/webseeds`, `/files`, `/sync/torrentPeers`, `/categories`, and `/tags`. Because qBit WebUI exposes queue reordering as relative operations, the read model keeps the current numeric queue position while the write model uses an explicit queue action enum. The local 4.1 and 5.0 docs still do not document the `/sync/torrentPeers` response body, but we now have both a sanitized full snapshot fixture and a sanitized incremental fixture. The parser should therefore support confirmed fields such as `client`, `connection`, `flags`, `flags_desc`, `ip`, `peer_id_client`, `port`, `progress`, `relevance`, `dl_speed`, `up_speed`, `downloaded`, `uploaded`, and `files`, while the page itself should keep using `rid=0` and derive `ip:port` from the peer-map key when nested fields are absent.

**Tech Stack:** Flutter 3.24.5, Provider, go_router, Flutter l10n, qBittorrent WebUI API, widget tests, unit tests

---

## File Structure

### Create

- `lib/models/qbit_task_detail.dart`
  qBit info-homepage read model with section-ready fields and child-entry summaries; weakly documented fields such as v1/v2 hashes stay nullable and only render when present.
- `lib/models/qbit_task_file_node.dart`
  Read-only tree node model for the qBit files page.
- `lib/models/qbit_task_source.dart`
  Source-stat card model for DHT / PeX / LSD / tracker-like sources.
- `lib/models/qbit_task_peer.dart`
  Dense peer-row model for the nodes page.
- `lib/models/qbit_task_options.dart`
  Read model for current queue position, category, tags, and option catalogs.
- `lib/models/qbit_task_options_update.dart`
  Write payload for queue action, category update, and tag reconciliation.
- `lib/features/tasks/presentation/controllers/qbit_task_detail_controller.dart`
- `lib/features/tasks/presentation/controllers/qbit_task_files_controller.dart`
- `lib/features/tasks/presentation/controllers/qbit_task_sources_controller.dart`
- `lib/features/tasks/presentation/controllers/qbit_task_peers_controller.dart`
- `lib/features/tasks/presentation/controllers/qbit_task_options_controller.dart`
  qBit page-scoped loading, refresh, error, and dirty-state controllers.
- `lib/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart`
- `lib/features/tasks/presentation/pages/qbit/qbit_task_files_page.dart`
- `lib/features/tasks/presentation/pages/qbit/qbit_task_sources_page.dart`
- `lib/features/tasks/presentation/pages/qbit/qbit_task_peers_page.dart`
- `lib/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart`
  qBit homepage and four child pages.
- `lib/features/tasks/presentation/widgets/qbit_file_tree_node.dart`
- `lib/features/tasks/presentation/widgets/qbit_source_card.dart`
- `lib/features/tasks/presentation/widgets/qbit_peer_row.dart`
- `lib/features/tasks/presentation/widgets/qbit_options_form.dart`
  qBit-specific presentation widgets.
- `test/unit/services/qbit/qbit_task_detail_adapter_test.dart`
  qBit adapter parsing and mutation coverage for all new endpoints.
- `test/fixtures/qbit/torrent_peers_full_update.json`
  Sanitized full snapshot fixture for the peers parser, including confirmed peer field names.
- `test/fixtures/qbit/torrent_peers_incremental_update.json`
  Sanitized incremental sample with `rid`, `peers_removed`, and sparse peer updates for regression coverage.
- `test/unit/qbit_task_options_controller_test.dart`
  Dirty-state, validation, and save-flow tests.
- `test/widget/qbit_task_detail_page_test.dart`
- `test/widget/qbit_test_helpers.dart`
- `test/widget/qbit_task_files_page_test.dart`
- `test/widget/qbit_task_sources_page_test.dart`
- `test/widget/qbit_task_peers_page_test.dart`
- `test/widget/qbit_task_options_page_test.dart`
  Homepage and child-page rendering / route-entry tests.

### Modify

- `lib/services/qbit/qbit_api_adapter.dart`
  Extend the qBit adapter contract with detail/files/sources/peers/options methods.
- `lib/services/qbit/qbit_base_api_adapter.dart`
  Implement the new qBit WebUI reads/writes and parsing helpers.
- `lib/services/qbit_service.dart`
  Expose the new qBit facade methods.
- `lib/features/tasks/presentation/pages/task_detail_page.dart`
  Dispatch qBittorrent tasks to the new qBit homepage instead of `GenericTaskDetailPage`.
- `lib/core/router/app_router.dart`
  Add qBit child-page routes under `/tasks/detail/:id/qbit/...`.
- `test/widget/task_detail_route_page_test.dart`
  Verify route dispatch now targets `QBitTaskDetailPage`.
- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_ja.arb`
  Add qBit section titles, labels, empty states, queue-action labels, and save feedback.

## Task 1: Add qBit Detail Models And WebUI Service Methods

**Files:**
- Create: `lib/models/qbit_task_detail.dart`
- Create: `lib/models/qbit_task_file_node.dart`
- Create: `lib/models/qbit_task_source.dart`
- Create: `lib/models/qbit_task_peer.dart`
- Create: `lib/models/qbit_task_options.dart`
- Create: `lib/models/qbit_task_options_update.dart`
- Modify: `lib/services/qbit/qbit_api_adapter.dart`
- Modify: `lib/services/qbit/qbit_base_api_adapter.dart`
- Modify: `lib/services/qbit_service.dart`
- Test: `test/unit/services/qbit/qbit_task_detail_adapter_test.dart`

- [x] **Step 1: Write the failing qBit adapter tests**

```dart
test('getTaskFullDetail merges info, properties, trackers, and webseeds', () async {
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
      'comment': '',
      'created_by': '',
      'nb_connections': 0,
      'nb_connections_limit': 300,
      'total_size': 114390000000,
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
});

test('getTaskFiles, getTaskSources, getTaskPeers, and getTaskOptions parse qBit payloads', () async {
  final adapter = buildAdapter(
    files: [
      {'name': 'demo/EP01.mkv', 'size': 100, 'progress': 0.0, 'priority': 1, 'index': 0},
      {'name': 'demo/subs/EP01.srt', 'size': 10, 'progress': 1.0, 'priority': 1, 'index': 1},
    ],
    trackers: [
      {'url': '** [DHT] **', 'status': 2, 'num_peers': 7, 'num_seeds': 0, 'num_leeches': 0, 'num_downloaded': 0},
      {'url': '** [PeX] **', 'status': 2, 'num_peers': 3, 'num_seeds': 0, 'num_leeches': 0, 'num_downloaded': 0},
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

  expect(files.single.children.single.name, 'subs');
  expect(sources.first.name, 'DHT');
  expect(peers.single.protocol, 'BT');
  expect(options.queuePosition, 3);
  expect(options.tags, ['classic', 'chinese']);
});

test('getTaskPeers ignores removed peers and derives endpoint from sparse payloads', () async {
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
          'flags_desc': 'H = 来自 DHT 的下载者\\nP = μTP',
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

test('updateTaskOptions uses queue action plus category/tag endpoints', () async {
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
  expect(recorder, contains('/api/v2/torrents/createCategory {category: drama}'));
  expect(recorder, contains('/api/v2/torrents/setCategory {hashes: abc, category: drama}'));
  expect(recorder, contains('/api/v2/torrents/createTags {tags: favorite}'));
  expect(recorder, contains('/api/v2/torrents/addTags {hashes: abc, tags: favorite}'));
});
```

- [x] **Step 2: Run the adapter tests to verify they fail**

Run: `flutter test test/unit/services/qbit/qbit_task_detail_adapter_test.dart`

Expected: FAIL with undefined classes and methods for:

- `QBitTaskDetail`
- `QBitTaskFileNode`
- `QBitTaskSource`
- `QBitTaskPeer`
- `QBitTaskOptions`
- `QBitTaskOptionsUpdate`
- `QBitQueuePriorityAction`
- `getTaskFullDetail`
- `getTaskFiles`
- `getTaskSources`
- `getTaskPeers`
- `getTaskOptions`
- `updateTaskOptions`

- [x] **Step 3: Write the minimal models and qBit service surface**

```dart
// lib/models/qbit_task_options_update.dart
enum QBitQueuePriorityAction { unchanged, increase, decrease, top, bottom }

class QBitTaskOptionsUpdate {
  const QBitTaskOptionsUpdate({
    required this.queueAction,
    required this.category,
    required this.tags,
  });

  final QBitQueuePriorityAction queueAction;
  final String category;
  final List<String> tags;
}
```

```dart
// lib/models/qbit_task_options.dart
class QBitTaskOptions {
  const QBitTaskOptions({
    required this.queuePosition,
    required this.category,
    required this.tags,
    required this.availableCategories,
    required this.availableTags,
  });

  final int queuePosition;
  final String category;
  final List<String> tags;
  final List<String> availableCategories;
  final List<String> availableTags;

  QBitTaskOptions copyWith({
    int? queuePosition,
    String? category,
    List<String>? tags,
    List<String>? availableCategories,
    List<String>? availableTags,
  }) {
    return QBitTaskOptions(
      queuePosition: queuePosition ?? this.queuePosition,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      availableCategories: availableCategories ?? this.availableCategories,
      availableTags: availableTags ?? this.availableTags,
    );
  }
}
```

```dart
// lib/models/qbit_task_file_node.dart
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class QBitTaskFileNode {
  const QBitTaskFileNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.downloaded,
    required this.progress,
    this.children = const [],
  });

  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final int downloaded;
  final double progress;
  final List<QBitTaskFileNode> children;

  String get formattedSize => _formatBytes(size);
  String get progressLabel => '${(progress * 100).toStringAsFixed(1)}%';
}
```

```dart
// lib/models/qbit_task_source.dart
class QBitTaskSource {
  const QBitTaskSource({
    required this.name,
    required this.status,
    required this.peerCount,
    required this.seedCount,
    required this.downloadCount,
    required this.downloadedCount,
  });

  final String name;
  final String status;
  final int peerCount;
  final int seedCount;
  final int downloadCount;
  final int downloadedCount;

  String get statusLabel => status;
}
```

```dart
// lib/models/qbit_task_peer.dart
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class QBitTaskPeer {
  const QBitTaskPeer({
    required this.address,
    required this.port,
    required this.protocol,
    required this.stateTags,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.downloaded,
    required this.uploaded,
    required this.progress,
    required this.relevance,
  });

  final String address;
  final int port;
  final String protocol;
  final List<String> stateTags;
  final int downloadSpeed;
  final int uploadSpeed;
  final int downloaded;
  final int uploaded;
  final double progress;
  final double relevance;

  String get formattedDownloadSpeed => '${_formatBytes(downloadSpeed)}/s';
  String get formattedUploadSpeed => '${_formatBytes(uploadSpeed)}/s';
  String get formattedDownloaded => _formatBytes(downloaded);
  String get formattedUploaded => _formatBytes(uploaded);
  String get progressLabel => '${(progress * 100).toStringAsFixed(0)}%';
  String get relevanceLabel => 'file affinity ${(relevance * 100).toStringAsFixed(2)}%';
}
```

```dart
// lib/services/qbit/qbit_api_adapter.dart
abstract class QBitApiAdapter {
  Future<DownloadTask?> getTaskDetail(String taskId);
  Future<QBitTaskDetail?> getTaskFullDetail(String taskId);
  Future<List<QBitTaskFileNode>> getTaskFiles(String taskId);
  Future<List<QBitTaskSource>> getTaskSources(String taskId);
  Future<List<QBitTaskPeer>> getTaskPeers(String taskId);
  Future<QBitTaskOptions> getTaskOptions(String taskId);
  Future<void> updateTaskOptions(
    String taskId, {
    required QBitTaskOptions current,
    required QBitTaskOptionsUpdate update,
  });
}
```

```dart
// lib/services/qbit_service.dart
Future<QBitTaskDetail?> getTaskFullDetail(String taskId) async =>
    (await _resolveAdapter()).getTaskFullDetail(taskId);

Future<List<QBitTaskFileNode>> getTaskFiles(String taskId) async =>
    (await _resolveAdapter()).getTaskFiles(taskId);

Future<List<QBitTaskSource>> getTaskSources(String taskId) async =>
    (await _resolveAdapter()).getTaskSources(taskId);

Future<List<QBitTaskPeer>> getTaskPeers(String taskId) async =>
    (await _resolveAdapter()).getTaskPeers(taskId);

Future<QBitTaskOptions> getTaskOptions(String taskId) async =>
    (await _resolveAdapter()).getTaskOptions(taskId);

Future<void> updateTaskOptions(
  String taskId, {
  required QBitTaskOptions current,
  required QBitTaskOptionsUpdate update,
}) async => (await _resolveAdapter()).updateTaskOptions(
      taskId,
      current: current,
      update: update,
    );
```

```dart
// lib/services/qbit/qbit_base_api_adapter.dart
@override
Future<List<QBitTaskSource>> getTaskSources(String taskId) async {
  final body = await session.getText('/api/v2/torrents/trackers?hash=$taskId');
  final List<dynamic> json = jsonDecode(body);
  return json
      .where((item) => (item['url']?.toString() ?? '').startsWith('**'))
      .map(_parseSource)
      .toList();
}

@override
Future<List<QBitTaskPeer>> getTaskPeers(String taskId) async {
  final body =
      await session.getText('/api/v2/sync/torrentPeers?hash=$taskId&rid=0');
  final json = jsonDecode(body) as Map<String, dynamic>;
  final peers = json['peers'] as Map<String, dynamic>? ?? const {};
  return peers.entries
      .map((entry) => _parsePeer(
            key: entry.key,
            raw: entry.value as Map<String, dynamic>,
          ))
      .toList();
}

@override
Future<void> updateTaskOptions(
  String taskId, {
  required QBitTaskOptions current,
  required QBitTaskOptionsUpdate update,
}) async {
  await _applyQueueAction(taskId, update.queueAction);
  await _applyCategory(taskId, current: current.category, next: update.category);
  await _applyTags(taskId, current: current.tags, next: update.tags);
}
```

- [x] **Step 4: Run the adapter tests to verify they pass**

Run: `flutter test test/unit/services/qbit/qbit_task_detail_adapter_test.dart`

Expected: PASS

- [x] **Step 5: Commit the service/model foundation**

```bash
git add lib/models/qbit_task_detail.dart lib/models/qbit_task_file_node.dart lib/models/qbit_task_source.dart lib/models/qbit_task_peer.dart lib/models/qbit_task_options.dart lib/models/qbit_task_options_update.dart lib/services/qbit/qbit_api_adapter.dart lib/services/qbit/qbit_base_api_adapter.dart lib/services/qbit_service.dart test/unit/services/qbit/qbit_task_detail_adapter_test.dart
git commit -m "feat: add qbittorrent task detail data layer"
```

## Task 2: Replace The qBit Generic Detail Fallback With The qBit Info Homepage

**Files:**
- Create: `lib/features/tasks/presentation/controllers/qbit_task_detail_controller.dart`
- Create: `lib/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart`
- Create: `test/widget/qbit_test_helpers.dart`
- Modify: `lib/features/tasks/presentation/pages/task_detail_page.dart`
- Modify: `test/widget/task_detail_route_page_test.dart`
- Test: `test/widget/qbit_task_detail_page_test.dart`

- [x] **Step 1: Write the failing route and homepage widget tests**

```dart
testWidgets('dispatches qbittorrent tasks to QBitTaskDetailPage', (tester) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(
        id: 'qbit-1',
        name: 'Seedbox',
        type: DownloaderType.qbittorrent,
      ),
    ];

  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      taskController: _StubTaskController(),
      child: const TaskDetailPage(
        taskId: 'abc',
        downloaderId: 'qbit-1',
        taskName: 'Three Kingdoms',
      ),
    ),
  );
  await tester.pump();

  expect(find.byType(QBitTaskDetailPage), findsOneWidget);
  expect(find.byType(GenericTaskDetailPage), findsNothing);
});

testWidgets('qBit detail page renders sections and child-page entries', (tester) async {
  await tester.pumpWidget(buildQBitDetailTestApp(
    detail: fakeQBitTaskDetail,
  ));
  await tester.pumpAndSettle();

  expect(find.text('Progress'), findsOneWidget);
  expect(find.text('Transfer'), findsOneWidget);
  expect(find.text('Torrent Info'), findsOneWidget);
  expect(find.text('HTTP Sources'), findsOneWidget);
  expect(find.text('Files'), findsOneWidget);
  expect(find.text('Servers'), findsOneWidget);
  expect(find.text('Peers'), findsOneWidget);
  expect(find.text('Options'), findsOneWidget);
});
```

- [x] **Step 2: Run the route and homepage tests to verify they fail**

Run: `flutter test test/widget/task_detail_route_page_test.dart test/widget/qbit_task_detail_page_test.dart`

Expected: FAIL because `QBitTaskDetailPage` and `QBitTaskDetailController` do not exist, and qBit still routes to `GenericTaskDetailPage`.

- [x] **Step 3: Implement the qBit homepage controller and page**

```dart
// lib/features/tasks/presentation/controllers/qbit_task_detail_controller.dart
typedef QBitServiceFactory = QBitService Function(Downloader downloader);

class QBitTaskDetailController extends ChangeNotifier {
  QBitTaskDetailController({
    QBitServiceFactory? serviceFactory,
  }) : _serviceFactory = serviceFactory ?? ((downloader) => QBitService(downloader));

  final QBitServiceFactory _serviceFactory;
  QBitTaskDetail? _detail;
  bool _isLoading = false;
  String? _errorMessage;

  QBitTaskDetail? get detail => _detail;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({required String taskId, required Downloader downloader}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _detail = await _serviceFactory(downloader).getTaskFullDetail(taskId);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

```dart
// lib/features/tasks/presentation/pages/task_detail_page.dart
case DownloaderType.qbittorrent:
  return QBitTaskDetailPage(
    taskId: taskId,
    downloaderId: downloaderId,
    taskName: taskName,
  );
```

```dart
// lib/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart
class QBitTaskDetailPage extends StatefulWidget {
  const QBitTaskDetailPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final QBitTaskDetailController? controller;
}

return ChangeNotifierProvider<QBitTaskDetailController>.value(
  value: _controller,
  child: TaskDetailShell(
    taskId: widget.taskId,
    downloaderId: widget.downloaderId,
    taskName: widget.taskName,
    detailLoader: _load,
    body: Consumer<QBitTaskDetailController>(
      builder: (context, controller, _) {
        final detail = _matchingDetail(controller.detail);
        return Column(
          children: [
            _ProgressSection(detail: detail),
            const SizedBox(height: 16),
            _TransferSection(detail: detail),
            const SizedBox(height: 16),
            _TorrentInfoSection(detail: detail),
            const SizedBox(height: 16),
            _HttpSourcesSection(detail: detail),
            const SizedBox(height: 16),
            _EntrySection(
              detail: detail,
              onFiles: () => _pushChild(context, 'qbit-task-files'),
              onSources: () => _pushChild(context, 'qbit-task-sources'),
              onPeers: () => _pushChild(context, 'qbit-task-peers'),
              onOptions: () => _pushChild(context, 'qbit-task-options'),
            ),
          ],
        );
      },
    ),
  ),
);
```

```dart
// test/widget/qbit_test_helpers.dart
final fakeQBitDownloader = Downloader(
  id: 'qbit-1',
  name: 'Seedbox',
  type: DownloaderType.qbittorrent,
  host: 'localhost',
  port: 8080,
  username: 'admin',
  password: 'admin',
);

const fakeQBitTaskDetail = QBitTaskDetail(
  taskId: 'abc',
  downloaderId: 'qbit-1',
  name: 'Three Kingdoms',
  progress: 0.12,
  queuePosition: 3,
  category: 'tv',
  tags: ['classic', 'chinese'],
  savePath: '/ptd',
  totalSize: 114390000000,
  fileCount: 95,
  sourceCount: 3,
  peerCount: 30,
  httpSourceCount: 0,
  infoHashV1: 'v1hash',
  infoHashV2: 'v2hash',
);

final fakeQBitFileTree = <QBitTaskFileNode>[
  const QBitTaskFileNode(
    path: 'demo',
    name: 'demo',
    isDirectory: true,
    size: 110,
    downloaded: 10,
    progress: 0.09,
    children: [
      QBitTaskFileNode(
        path: 'demo/subs',
        name: 'subs',
        isDirectory: true,
        size: 10,
        downloaded: 10,
        progress: 1,
        children: [
          QBitTaskFileNode(
            path: 'demo/subs/EP01.srt',
            name: 'EP01.srt',
            isDirectory: false,
            size: 10,
            downloaded: 10,
            progress: 1,
          ),
        ],
      ),
    ],
  ),
];

class FakeQBitService extends QBitService {
  FakeQBitService({
    this.detail = fakeQBitTaskDetail,
    this.files = const [],
    this.sources = const [],
    this.peers = const [],
    this.options,
    this.saveError,
  }) : super(fakeQBitDownloader);

  final QBitTaskDetail detail;
  final List<QBitTaskFileNode> files;
  final List<QBitTaskSource> sources;
  final List<QBitTaskPeer> peers;
  final QBitTaskOptions? options;
  final String? saveError;

  @override
  Future<QBitTaskDetail?> getTaskFullDetail(String taskId) async => detail;

  @override
  Future<List<QBitTaskFileNode>> getTaskFiles(String taskId) async => files;

  @override
  Future<List<QBitTaskSource>> getTaskSources(String taskId) async => sources;

  @override
  Future<List<QBitTaskPeer>> getTaskPeers(String taskId) async => peers;

  @override
  Future<QBitTaskOptions> getTaskOptions(String taskId) async => options!;

  @override
  Future<void> updateTaskOptions(
    String taskId, {
    required QBitTaskOptions current,
    required QBitTaskOptionsUpdate update,
  }) async {
    if (saveError != null) {
      throw DownloaderServiceException(saveError!);
    }
  }
}

Widget buildQBitDetailTestApp({required QBitTaskDetail detail}) {
  return createTestApp(
    downloaderController: MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    child: QBitTaskDetailPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: detail.name,
      controller: QBitTaskDetailController(
        serviceFactory: (_) => FakeQBitService(detail: detail),
      ),
    ),
  );
}

Widget buildQBitFilesTestApp({required List<QBitTaskFileNode> files}) {
  return createTestApp(
    downloaderController: MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    child: QBitTaskFilesPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: 'Three Kingdoms',
      controller: QBitTaskFilesController(
        serviceFactory: (_) => FakeQBitService(files: files),
      ),
    ),
  );
}

Widget buildQBitSourcesTestApp({required List<QBitTaskSource> sources}) {
  return createTestApp(
    downloaderController: MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    child: QBitTaskSourcesPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: 'Three Kingdoms',
      controller: QBitTaskSourcesController(
        serviceFactory: (_) => FakeQBitService(sources: sources),
      ),
    ),
  );
}

Widget buildQBitPeersTestApp({required List<QBitTaskPeer> peers}) {
  return createTestApp(
    downloaderController: MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    child: QBitTaskPeersPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: 'Three Kingdoms',
      controller: QBitTaskPeersController(
        serviceFactory: (_) => FakeQBitService(peers: peers),
      ),
    ),
  );
}

Widget buildQBitOptionsTestApp({required QBitTaskOptions options}) {
  return createTestApp(
    downloaderController: MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    child: QBitTaskOptionsPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: 'Three Kingdoms',
      controller: QBitTaskOptionsController(
        serviceFactory: (_) => FakeQBitService(options: options),
      ),
    ),
  );
}

Widget buildQBitRouterTestApp() {
  final router = GoRouter(
    initialLocation: '/tasks/detail/abc?downloaderId=qbit-1&taskName=Three%20Kingdoms',
    routes: [
      GoRoute(
        path: '/tasks',
        builder: (_, __) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'detail/:id',
            builder: (context, state) => TaskDetailPage(
              taskId: state.pathParameters['id']!,
              downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
              taskName: state.uri.queryParameters['taskName'] ?? '',
            ),
            routes: [
              GoRoute(
                path: 'qbit/files',
                builder: (context, state) => QBitTaskFilesPage(
                  taskId: state.pathParameters['id']!,
                  downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                  taskName: state.uri.queryParameters['taskName'] ?? '',
                  controller: QBitTaskFilesController(
                    serviceFactory: (_) => FakeQBitService(files: fakeQBitFileTree),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DownloaderController>.value(
        value: MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
      ),
      ChangeNotifierProvider<TaskController>.value(value: _StubTaskController()),
      ChangeNotifierProvider<SettingsController>(create: (_) => SettingsController()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
    ),
  );
}

class _StubTaskController extends TaskController {
  @override
  Future<void> loadTaskDetailForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController,
  ) async {}
}
```

- [x] **Step 4: Run the route and homepage tests to verify they pass**

Run: `flutter test test/widget/task_detail_route_page_test.dart test/widget/qbit_task_detail_page_test.dart`

Expected: PASS

- [x] **Step 5: Commit the qBit homepage swap**

```bash
git add lib/features/tasks/presentation/controllers/qbit_task_detail_controller.dart lib/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart lib/features/tasks/presentation/pages/task_detail_page.dart test/widget/task_detail_route_page_test.dart test/widget/qbit_task_detail_page_test.dart
git commit -m "feat: add qbittorrent task detail homepage"
```

## Task 3: Build The Read-Only qBit Files Tree Page

**Files:**
- Create: `lib/features/tasks/presentation/controllers/qbit_task_files_controller.dart`
- Create: `lib/features/tasks/presentation/pages/qbit/qbit_task_files_page.dart`
- Create: `lib/features/tasks/presentation/widgets/qbit_file_tree_node.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/widget/qbit_task_files_page_test.dart`

- [x] **Step 1: Write the failing files-page tests**

```dart
testWidgets('tapping Files opens the qBit files page', (tester) async {
  await tester.pumpWidget(buildQBitRouterTestApp());
  await tester.pumpAndSettle();

  final filesEntry = find.ancestor(
    of: find.text('Files'),
    matching: find.byType(TaskDetailEntryCard),
  );
  await tester.ensureVisible(filesEntry);
  await tester.tap(filesEntry, warnIfMissed: false);
  await tester.pumpAndSettle();

  expect(find.byType(QBitTaskFilesPage), findsOneWidget);
});

testWidgets('qBit files page renders expandable directory tree', (tester) async {
  await tester.pumpWidget(buildQBitFilesTestApp(
    files: fakeQBitFileTree,
  ));
  await tester.pumpAndSettle();

  expect(find.text('demo'), findsOneWidget);
  expect(find.text('subs'), findsNothing);

  await tester.tap(find.text('demo'));
  await tester.pumpAndSettle();

  expect(find.text('subs'), findsOneWidget);
  expect(find.text('EP01.srt'), findsOneWidget);
});
```

- [x] **Step 2: Run the files-page tests to verify they fail**

Run: `flutter test test/widget/qbit_task_files_page_test.dart`

Expected: FAIL because the qBit files route, page, controller, and tree widget do not exist.

- [x] **Step 3: Implement the files controller, page, and tree node widget**

```dart
// lib/features/tasks/presentation/controllers/qbit_task_files_controller.dart
class QBitTaskFilesController extends ChangeNotifier {
  QBitTaskFilesController({QBitServiceFactory? serviceFactory})
      : _serviceFactory = serviceFactory ?? ((downloader) => QBitService(downloader));

  final QBitServiceFactory _serviceFactory;
  final Set<String> _expandedPaths = <String>{};
  List<QBitTaskFileNode> _files = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<QBitTaskFileNode> get files => _files;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool isExpanded(String path) => _expandedPaths.contains(path);

  void toggle(String path) {
    if (!_expandedPaths.add(path)) {
      _expandedPaths.remove(path);
    }
    notifyListeners();
  }
}
```

```dart
// lib/core/router/app_router.dart
GoRoute(
  path: 'qbit/files',
  name: 'qbit-task-files',
  builder: (context, state) => QBitTaskFilesPage(
    taskId: state.pathParameters['id']!,
    downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
    taskName: state.uri.queryParameters['taskName'] ?? '',
  ),
),
```

```dart
// lib/features/tasks/presentation/pages/qbit/qbit_task_files_page.dart
class QBitTaskFilesPage extends StatefulWidget {
  const QBitTaskFilesPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final QBitTaskFilesController? controller;
}

// lib/features/tasks/presentation/widgets/qbit_file_tree_node.dart
class QBitFileTreeNode extends StatelessWidget {
  const QBitFileTreeNode({
    super.key,
    required this.node,
    required this.depth,
  });

  final QBitTaskFileNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QBitTaskFilesController>();
    final expanded = node.isDirectory && controller.isExpanded(node.path);

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: 12.0 + depth * 16.0, right: 8),
          leading: Icon(node.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file_rounded),
          title: Text(node.name),
          subtitle: Text('${node.formattedSize}  ${node.progressLabel}'),
          trailing: node.isDirectory
              ? Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded)
              : null,
          onTap: node.isDirectory ? () => controller.toggle(node.path) : null,
        ),
        if (expanded)
          for (final child in node.children)
            QBitFileTreeNode(node: child, depth: depth + 1),
      ],
    );
  }
}
```

- [x] **Step 4: Run the files-page tests to verify they pass**

Run: `flutter test test/widget/qbit_task_files_page_test.dart`

Expected: PASS

- [x] **Step 5: Commit the qBit files page**

```bash
git add lib/features/tasks/presentation/controllers/qbit_task_files_controller.dart lib/features/tasks/presentation/pages/qbit/qbit_task_files_page.dart lib/features/tasks/presentation/widgets/qbit_file_tree_node.dart lib/core/router/app_router.dart test/widget/qbit_task_files_page_test.dart
git commit -m "feat: add qbittorrent files tree page"
```

## Task 4: Build The Read-Only qBit Sources And Peers Pages

**Files:**
- Create: `lib/features/tasks/presentation/controllers/qbit_task_sources_controller.dart`
- Create: `lib/features/tasks/presentation/controllers/qbit_task_peers_controller.dart`
- Create: `lib/features/tasks/presentation/pages/qbit/qbit_task_sources_page.dart`
- Create: `lib/features/tasks/presentation/pages/qbit/qbit_task_peers_page.dart`
- Create: `lib/features/tasks/presentation/widgets/qbit_source_card.dart`
- Create: `lib/features/tasks/presentation/widgets/qbit_peer_row.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/widget/qbit_task_sources_page_test.dart`
- Test: `test/widget/qbit_task_peers_page_test.dart`

- [x] **Step 1: Write the failing sources and peers tests**

```dart
testWidgets('qBit sources page renders source cards', (tester) async {
  await tester.pumpWidget(buildQBitSourcesTestApp(
    sources: const [
      QBitTaskSource(
        name: 'DHT',
        status: 'working',
        peerCount: 0,
        seedCount: 0,
        downloadCount: 0,
        downloadedCount: 0,
      ),
    ],
  ));
  await tester.pumpAndSettle();

  expect(find.text('DHT'), findsOneWidget);
  expect(find.text('working'), findsOneWidget);
});

// Before implementing parser logic, capture one real `/api/v2/sync/torrentPeers`
// response from a supported qBit server and store two fixtures:
// one `rid=0` full snapshot for the page parser and one incremental sample
// with `peers_removed`, because the local 4.1 / 5.0 docs do not define the
// response schema beyond the endpoint name itself.
testWidgets('qBit peers page renders dense peer rows', (tester) async {
  await tester.pumpWidget(buildQBitPeersTestApp(
    peers: const [
      QBitTaskPeer(
        address: '1.1.1.1',
        port: 51413,
        protocol: 'BT',
        stateTags: ['H', 'X'],
        downloadSpeed: 0,
        uploadSpeed: 12800,
        downloaded: 0,
        uploaded: 2048,
        progress: 0.31,
        relevance: 0.0002,
      ),
    ],
  ));
  await tester.pumpAndSettle();

  expect(find.text('1.1.1.1:51413'), findsOneWidget);
  expect(find.text('BT'), findsOneWidget);
  expect(find.text('H'), findsOneWidget);
  expect(find.text('X'), findsOneWidget);
});
```

- [x] **Step 2: Run the sources and peers tests to verify they fail**

Run: `flutter test test/widget/qbit_task_sources_page_test.dart test/widget/qbit_task_peers_page_test.dart`

Expected: FAIL because the qBit sources/peers pages and widgets do not exist.

- [x] **Step 3: Implement the qBit sources and peers pages**

```dart
// lib/core/router/app_router.dart
GoRoute(
  path: 'qbit/sources',
  name: 'qbit-task-sources',
  builder: (context, state) => QBitTaskSourcesPage(
    taskId: state.pathParameters['id']!,
    downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
    taskName: state.uri.queryParameters['taskName'] ?? '',
  ),
),
GoRoute(
  path: 'qbit/peers',
  name: 'qbit-task-peers',
  builder: (context, state) => QBitTaskPeersPage(
    taskId: state.pathParameters['id']!,
    downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
    taskName: state.uri.queryParameters['taskName'] ?? '',
  ),
),
```

```dart
// lib/features/tasks/presentation/pages/qbit/qbit_task_sources_page.dart
class QBitTaskSourcesPage extends StatefulWidget {
  const QBitTaskSourcesPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final QBitTaskSourcesController? controller;
}

// lib/features/tasks/presentation/widgets/qbit_source_card.dart
class QBitSourceCard extends StatelessWidget {
  const QBitSourceCard({super.key, required this.source});

  final QBitTaskSource source;

  @override
  Widget build(BuildContext context) {
    return NeoSection(
      title: source.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeoBadge(label: source.statusLabel),
          const SizedBox(height: 12),
          Text('Peers: ${source.peerCount}'),
          Text('Seeds: ${source.seedCount}'),
          Text('Downloads: ${source.downloadCount}'),
          Text('Downloaded: ${source.downloadedCount}'),
        ],
      ),
    );
  }
}
```

```dart
// lib/features/tasks/presentation/pages/qbit/qbit_task_peers_page.dart
class QBitTaskPeersPage extends StatefulWidget {
  const QBitTaskPeersPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final QBitTaskPeersController? controller;
}

// lib/features/tasks/presentation/widgets/qbit_peer_row.dart
class QBitPeerRow extends StatelessWidget {
  const QBitPeerRow({super.key, required this.peer});

  final QBitTaskPeer peer;

  @override
  Widget build(BuildContext context) {
    return NeoSection(
      title: '${peer.address}:${peer.port}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, children: [
            NeoBadge(label: peer.protocol),
            for (final tag in peer.stateTags) NeoBadge(label: tag),
          ]),
          const SizedBox(height: 12),
          Text('↓ ${peer.formattedDownloadSpeed}   ↑ ${peer.formattedUploadSpeed}'),
          Text('${peer.formattedDownloaded} / ${peer.formattedUploaded}'),
          Text('${peer.progressLabel} · ${peer.relevanceLabel}'),
        ],
      ),
    );
  }
}
```

- [x] **Step 4: Run the sources and peers tests to verify they pass**

Run: `flutter test test/widget/qbit_task_sources_page_test.dart test/widget/qbit_task_peers_page_test.dart`

Expected: PASS

- [x] **Step 5: Commit the qBit sources and peers pages**

```bash
git add lib/features/tasks/presentation/controllers/qbit_task_sources_controller.dart lib/features/tasks/presentation/controllers/qbit_task_peers_controller.dart lib/features/tasks/presentation/pages/qbit/qbit_task_sources_page.dart lib/features/tasks/presentation/pages/qbit/qbit_task_peers_page.dart lib/features/tasks/presentation/widgets/qbit_source_card.dart lib/features/tasks/presentation/widgets/qbit_peer_row.dart lib/core/router/app_router.dart test/widget/qbit_task_sources_page_test.dart test/widget/qbit_task_peers_page_test.dart
git commit -m "feat: add qbittorrent sources and peers pages"
```

## Task 5: Build The Editable qBit Options Page And Final Regression Coverage

**Files:**
- Create: `lib/features/tasks/presentation/controllers/qbit_task_options_controller.dart`
- Create: `lib/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart`
- Create: `lib/features/tasks/presentation/widgets/qbit_options_form.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_ja.arb`
- Test: `test/unit/qbit_task_options_controller_test.dart`
- Test: `test/widget/qbit_task_options_page_test.dart`

- [x] **Step 1: Write the failing options tests**

```dart
test('options controller only saves dirty changes and preserves input on failure', () async {
  final controller = QBitTaskOptionsController(
    serviceFactory: (_) => FakeQBitService(
      options: const QBitTaskOptions(
        queuePosition: 3,
        category: 'tv',
        tags: ['classic'],
        availableCategories: ['tv', 'movie'],
        availableTags: ['classic', 'favorite'],
      ),
      saveError: 'save failed',
    ),
  );

  await controller.load(taskId: 'abc', downloader: fakeQBitDownloader);
  controller.updateQueueAction(QBitQueuePriorityAction.top);
  controller.updateCategory('movie');
  controller.updateTags(['classic', 'favorite']);

  expect(controller.isDirty, isTrue);

  await controller.save(taskId: 'abc', downloader: fakeQBitDownloader);

  expect(controller.errorMessage, 'save failed');
  expect(controller.categoryDraft, 'movie');
  expect(controller.tagDrafts, ['classic', 'favorite']);
});

test('queue action is disabled when qBit reports queue position -1', () async {
  final controller = QBitTaskOptionsController(
    serviceFactory: (_) => FakeQBitService(
      options: const QBitTaskOptions(
        queuePosition: -1,
        category: 'tv',
        tags: ['classic'],
        availableCategories: ['tv'],
        availableTags: ['classic'],
      ),
    ),
  );

  await controller.load(taskId: 'abc', downloader: fakeQBitDownloader);

  expect(controller.queueActionsEnabled, isFalse);
});

testWidgets('options page enables save only when form is dirty', (tester) async {
  await tester.pumpWidget(buildQBitOptionsTestApp(
    options: const QBitTaskOptions(
      queuePosition: 3,
      category: 'tv',
      tags: ['classic'],
      availableCategories: ['tv', 'movie'],
      availableTags: ['classic', 'favorite'],
    ),
  ));
  await tester.pumpAndSettle();

  final saveButton = find.widgetWithText(FilledButton, 'Save');
  expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

  await tester.tap(find.text('Top of queue'));
  await tester.pumpAndSettle();

  expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
});
```

- [x] **Step 2: Run the options tests to verify they fail**

Run: `flutter test test/unit/qbit_task_options_controller_test.dart test/widget/qbit_task_options_page_test.dart`

Expected: FAIL because the qBit options controller, form, and page do not exist.

- [x] **Step 3: Implement the options controller, page, localization, and save flow**

```dart
// lib/features/tasks/presentation/controllers/qbit_task_options_controller.dart
class QBitTaskOptionsController extends ChangeNotifier {
  QBitTaskOptionsController({QBitServiceFactory? serviceFactory})
      : _serviceFactory = serviceFactory ?? ((downloader) => QBitService(downloader));

  final QBitServiceFactory _serviceFactory;
  QBitTaskOptions? _initial;
  QBitQueuePriorityAction _queueAction = QBitQueuePriorityAction.unchanged;
  String _categoryDraft = '';
  List<String> _tagDrafts = const [];
  bool _isSaving = false;
  String? _errorMessage;

  QBitQueuePriorityAction get queueAction => _queueAction;
  String get categoryDraft => _categoryDraft;
  List<String> get tagDrafts => _tagDrafts;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get queueActionsEnabled => (_initial?.queuePosition ?? -1) >= 0;

  Future<void> load({required String taskId, required Downloader downloader}) async {
    _initial = await _serviceFactory(downloader).getTaskOptions(taskId);
    _queueAction = QBitQueuePriorityAction.unchanged;
    _categoryDraft = _initial!.category;
    _tagDrafts = List<String>.from(_initial!.tags);
    _errorMessage = null;
    notifyListeners();
  }

  void updateQueueAction(QBitQueuePriorityAction value) {
    if (!queueActionsEnabled && value != QBitQueuePriorityAction.unchanged) {
      return;
    }
    _queueAction = value;
    notifyListeners();
  }

  void updateCategory(String value) {
    _categoryDraft = value.trim();
    notifyListeners();
  }

  void updateTags(List<String> value) {
    _tagDrafts = value;
    notifyListeners();
  }

  bool get isDirty =>
      _queueAction != QBitQueuePriorityAction.unchanged ||
      _categoryDraft != (_initial?.category ?? '') ||
      !listEquals(_tagDrafts, _initial?.tags ?? const []);

  Future<void> save({required String taskId, required Downloader downloader}) async {
    if (_initial == null || !isDirty) return;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _serviceFactory(downloader).updateTaskOptions(
        taskId,
        current: _initial!,
        update: QBitTaskOptionsUpdate(
          queueAction: _queueAction,
          category: _categoryDraft,
          tags: _tagDrafts,
        ),
      );
      _initial = _initial!.copyWith(category: _categoryDraft, tags: _tagDrafts, queuePosition: _initial!.queuePosition);
      _queueAction = QBitQueuePriorityAction.unchanged;
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
```

```dart
// lib/core/router/app_router.dart
GoRoute(
  path: 'qbit/options',
  name: 'qbit-task-options',
  builder: (context, state) => QBitTaskOptionsPage(
    taskId: state.pathParameters['id']!,
    downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
    taskName: state.uri.queryParameters['taskName'] ?? '',
  ),
),
```

```dart
// lib/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart
class QBitTaskOptionsPage extends StatefulWidget {
  const QBitTaskOptionsPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    this.controller,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final QBitTaskOptionsController? controller;
}

// lib/features/tasks/presentation/widgets/qbit_options_form.dart
String _queueActionLabel(AppLocalizations l10n, QBitQueuePriorityAction action) {
  return switch (action) {
    QBitQueuePriorityAction.unchanged => l10n.qbitQueueActionUnchanged,
    QBitQueuePriorityAction.increase => l10n.qbitQueueActionIncrease,
    QBitQueuePriorityAction.decrease => l10n.qbitQueueActionDecrease,
    QBitQueuePriorityAction.top => l10n.qbitQueueActionTop,
    QBitQueuePriorityAction.bottom => l10n.qbitQueueActionBottom,
  };
}

Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(l10n.qbitQueuePriorityTitle),
    Wrap(
      spacing: 8,
      children: QBitQueuePriorityAction.values.map((action) {
        return ChoiceChip(
          label: Text(_queueActionLabel(l10n, action)),
          selected: controller.queueAction == action,
          onSelected: controller.queueActionsEnabled
              ? (_) => controller.updateQueueAction(action)
              : null,
        );
      }).toList(),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: categoryController,
      decoration: InputDecoration(
        labelText: l10n.qbitCategoryLabel,
        helperText: l10n.qbitCategoryHelper,
      ),
      onChanged: controller.updateCategory,
    ),
    const SizedBox(height: 16),
    TextField(
      controller: tagsController,
      decoration: InputDecoration(
        labelText: l10n.qbitTagsLabel,
        helperText: l10n.qbitTagsHelper,
      ),
      onChanged: (value) => controller.updateTags(
        value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
      ),
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: controller.isDirty && !controller.isSaving ? onSave : null,
      child: Text(l10n.save),
    ),
  ],
)
```

```json
// lib/l10n/app_en.arb
{
  "qbitQueuePriorityTitle": "Queue priority",
  "qbitQueueActionUnchanged": "No change",
  "qbitQueueActionTop": "Top of queue",
  "qbitQueueActionIncrease": "Move up",
  "qbitQueueActionDecrease": "Move down",
  "qbitQueueActionBottom": "Bottom of queue",
  "qbitCategoryLabel": "Category",
  "qbitCategoryHelper": "Choose an existing category or type a new one",
  "qbitTagsLabel": "Tags",
  "qbitTagsHelper": "Separate tags with commas",
  "qbitOptionsSaved": "Options saved"
}
```

- [x] **Step 4: Run l10n generation and the options tests**

Run: `flutter gen-l10n`

Expected: PASS with regenerated localization classes.

Run: `flutter test test/unit/qbit_task_options_controller_test.dart test/widget/qbit_task_options_page_test.dart test/widget/qbit_task_detail_page_test.dart test/widget/qbit_task_files_page_test.dart test/widget/qbit_task_sources_page_test.dart test/widget/qbit_task_peers_page_test.dart test/widget/task_detail_route_page_test.dart test/unit/services/qbit/qbit_task_detail_adapter_test.dart`

Expected: PASS

- [x] **Step 5: Commit the qBit options page and regression suite**

```bash
git add lib/features/tasks/presentation/controllers/qbit_task_options_controller.dart lib/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart lib/features/tasks/presentation/widgets/qbit_options_form.dart lib/core/router/app_router.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart test/unit/qbit_task_options_controller_test.dart test/widget/qbit_task_options_page_test.dart test/widget/qbit_task_detail_page_test.dart test/widget/qbit_task_files_page_test.dart test/widget/qbit_task_sources_page_test.dart test/widget/qbit_task_peers_page_test.dart test/widget/task_detail_route_page_test.dart test/unit/services/qbit/qbit_task_detail_adapter_test.dart
git commit -m "feat: add qbittorrent task detail child pages"
```
