# Transmission Child Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build real Transmission `文件 / 服务器 / 节点 / 选项` child pages on top of the existing Transmission detail shell, with read-only files/trackers/peers pages and an editable options page.

**Architecture:** Add Transmission-specific child-page models and RPC methods instead of overloading `TransmissionTaskDetail`. Each child page gets a focused controller so files, trackers, peers, and options can load, refresh, and error independently while reusing `TaskDetailShell`. The options page uses explicit save with task-level `torrent-set` updates, while the other three pages remain read-only.

**Tech Stack:** Flutter 3.24.5, Provider, go_router, Flutter l10n, widget tests, unit tests

---

## File Structure

### Create

- `lib/models/transmission_task_file_node.dart`
  Tree node model for the read-only files page.
- `lib/models/transmission_task_tracker.dart`
  Tracker card model for the “服务器” page.
- `lib/models/transmission_task_peer.dart`
  Peer row model for the “节点” page.
- `lib/models/transmission_task_options.dart`
  Read model for task-level Transmission options.
- `lib/models/transmission_task_options_update.dart`
  Write payload for saving editable Transmission options.
- `lib/features/tasks/presentation/controllers/transmission_task_files_controller.dart`
  Files page state, including `expandedPaths`.
- `lib/features/tasks/presentation/controllers/transmission_task_trackers_controller.dart`
  Trackers page state.
- `lib/features/tasks/presentation/controllers/transmission_task_peers_controller.dart`
  Peers page state.
- `lib/features/tasks/presentation/controllers/transmission_task_options_controller.dart`
  Options page load/save/dirty-state controller.
- `lib/features/tasks/presentation/widgets/transmission_file_tree_node.dart`
  Recursive read-only file tree row widget.
- `lib/features/tasks/presentation/widgets/transmission_tracker_card.dart`
  Tracker card widget.
- `lib/features/tasks/presentation/widgets/transmission_peer_row.dart`
  Peer row widget.
- `lib/features/tasks/presentation/widgets/transmission_options_form.dart`
  Task-level options form sections and save action.
- `test/unit/transmission_task_child_data_test.dart`
  Adapter parsing coverage for files, trackers, peers, and options.
- `test/unit/transmission_task_options_controller_test.dart`
  Options dirty-state and save tests.
- `test/widget/transmission_task_files_page_test.dart`
- `test/widget/transmission_task_trackers_page_test.dart`
- `test/widget/transmission_task_peers_page_test.dart`
- `test/widget/transmission_task_options_page_test.dart`

### Modify

- `lib/services/transmission/transmission_rpc_adapter.dart`
  Add child-page read/write methods.
- `lib/services/transmission/transmission_modern_rpc_adapter.dart`
  Map snake_case child-page payloads and `torrent_set`.
- `lib/services/transmission/transmission_legacy_rpc_adapter.dart`
  Map legacy camelCase child-page payloads and `torrent-set`.
- `lib/services/transmission_service.dart`
  Expose child-page service methods.
- `lib/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart`
- `lib/features/tasks/presentation/pages/transmission/transmission_task_trackers_page.dart`
- `lib/features/tasks/presentation/pages/transmission/transmission_task_peers_page.dart`
- `lib/features/tasks/presentation/pages/transmission/transmission_task_options_page.dart`
  Replace placeholder shells with real child-page UIs.
- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_ja.arb`
  Add strings for child-page summaries, form labels, validation, and save feedback.

## Task 1: Add Child-Page Models And Transmission RPC Methods

**Files:**
- Create: `lib/models/transmission_task_file_node.dart`
- Create: `lib/models/transmission_task_tracker.dart`
- Create: `lib/models/transmission_task_peer.dart`
- Create: `lib/models/transmission_task_options.dart`
- Create: `lib/models/transmission_task_options_update.dart`
- Modify: `lib/services/transmission/transmission_rpc_adapter.dart`
- Modify: `lib/services/transmission/transmission_modern_rpc_adapter.dart`
- Modify: `lib/services/transmission/transmission_legacy_rpc_adapter.dart`
- Modify: `lib/services/transmission_service.dart`
- Test: `test/unit/transmission_task_child_data_test.dart`

- [x] **Step 1: Write the failing parser tests**

```dart
test('modern adapter maps files into a directory tree input list', () async {
  final adapter = buildModernAdapter(response: {
    'torrents': [
      {
        'id': 7,
        'name': 'demo',
        'files': [
          {'name': 'demo/video/a.mkv', 'length': 100, 'bytes_completed': 100},
          {'name': 'demo/subs/a.srt', 'length': 10, 'bytes_completed': 5},
        ],
      }
    ],
  });

  final files = await adapter.getTaskFiles('7');

  expect(files.length, 2);
  expect(files.first.path, 'demo/video/a.mkv');
  expect(files.last.progress, 0.5);
});

test('modern adapter maps trackers, peers, and options', () async {
  final adapter = buildModernAdapter(response: {
    'torrents': [
      {
        'id': 7,
        'trackers': [
          {
            'id': 1,
            'announce': 'https://tracker.example/announce',
            'sitename': 'tracker.example',
            'tier': 1,
            'last_announce_time': 1710000000,
            'next_announce_time': 1710000600,
            'last_scrape_time': 1710000300,
            'seeder_count': 200,
            'leecher_count': 20,
            'download_count': 50,
          }
        ],
        'peers': [
          {
            'address': '1.1.1.1',
            'client_name': 'qBittorrent/4.3.8',
            'port': 42032,
            'progress': 0.31,
            'rate_to_client': 0,
            'rate_to_peer': 12800,
          }
        ],
        'bandwidth_priority': 0,
        'honors_session_limits': true,
        'download_limited': true,
        'download_limit': 100,
        'upload_limited': true,
        'upload_limit': 3000,
        'seed_ratio_mode': 0,
        'seed_ratio_limit': 0,
        'idle_seeding_limit_mode': 0,
        'idle_seeding_limit': 0,
      }
    ]
  });

  final trackers = await adapter.getTaskTrackers('7');
  final peers = await adapter.getTaskPeers('7');
  final options = await adapter.getTaskOptions('7');

  expect(trackers.single.tier, 1);
  expect(peers.single.clientName, 'qBittorrent/4.3.8');
  expect(options.downloadLimitKBps, 100);
});
```

- [x] **Step 2: Run the parser tests to verify they fail**

Run: `flutter test test/unit/transmission_task_child_data_test.dart`

Expected: FAIL with undefined method/class errors for:

- `getTaskFiles`
- `getTaskTrackers`
- `getTaskPeers`
- `getTaskOptions`
- child-page models

- [x] **Step 3: Write the minimal models and service methods**

```dart
// lib/models/transmission_task_file_node.dart
class TransmissionTaskFileNode {
  const TransmissionTaskFileNode({
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
  final List<TransmissionTaskFileNode> children;
}
```

```dart
// lib/models/transmission_task_tracker.dart
class TransmissionTaskTracker {
  const TransmissionTaskTracker({
    required this.id,
    required this.host,
    required this.announce,
    required this.tier,
    this.lastAnnounceAt,
    this.nextAnnounceAt,
    this.lastScrapeAt,
    this.seederCount = 0,
    this.leecherCount = 0,
    this.downloadCount = 0,
    this.status,
    this.errorMessage,
  });

  final int id;
  final String host;
  final String announce;
  final int tier;
  final DateTime? lastAnnounceAt;
  final DateTime? nextAnnounceAt;
  final DateTime? lastScrapeAt;
  final int seederCount;
  final int leecherCount;
  final int downloadCount;
  final String? status;
  final String? errorMessage;
}
```

```dart
// lib/models/transmission_task_peer.dart
class TransmissionTaskPeer {
  const TransmissionTaskPeer({
    required this.address,
    required this.clientName,
    required this.port,
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.isDownloadingToUs,
    required this.isUploadingFromUs,
  });

  final String address;
  final String clientName;
  final int port;
  final double progress;
  final int downloadSpeed;
  final int uploadSpeed;
  final bool isDownloadingToUs;
  final bool isUploadingFromUs;
}
```

```dart
// lib/models/transmission_task_options.dart
enum TransmissionLimitMode { global, disabled, custom }

class TransmissionTaskOptions {
  const TransmissionTaskOptions({
    required this.bandwidthPriority,
    required this.honorsSessionLimits,
    required this.downloadLimited,
    required this.downloadLimitKBps,
    required this.uploadLimited,
    required this.uploadLimitKBps,
    required this.seedRatioMode,
    required this.seedRatioLimit,
    required this.idleLimitMode,
    required this.idleLimitMinutes,
  });

  final int bandwidthPriority;
  final bool honorsSessionLimits;
  final bool downloadLimited;
  final int downloadLimitKBps;
  final bool uploadLimited;
  final int uploadLimitKBps;
  final TransmissionLimitMode seedRatioMode;
  final double seedRatioLimit;
  final TransmissionLimitMode idleLimitMode;
  final int idleLimitMinutes;

  TransmissionTaskOptions copyWith({
    int? bandwidthPriority,
    bool? honorsSessionLimits,
    bool? downloadLimited,
    int? downloadLimitKBps,
    bool? uploadLimited,
    int? uploadLimitKBps,
    TransmissionLimitMode? seedRatioMode,
    double? seedRatioLimit,
    TransmissionLimitMode? idleLimitMode,
    int? idleLimitMinutes,
  }) {
    return TransmissionTaskOptions(
      bandwidthPriority: bandwidthPriority ?? this.bandwidthPriority,
      honorsSessionLimits: honorsSessionLimits ?? this.honorsSessionLimits,
      downloadLimited: downloadLimited ?? this.downloadLimited,
      downloadLimitKBps: downloadLimitKBps ?? this.downloadLimitKBps,
      uploadLimited: uploadLimited ?? this.uploadLimited,
      uploadLimitKBps: uploadLimitKBps ?? this.uploadLimitKBps,
      seedRatioMode: seedRatioMode ?? this.seedRatioMode,
      seedRatioLimit: seedRatioLimit ?? this.seedRatioLimit,
      idleLimitMode: idleLimitMode ?? this.idleLimitMode,
      idleLimitMinutes: idleLimitMinutes ?? this.idleLimitMinutes,
    );
  }
}
```

```dart
// lib/models/transmission_task_options_update.dart
class TransmissionTaskOptionsUpdate {
  const TransmissionTaskOptionsUpdate({
    required this.bandwidthPriority,
    required this.honorsSessionLimits,
    required this.downloadLimited,
    required this.downloadLimitKBps,
    required this.uploadLimited,
    required this.uploadLimitKBps,
    required this.seedRatioMode,
    required this.seedRatioLimit,
    required this.idleLimitMode,
    required this.idleLimitMinutes,
  });

  final int bandwidthPriority;
  final bool honorsSessionLimits;
  final bool downloadLimited;
  final int downloadLimitKBps;
  final bool uploadLimited;
  final int uploadLimitKBps;
  final TransmissionLimitMode seedRatioMode;
  final double seedRatioLimit;
  final TransmissionLimitMode idleLimitMode;
  final int idleLimitMinutes;

  factory TransmissionTaskOptionsUpdate.fromOptions(
    TransmissionTaskOptions options,
  ) {
    return TransmissionTaskOptionsUpdate(
      bandwidthPriority: options.bandwidthPriority,
      honorsSessionLimits: options.honorsSessionLimits,
      downloadLimited: options.downloadLimited,
      downloadLimitKBps: options.downloadLimitKBps,
      uploadLimited: options.uploadLimited,
      uploadLimitKBps: options.uploadLimitKBps,
      seedRatioMode: options.seedRatioMode,
      seedRatioLimit: options.seedRatioLimit,
      idleLimitMode: options.idleLimitMode,
      idleLimitMinutes: options.idleLimitMinutes,
    );
  }
}
```

```dart
// lib/services/transmission/transmission_rpc_adapter.dart
abstract class TransmissionRpcAdapter {
  Future<List<TransmissionTaskFileNode>> getTaskFiles(String taskId);
  Future<List<TransmissionTaskTracker>> getTaskTrackers(String taskId);
  Future<List<TransmissionTaskPeer>> getTaskPeers(String taskId);
  Future<TransmissionTaskOptions> getTaskOptions(String taskId);
  Future<void> updateTaskOptions(
    String taskId,
    TransmissionTaskOptionsUpdate update,
  );
}
```

```dart
// lib/services/transmission_service.dart
Future<List<TransmissionTaskFileNode>> getTaskFiles(String taskId) async =>
    (await _getAdapter()).getTaskFiles(taskId);

Future<List<TransmissionTaskTracker>> getTaskTrackers(String taskId) async =>
    (await _getAdapter()).getTaskTrackers(taskId);

Future<List<TransmissionTaskPeer>> getTaskPeers(String taskId) async =>
    (await _getAdapter()).getTaskPeers(taskId);

Future<TransmissionTaskOptions> getTaskOptions(String taskId) async =>
    (await _getAdapter()).getTaskOptions(taskId);

Future<void> updateTaskOptions(
  String taskId,
  TransmissionTaskOptionsUpdate update,
) async =>
    (await _getAdapter()).updateTaskOptions(taskId, update);
```

- [x] **Step 4: Run the parser tests to verify they pass**

Run: `flutter test test/unit/transmission_task_child_data_test.dart`

Expected: PASS with files, trackers, peers, and options parsing covered for modern and legacy adapters.

- [x] **Step 5: Commit**

```bash
git add lib/models/transmission_task_file_node.dart \
  lib/models/transmission_task_tracker.dart \
  lib/models/transmission_task_peer.dart \
  lib/models/transmission_task_options.dart \
  lib/models/transmission_task_options_update.dart \
  lib/services/transmission/transmission_rpc_adapter.dart \
  lib/services/transmission/transmission_modern_rpc_adapter.dart \
  lib/services/transmission/transmission_legacy_rpc_adapter.dart \
  lib/services/transmission_service.dart \
  test/unit/transmission_task_child_data_test.dart
git commit -m "feat: add transmission child page data models"
```

## Task 2: Build The Read-Only Files Page

**Files:**
- Create: `lib/features/tasks/presentation/controllers/transmission_task_files_controller.dart`
- Create: `lib/features/tasks/presentation/widgets/transmission_file_tree_node.dart`
- Modify: `lib/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart`
- Test: `test/widget/transmission_task_files_page_test.dart`

- [x] **Step 1: Write the failing files page widget test**

```dart
testWidgets('renders a read-only directory tree with expandable folders', (
  tester,
) async {
  final controller = TransmissionTaskFilesController(
    serviceFactory: (_) => FakeTransmissionService.files([
      const TransmissionTaskFileNode(
        path: 'demo',
        name: 'demo',
        isDirectory: true,
        size: 110,
        downloaded: 105,
        progress: 0.95,
        children: [
          TransmissionTaskFileNode(
            path: 'demo/video/a.mkv',
            name: 'a.mkv',
            isDirectory: false,
            size: 100,
            downloaded: 100,
            progress: 1,
          ),
        ],
      ),
    ]),
  );

  await tester.pumpWidget(buildFilesPage(controller));
  await tester.pump();

  expect(find.text('demo'), findsOneWidget);
  expect(find.text('a.mkv'), findsNothing);

  await tester.tap(find.text('demo'));
  await tester.pump();

  expect(find.text('a.mkv'), findsOneWidget);
});
```

- [x] **Step 2: Run the files page test to verify it fails**

Run: `flutter test test/widget/transmission_task_files_page_test.dart`

Expected: FAIL with missing controller/widget errors for the real tree page.

- [x] **Step 3: Implement the files controller and tree UI**

```dart
class TransmissionTaskFilesController extends ChangeNotifier {
  TransmissionTaskFilesController({TransmissionServiceFactory? serviceFactory})
      : _serviceFactory =
            serviceFactory ?? ((downloader) => TransmissionService(downloader));

  final TransmissionServiceFactory _serviceFactory;
  List<TransmissionTaskFileNode> _files = const [];
  final Set<String> _expandedPaths = <String>{};
  bool _isLoading = false;
  String? _errorMessage;

  List<TransmissionTaskFileNode> get files => _files;
  Set<String> get expandedPaths => _expandedPaths;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _files = await _serviceFactory(downloader).getTaskFiles(taskId);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleExpanded(String path) {
    if (_expandedPaths.contains(path)) {
      _expandedPaths.remove(path);
    } else {
      _expandedPaths.add(path);
    }
    notifyListeners();
  }
}
```

```dart
class TransmissionFileTreeNode extends StatelessWidget {
  const TransmissionFileTreeNode({
    super.key,
    required this.node,
    required this.depth,
  });

  final TransmissionTaskFileNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TransmissionTaskFilesController>();
    final expanded = controller.expandedPaths.contains(node.path);

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: 16.0 + depth * 16),
          leading: Icon(
            node.isDirectory
                ? (expanded ? Icons.folder_open : Icons.folder_outlined)
                : Icons.insert_drive_file_outlined,
          ),
          title: Text(node.name),
          subtitle: Text('${node.downloaded} / ${node.size}'),
          trailing: Text('${(node.progress * 100).toStringAsFixed(0)}%'),
          onTap: node.isDirectory
              ? () => controller.toggleExpanded(node.path)
              : null,
        ),
        if (node.isDirectory && expanded)
          for (final child in node.children)
            TransmissionFileTreeNode(node: child, depth: depth + 1),
      ],
    );
  }
}
```

- [x] **Step 4: Run the files page test to verify it passes**

Run: `flutter test test/widget/transmission_task_files_page_test.dart`

Expected: PASS with folder expansion and read-only file rows working.

- [x] **Step 5: Commit**

```bash
git add lib/features/tasks/presentation/controllers/transmission_task_files_controller.dart \
  lib/features/tasks/presentation/widgets/transmission_file_tree_node.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart \
  test/widget/transmission_task_files_page_test.dart
git commit -m "feat: add transmission files page"
```

## Task 3: Build The Read-Only Trackers And Peers Pages

**Files:**
- Create: `lib/features/tasks/presentation/controllers/transmission_task_trackers_controller.dart`
- Create: `lib/features/tasks/presentation/controllers/transmission_task_peers_controller.dart`
- Create: `lib/features/tasks/presentation/widgets/transmission_tracker_card.dart`
- Create: `lib/features/tasks/presentation/widgets/transmission_peer_row.dart`
- Modify: `lib/features/tasks/presentation/pages/transmission/transmission_task_trackers_page.dart`
- Modify: `lib/features/tasks/presentation/pages/transmission/transmission_task_peers_page.dart`
- Test: `test/widget/transmission_task_trackers_page_test.dart`
- Test: `test/widget/transmission_task_peers_page_test.dart`

- [x] **Step 1: Write the failing trackers and peers page tests**

```dart
testWidgets('renders tracker detail cards', (tester) async {
  final controller = TransmissionTaskTrackersController(
    serviceFactory: (_) => FakeTransmissionService.trackers([
      TransmissionTaskTracker(
        id: 1,
        host: 'tracker.example:443',
        announce: 'https://tracker.example/announce',
        tier: 1,
        lastAnnounceAt: DateTime(2026, 6, 25, 10, 0),
        nextAnnounceAt: DateTime(2026, 6, 25, 10, 17),
        lastScrapeAt: DateTime(2026, 6, 25, 10, 0),
        seederCount: 936,
        leecherCount: 35,
        downloadCount: 0,
      ),
    ]),
  );

  await tester.pumpWidget(buildTrackersPage(controller));
  await tester.pump();

  expect(find.text('tracker.example:443'), findsOneWidget);
  expect(find.text('Tier 1'), findsOneWidget);
  expect(find.text('936'), findsOneWidget);
});

testWidgets('renders dense peer rows', (tester) async {
  final controller = TransmissionTaskPeersController(
    serviceFactory: (_) => FakeTransmissionService.peers([
      const TransmissionTaskPeer(
        address: '222.213.144.115',
        clientName: 'qBittorrent/4.3.8',
        port: 42032,
        progress: 0.31,
        downloadSpeed: 0,
        uploadSpeed: 12800,
        isDownloadingToUs: false,
        isUploadingFromUs: true,
      ),
    ]),
  );

  await tester.pumpWidget(buildPeersPage(controller));
  await tester.pump();

  expect(find.text('222.213.144.115'), findsOneWidget);
  expect(find.text('qBittorrent/4.3.8'), findsOneWidget);
  expect(find.text('31%'), findsOneWidget);
});
```

- [x] **Step 2: Run the two page tests to verify they fail**

Run: `flutter test test/widget/transmission_task_trackers_page_test.dart test/widget/transmission_task_peers_page_test.dart`

Expected: FAIL with missing controller/widget errors for the real pages.

- [x] **Step 3: Implement the controllers and read-only UIs**

```dart
class TransmissionTaskTrackersController extends ChangeNotifier {
  TransmissionTaskTrackersController({
    TransmissionServiceFactory? serviceFactory,
  }) : _serviceFactory =
            serviceFactory ?? ((downloader) => TransmissionService(downloader));

  final TransmissionServiceFactory _serviceFactory;
  List<TransmissionTaskTracker> _trackers = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TransmissionTaskTracker> get trackers => _trackers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _trackers = await _serviceFactory(downloader).getTaskTrackers(taskId);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class TransmissionTrackerCard extends StatelessWidget {
  const TransmissionTrackerCard({super.key, required this.tracker});
  final TransmissionTaskTracker tracker;

  @override
  Widget build(BuildContext context) {
    return NeoSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(tracker.host)),
              Text('Tier ${tracker.tier}'),
            ],
          ),
          Text('Last update: ${tracker.lastAnnounceAt ?? '--'}'),
          Text('Next update: ${tracker.nextAnnounceAt ?? '--'}'),
          Text('Last scrape: ${tracker.lastScrapeAt ?? '--'}'),
          Text('Seeders: ${tracker.seederCount}'),
          Text('Leechers: ${tracker.leecherCount}'),
          Text('Downloaded: ${tracker.downloadCount}'),
        ],
      ),
    );
  }
}
```

```dart
class TransmissionPeerRow extends StatelessWidget {
  const TransmissionPeerRow({super.key, required this.peer});
  final TransmissionTaskPeer peer;

  @override
  Widget build(BuildContext context) {
    return NeoSection(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(peer.address)),
              Text('${(peer.progress * 100).toStringAsFixed(0)}%'),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text(peer.clientName)),
              Text('Port ${peer.port}'),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text('DL ${peer.downloadSpeed}')),
              Text('UL ${peer.uploadSpeed}'),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [x] **Step 4: Run the trackers and peers page tests to verify they pass**

Run: `flutter test test/widget/transmission_task_trackers_page_test.dart test/widget/transmission_task_peers_page_test.dart`

Expected: PASS with tracker cards and peer rows rendered from controller data.

- [x] **Step 5: Commit**

```bash
git add lib/features/tasks/presentation/controllers/transmission_task_trackers_controller.dart \
  lib/features/tasks/presentation/controllers/transmission_task_peers_controller.dart \
  lib/features/tasks/presentation/widgets/transmission_tracker_card.dart \
  lib/features/tasks/presentation/widgets/transmission_peer_row.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_trackers_page.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_peers_page.dart \
  test/widget/transmission_task_trackers_page_test.dart \
  test/widget/transmission_task_peers_page_test.dart
git commit -m "feat: add transmission trackers and peers pages"
```

## Task 4: Build The Editable Options Page

**Files:**
- Create: `lib/features/tasks/presentation/controllers/transmission_task_options_controller.dart`
- Create: `lib/features/tasks/presentation/widgets/transmission_options_form.dart`
- Modify: `lib/features/tasks/presentation/pages/transmission/transmission_task_options_page.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_ja.arb`
- Test: `test/unit/transmission_task_options_controller_test.dart`
- Test: `test/widget/transmission_task_options_page_test.dart`

- [x] **Step 1: Write the failing options controller and widget tests**

```dart
test('marks controller dirty when a field changes and clears dirty after save', () async {
  final controller = TransmissionTaskOptionsController(
    serviceFactory: (_) => FakeTransmissionService.options(
      const TransmissionTaskOptions(
        bandwidthPriority: 0,
        honorsSessionLimits: true,
        downloadLimited: true,
        downloadLimitKBps: 100,
        uploadLimited: true,
        uploadLimitKBps: 3000,
        seedRatioMode: TransmissionLimitMode.global,
        seedRatioLimit: 0,
        idleLimitMode: TransmissionLimitMode.global,
        idleLimitMinutes: 0,
      ),
    ),
  );

  await controller.load(taskId: '7', downloader: trans());
  controller.updateDownloadLimit('120');

  expect(controller.isDirty, isTrue);

  await controller.save(taskId: '7', downloader: trans());

  expect(controller.isDirty, isFalse);
});

testWidgets('renders editable options sections and save button', (tester) async {
  await tester.pumpWidget(buildOptionsPage(controller));
  await tester.pump();

  expect(find.text('Transfer Priority'), findsOneWidget);
  expect(find.text('Bandwidth'), findsOneWidget);
  expect(find.text('Share Ratio Limit'), findsOneWidget);
  expect(find.text('Idle Limit'), findsOneWidget);
  expect(find.text('Save'), findsOneWidget);
});
```

- [x] **Step 2: Run the options tests to verify they fail**

Run: `flutter test test/unit/transmission_task_options_controller_test.dart test/widget/transmission_task_options_page_test.dart`

Expected: FAIL with missing controller/form/save-method errors.

- [x] **Step 3: Implement the options controller, form, and save RPC**

```dart
class TransmissionTaskOptionsController extends ChangeNotifier {
  TransmissionTaskOptions? _initial;
  TransmissionTaskOptions? _draft;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  bool get isDirty => _initial != _draft;

  Future<void> load({
    required String taskId,
    required Downloader downloader,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final loaded = await _serviceFactory(downloader).getTaskOptions(taskId);
      _initial = loaded;
      _draft = loaded;
      _errorMessage = null;
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateBandwidthPriority(int value) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(bandwidthPriority: value);
    notifyListeners();
  }

  void updateDownloadLimit(String raw) {
    final value = int.tryParse(raw);
    final draft = _draft;
    if (draft == null || value == null || value < 0) return;
    _draft = draft.copyWith(downloadLimitKBps: value);
    notifyListeners();
  }

  Future<void> save({
    required String taskId,
    required Downloader downloader,
  }) async {
    final draft = _draft;
    if (draft == null) return;
    _isSaving = true;
    notifyListeners();
    try {
      await _serviceFactory(downloader).updateTaskOptions(
        taskId,
        TransmissionTaskOptionsUpdate.fromOptions(draft),
      );
      _initial = draft;
      _errorMessage = null;
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
```

```dart
// transmission_options_form.dart
class TransmissionOptionsForm extends StatelessWidget {
  const TransmissionOptionsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TransmissionTaskOptionsController>();
    final options = controller.draft!;
    return Column(
      children: [
        NeoSection(
          title: 'Transfer Priority',
          child: DropdownButton<int>(
            value: options.bandwidthPriority,
            items: const [
              DropdownMenuItem(value: -1, child: Text('Low')),
              DropdownMenuItem(value: 0, child: Text('Normal')),
              DropdownMenuItem(value: 1, child: Text('High')),
            ],
            onChanged: (value) {
              if (value != null) controller.updateBandwidthPriority(value);
            },
          ),
        ),
        NeoSection(
          title: 'Bandwidth',
          child: Column(
            children: [
              SwitchListTile(
                value: options.honorsSessionLimits,
                onChanged: controller.updateHonorsSessionLimits,
                title: const Text('Honor global bandwidth limits'),
              ),
              TextFormField(
                initialValue: '${options.downloadLimitKBps}',
                onChanged: controller.updateDownloadLimit,
                decoration: const InputDecoration(labelText: 'Download limit (KB/s)'),
              ),
              TextFormField(
                initialValue: '${options.uploadLimitKBps}',
                onChanged: controller.updateUploadLimit,
                decoration: const InputDecoration(labelText: 'Upload limit (KB/s)'),
              ),
            ],
          ),
        ),
        NeoSection(
          title: 'Share Ratio Limit',
          child: Column(
            children: [
              DropdownButton<TransmissionLimitMode>(
                value: options.seedRatioMode,
                items: const [
                  DropdownMenuItem(
                    value: TransmissionLimitMode.global,
                    child: Text('Global'),
                  ),
                  DropdownMenuItem(
                    value: TransmissionLimitMode.disabled,
                    child: Text('Disabled'),
                  ),
                  DropdownMenuItem(
                    value: TransmissionLimitMode.custom,
                    child: Text('Custom'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) controller.updateSeedRatioMode(value);
                },
              ),
              TextFormField(
                initialValue: '${options.seedRatioLimit}',
                onChanged: controller.updateSeedRatioLimit,
                decoration: const InputDecoration(labelText: 'Ratio value'),
              ),
            ],
          ),
        ),
        NeoSection(
          title: 'Idle Limit',
          child: Column(
            children: [
              DropdownButton<TransmissionLimitMode>(
                value: options.idleLimitMode,
                items: const [
                  DropdownMenuItem(
                    value: TransmissionLimitMode.global,
                    child: Text('Global'),
                  ),
                  DropdownMenuItem(
                    value: TransmissionLimitMode.disabled,
                    child: Text('Disabled'),
                  ),
                  DropdownMenuItem(
                    value: TransmissionLimitMode.custom,
                    child: Text('Custom'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) controller.updateIdleLimitMode(value);
                },
              ),
              TextFormField(
                initialValue: '${options.idleLimitMinutes}',
                onChanged: controller.updateIdleLimitMinutes,
                decoration: const InputDecoration(labelText: 'Minutes'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.isDirty && !controller.isSaving
                    ? () => controller.save(
                          taskId: '7',
                          downloader: context.read<DownloaderController>().getDownloader('trans-1')!,
                        )
                    : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

```dart
// transmission_modern_rpc_adapter.dart
@override
Future<void> updateTaskOptions(
  String taskId,
  TransmissionTaskOptionsUpdate update,
) async {
  await _call('torrent_set', {
    'ids': [int.tryParse(taskId) ?? taskId],
    'bandwidth_priority': update.bandwidthPriority,
    'honors_session_limits': update.honorsSessionLimits,
    'download_limited': update.downloadLimited,
    'download_limit': update.downloadLimitKBps,
    'upload_limited': update.uploadLimited,
    'upload_limit': update.uploadLimitKBps,
    'seed_ratio_mode': update.seedRatioMode.rpcValue,
    'seed_ratio_limit': update.seedRatioLimit,
    'idle_seeding_limit_mode': update.idleLimitMode.rpcValue,
    'idle_seeding_limit': update.idleLimitMinutes,
  });
}
```

- [x] **Step 4: Run the options tests to verify they pass**

Run: `flutter test test/unit/transmission_task_options_controller_test.dart test/widget/transmission_task_options_page_test.dart`

Expected: PASS with dirty-state tracking, save flow, and form rendering covered.

- [x] **Step 5: Commit**

```bash
git add lib/features/tasks/presentation/controllers/transmission_task_options_controller.dart \
  lib/features/tasks/presentation/widgets/transmission_options_form.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_options_page.dart \
  lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_ja.arb \
  lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart \
  lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart \
  test/unit/transmission_task_options_controller_test.dart \
  test/widget/transmission_task_options_page_test.dart
git commit -m "feat: add transmission task options page"
```

## Task 5: Run Regression Tests Across The Whole Transmission Detail Flow

**Files:**
- Modify: `test/widget/transmission_task_child_pages_test.dart`
- Modify: `test/widget/transmission_task_detail_page_test.dart`
- Modify: `test/widget/task_detail_route_page_test.dart`
- Modify: `test/unit/transmission_task_child_data_test.dart`
- Modify: `test/unit/transmission_task_options_controller_test.dart`

- [x] **Step 1: Add final regression assertions for navigation and save integration**

```dart
testWidgets('child page routes still preserve the shared hero and action bar', (
  tester,
) async {
  await tester.pumpWidget(buildFilesPageWithRouter());
  await tester.pumpAndSettle();

  expect(find.text('demo.iso'), findsOneWidget);
  expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);
  expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
});

testWidgets('options save keeps user input on failure', (tester) async {
  final controller = failingOptionsController();
  await tester.pumpWidget(buildOptionsPage(controller));
  await tester.pump();

  await tester.enterText(find.byType(TextFormField).first, '120');
  await tester.tap(find.text('Save'));
  await tester.pump();

  expect(find.text('120'), findsOneWidget);
  expect(find.text('boom'), findsOneWidget);
});
```

- [x] **Step 2: Run the full Transmission detail test suite and confirm any failures are real**

Run: `flutter test test/widget/transmission_task_detail_page_test.dart test/widget/transmission_task_files_page_test.dart test/widget/transmission_task_trackers_page_test.dart test/widget/transmission_task_peers_page_test.dart test/widget/transmission_task_options_page_test.dart test/widget/transmission_task_child_pages_test.dart test/widget/task_detail_route_page_test.dart test/unit/transmission_task_child_data_test.dart test/unit/transmission_task_options_controller_test.dart`

Expected: FAIL only for real regressions or unfinished child-page wiring.

- [x] **Step 3: Fix the remaining regressions and regenerate l10n if needed**

```bash
flutter gen-l10n
flutter test test/widget/transmission_task_detail_page_test.dart \
  test/widget/transmission_task_files_page_test.dart \
  test/widget/transmission_task_trackers_page_test.dart \
  test/widget/transmission_task_peers_page_test.dart \
  test/widget/transmission_task_options_page_test.dart \
  test/widget/transmission_task_child_pages_test.dart \
  test/widget/task_detail_route_page_test.dart \
  test/unit/transmission_task_child_data_test.dart \
  test/unit/transmission_task_options_controller_test.dart
```

- [x] **Step 4: Verify the full suite is green**

Run: `flutter test test/widget/transmission_task_detail_page_test.dart test/widget/transmission_task_files_page_test.dart test/widget/transmission_task_trackers_page_test.dart test/widget/transmission_task_peers_page_test.dart test/widget/transmission_task_options_page_test.dart test/widget/transmission_task_child_pages_test.dart test/widget/task_detail_route_page_test.dart test/unit/transmission_task_child_data_test.dart test/unit/transmission_task_options_controller_test.dart`

Expected: PASS across all nine test files.

- [x] **Step 5: Commit**

```bash
git add test/widget/transmission_task_detail_page_test.dart \
  test/widget/transmission_task_files_page_test.dart \
  test/widget/transmission_task_trackers_page_test.dart \
  test/widget/transmission_task_peers_page_test.dart \
  test/widget/transmission_task_options_page_test.dart \
  test/widget/transmission_task_child_pages_test.dart \
  test/widget/task_detail_route_page_test.dart \
  test/unit/transmission_task_child_data_test.dart \
  test/unit/transmission_task_options_controller_test.dart
git commit -m "test: verify transmission child pages"
```
