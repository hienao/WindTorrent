# Transmission Task Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Transmission-specific task detail experience with an info homepage, dedicated child-page entry points, and a shared detail shell that preserves existing task actions.

**Architecture:** Keep `TaskController` responsible for cross-downloader task summary state and actions, then add a Transmission-only detail model/controller for full-detail data. Convert the current task detail route into a dispatcher that chooses between a generic fallback page and a new `TransmissionTaskDetailPage`, both rendered inside a shared shell. Add child routes for files, trackers, peers, and options, but keep those pages as shells in this iteration.

**Tech Stack:** Flutter 3.24.5, Provider, go_router, Flutter l10n, widget tests, unit tests

---

## File Structure

### Create

- `lib/models/transmission_task_detail.dart`
  Owns the Transmission-only detail payload used by the info homepage and child-page entry summaries.
- `lib/features/tasks/presentation/controllers/transmission_task_detail_controller.dart`
  Loads and exposes `TransmissionTaskDetail`, plus dedicated loading/error state for the Transmission detail flow.
- `lib/features/tasks/presentation/widgets/task_detail_shell.dart`
  Shared detail scaffold that renders the page header, hero, refresh flow, and bottom action bar around downloader-specific content.
- `lib/features/tasks/presentation/widgets/task_detail_entry_card.dart`
  Small reusable card/list-tile style entry widget for `文件 / 服务器 / 节点 / 选项`.
- `lib/features/tasks/presentation/pages/generic_task_detail_page.dart`
  Holds the current generic detail content for non-Transmission downloaders during the migration.
- `lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart`
  Transmission info homepage.
- `lib/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart`
  Files child-page shell.
- `lib/features/tasks/presentation/pages/transmission/transmission_task_trackers_page.dart`
  Trackers child-page shell.
- `lib/features/tasks/presentation/pages/transmission/transmission_task_peers_page.dart`
  Peers child-page shell.
- `lib/features/tasks/presentation/pages/transmission/transmission_task_options_page.dart`
  Options child-page shell.
- `test/unit/transmission_task_detail_controller_test.dart`
  Unit tests for controller loading, success, and error states.
- `test/widget/task_detail_route_page_test.dart`
  Route/dispatcher tests for downloader-type-based page selection.
- `test/widget/transmission_task_detail_page_test.dart`
  Widget tests for the info homepage sections and detail-entry cards.
- `test/widget/transmission_task_child_pages_test.dart`
  Widget/router tests for the four child pages and navigation.

### Modify

- `lib/services/transmission/transmission_rpc_adapter.dart`
  Add `getTaskFullDetail`.
- `lib/services/transmission/transmission_modern_rpc_adapter.dart`
  Fetch and map full-detail fields from snake_case RPC payloads.
- `lib/services/transmission/transmission_legacy_rpc_adapter.dart`
  Fetch and map full-detail fields from camelCase / kebab RPC payloads.
- `lib/services/transmission_service.dart`
  Expose `getTaskFullDetail`.
- `lib/core/router/app_router.dart`
  Keep `/tasks/detail/:id` as the entry route and add Transmission child routes.
- `lib/features/tasks/presentation/pages/task_detail_page.dart`
  Turn this page into the dispatcher instead of a single hard-coded layout.
- `test/unit/transmission_rpc_adapter_test.dart`
  Add full-detail parser coverage for modern and legacy adapters.
- `test/widget/task_detail_neumorphism_test.dart`
  Point the old generic-detail assertions at the new generic fallback page or shell.
- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_ja.arb`
  Add strings for the Transmission info groups, child-page titles, entry-card labels, and shell empty-state copy.

## Task 1: Add Transmission Full-Detail Model And RPC Parsing

**Files:**
- Create: `lib/models/transmission_task_detail.dart`
- Modify: `lib/services/transmission/transmission_rpc_adapter.dart`
- Modify: `lib/services/transmission/transmission_modern_rpc_adapter.dart`
- Modify: `lib/services/transmission/transmission_legacy_rpc_adapter.dart`
- Modify: `lib/services/transmission_service.dart`
- Test: `test/unit/transmission_rpc_adapter_test.dart`

- [ ] **Step 1: Write the failing adapter tests**

```dart
group('Modern adapter full detail', () {
  test('maps info, transfer, dates, and runtime fields', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'result': {
              'torrents': [
                {
                  'id': 7,
                  'hash_string': 'abc',
                  'name': 'demo.iso',
                  'total_size': 1000,
                  'piece_count': 20,
                  'piece_size': 50,
                  'download_dir': '/downloads',
                  'is_private': true,
                  'creator': 'qBittorrent',
                  'date_created': 1710000000,
                  'magnet_link': 'magnet:?xt=urn:btih:abc',
                  'desired_available': 0.95,
                  'downloaded_ever': 900,
                  'uploaded_ever': 300,
                  'upload_ratio': 0.33,
                  'rate_download': 10,
                  'added_date': 1710000100,
                  'done_date': 1710000200,
                  'activity_date': 1710000300,
                  'seconds_downloading': 120,
                  'seconds_seeding': 45,
                  'files': [
                    {'name': 'demo.iso', 'length': 1000, 'bytes_completed': 900}
                  ],
                  'trackers': [
                    {'announce': 'https://tracker.example/announce'}
                  ],
                  'peers': [
                    {'address': '1.1.1.1'}
                  ],
                }
              ]
            },
            'id': 1,
          }),
          200,
        ));

    final adapter = TransmissionModernRpcAdapter(
      downloader: trans(),
      client: client,
      protocolInfo: const TransmissionProtocolInfo(
        protocol: TransmissionProtocol.modern,
        appVersion: '4.1.1',
      ),
    );

    final detail = await adapter.getTaskFullDetail('7');

    expect(detail.pieceCount, 20);
    expect(detail.isPrivate, isTrue);
    expect(detail.fileCount, 1);
    expect(detail.trackerCount, 1);
    expect(detail.peerCount, 1);
    expect(detail.downloadDuration, const Duration(seconds: 120));
  });
});

group('Legacy adapter full detail', () {
  test('maps camelCase full-detail fields', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'result': 'success',
            'arguments': {
              'torrents': [
                {
                  'id': 8,
                  'hashString': 'def',
                  'name': 'legacy.iso',
                  'totalSize': 2000,
                  'pieceCount': 40,
                  'pieceSize': 50,
                  'downloadDir': '/legacy',
                  'isPrivate': false,
                  'creator': 'Transmission',
                  'dateCreated': 1710001000,
                  'magnetLink': 'magnet:?xt=urn:btih:def',
                  'desiredAvailable': 1.0,
                  'downloadedEver': 2000,
                  'uploadedEver': 1000,
                  'uploadRatio': 0.5,
                  'rateDownload': 20,
                  'addedDate': 1710001100,
                  'doneDate': 1710001200,
                  'activityDate': 1710001300,
                  'secondsDownloading': 240,
                  'secondsSeeding': 60,
                  'files': [
                    {'name': 'legacy.iso', 'length': 2000, 'bytesCompleted': 2000}
                  ],
                  'trackers': [
                    {'announce': 'https://tracker.example/legacy'}
                  ],
                  'peers': [
                    {'address': '2.2.2.2'}
                  ],
                }
              ]
            },
            'tag': 1,
          }),
          200,
        ));

    final adapter = TransmissionLegacyRpcAdapter(
      downloader: trans(),
      client: client,
      protocolInfo: const TransmissionProtocolInfo(
        protocol: TransmissionProtocol.legacy,
        appVersion: '4.0.3',
        rpcSemver: '5.3.0',
      ),
    );

    final detail = await adapter.getTaskFullDetail('8');

    expect(detail.pieceCount, 40);
    expect(detail.isPrivate, isFalse);
    expect(detail.fileCount, 1);
    expect(detail.trackerCount, 1);
    expect(detail.peerCount, 1);
    expect(detail.seedingDuration, const Duration(seconds: 60));
  });
});
```

- [ ] **Step 2: Run the adapter test file to verify it fails**

Run: `flutter test test/unit/transmission_rpc_adapter_test.dart`

Expected: FAIL with compile errors similar to:

- `The method 'getTaskFullDetail' isn't defined for the type 'TransmissionModernRpcAdapter'`
- `Undefined class 'TransmissionTaskDetail'`

- [ ] **Step 3: Write the minimal model and adapter implementation**

```dart
// lib/models/transmission_task_detail.dart
class TransmissionTaskDetail {
  const TransmissionTaskDetail({
    required this.taskId,
    required this.name,
    required this.downloaderId,
    required this.totalSize,
    required this.pieceCount,
    required this.pieceSize,
    required this.savePath,
    required this.isPrivate,
    required this.creator,
    required this.createdAt,
    required this.magnet,
    required this.availablePercent,
    required this.downloadedEver,
    required this.uploadedEver,
    required this.ratio,
    required this.averageSpeed,
    required this.addedAt,
    required this.completedAt,
    required this.lastActivityAt,
    required this.downloadDuration,
    required this.seedingDuration,
    required this.fileCount,
    required this.trackerCount,
    required this.peerCount,
    required this.optionsEditable,
  });

  final String taskId;
  final String name;
  final String downloaderId;
  final int totalSize;
  final int pieceCount;
  final int pieceSize;
  final String savePath;
  final bool isPrivate;
  final String? creator;
  final DateTime? createdAt;
  final String? magnet;
  final double availablePercent;
  final int downloadedEver;
  final int uploadedEver;
  final double ratio;
  final int averageSpeed;
  final DateTime? addedAt;
  final DateTime? completedAt;
  final DateTime? lastActivityAt;
  final Duration downloadDuration;
  final Duration seedingDuration;
  final int fileCount;
  final int trackerCount;
  final int peerCount;
  final bool optionsEditable;
}
```

```dart
// lib/services/transmission/transmission_rpc_adapter.dart
abstract class TransmissionRpcAdapter {
  Future<ConnectionResult> testConnection();
  Future<List<DownloadTask>> getTasks();
  Future<DownloadTask?> getTaskDetail(String taskId);
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId);
  Future<Map<String, dynamic>> getGlobalStat();
  // ...
}
```

```dart
// lib/services/transmission/transmission_modern_rpc_adapter.dart
@override
Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async {
  final result = await _call('torrent_get', {
    'ids': [int.tryParse(taskId) ?? taskId],
    'fields': [
      'id',
      'hash_string',
      'name',
      'total_size',
      'piece_count',
      'piece_size',
      'download_dir',
      'is_private',
      'creator',
      'date_created',
      'magnet_link',
      'desired_available',
      'downloaded_ever',
      'uploaded_ever',
      'upload_ratio',
      'rate_download',
      'added_date',
      'done_date',
      'activity_date',
      'seconds_downloading',
      'seconds_seeding',
      'files',
      'trackers',
      'peers',
    ],
  });

  final torrents = result['torrents'] as List<dynamic>;
  final json = torrents.first as Map<String, dynamic>;
  return TransmissionTaskDetail(
    taskId: (json['id'] ?? '').toString(),
    name: json['name'] as String? ?? 'Unknown',
    downloaderId: downloader.id,
    totalSize: json['total_size'] as int? ?? 0,
    pieceCount: json['piece_count'] as int? ?? 0,
    pieceSize: json['piece_size'] as int? ?? 0,
    savePath: json['download_dir'] as String? ?? '',
    isPrivate: json['is_private'] as bool? ?? false,
    creator: json['creator'] as String?,
    createdAt: _timestampOrNull(json['date_created']),
    magnet: json['magnet_link'] as String?,
    availablePercent: (json['desired_available'] as num?)?.toDouble() ?? 0,
    downloadedEver: json['downloaded_ever'] as int? ?? 0,
    uploadedEver: json['uploaded_ever'] as int? ?? 0,
    ratio: (json['upload_ratio'] as num?)?.toDouble() ?? 0,
    averageSpeed: json['rate_download'] as int? ?? 0,
    addedAt: _timestampOrNull(json['added_date']),
    completedAt: _timestampOrNull(json['done_date']),
    lastActivityAt: _timestampOrNull(json['activity_date']),
    downloadDuration: Duration(seconds: json['seconds_downloading'] as int? ?? 0),
    seedingDuration: Duration(seconds: json['seconds_seeding'] as int? ?? 0),
    fileCount: (json['files'] as List?)?.length ?? 0,
    trackerCount: (json['trackers'] as List?)?.length ?? 0,
    peerCount: (json['peers'] as List?)?.length ?? 0,
    optionsEditable: true,
  );
}
```

```dart
// lib/services/transmission/transmission_legacy_rpc_adapter.dart
@override
Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async {
  final result = await _call('torrent-get', {
    'ids': [int.tryParse(taskId) ?? taskId],
    'fields': [
      'id',
      'hashString',
      'name',
      'totalSize',
      'pieceCount',
      'pieceSize',
      'downloadDir',
      'isPrivate',
      'creator',
      'dateCreated',
      'magnetLink',
      'desiredAvailable',
      'downloadedEver',
      'uploadedEver',
      'uploadRatio',
      'rateDownload',
      'addedDate',
      'doneDate',
      'activityDate',
      'secondsDownloading',
      'secondsSeeding',
      'files',
      'trackers',
      'peers',
    ],
  });

  final torrents = result['torrents'] as List<dynamic>;
  final json = torrents.first as Map<String, dynamic>;
  return TransmissionTaskDetail(
    taskId: (json['id'] ?? '').toString(),
    name: json['name'] as String? ?? 'Unknown',
    downloaderId: downloader.id,
    totalSize: json['totalSize'] as int? ?? 0,
    pieceCount: json['pieceCount'] as int? ?? 0,
    pieceSize: json['pieceSize'] as int? ?? 0,
    savePath: json['downloadDir'] as String? ?? '',
    isPrivate: json['isPrivate'] as bool? ?? false,
    creator: json['creator'] as String?,
    createdAt: _timestampOrNull(json['dateCreated']),
    magnet: json['magnetLink'] as String?,
    availablePercent: (json['desiredAvailable'] as num?)?.toDouble() ?? 0,
    downloadedEver: json['downloadedEver'] as int? ?? 0,
    uploadedEver: json['uploadedEver'] as int? ?? 0,
    ratio: (json['uploadRatio'] as num?)?.toDouble() ?? 0,
    averageSpeed: json['rateDownload'] as int? ?? 0,
    addedAt: _timestampOrNull(json['addedDate']),
    completedAt: _timestampOrNull(json['doneDate']),
    lastActivityAt: _timestampOrNull(json['activityDate']),
    downloadDuration: Duration(seconds: json['secondsDownloading'] as int? ?? 0),
    seedingDuration: Duration(seconds: json['secondsSeeding'] as int? ?? 0),
    fileCount: (json['files'] as List?)?.length ?? 0,
    trackerCount: (json['trackers'] as List?)?.length ?? 0,
    peerCount: (json['peers'] as List?)?.length ?? 0,
    optionsEditable: true,
  );
}
```

```dart
// lib/services/transmission_service.dart
Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async {
  final adapter = await _getAdapter();
  return adapter.getTaskFullDetail(taskId);
}
```

- [ ] **Step 4: Run the adapter tests to verify they pass**

Run: `flutter test test/unit/transmission_rpc_adapter_test.dart`

Expected: PASS with the new modern and legacy full-detail test groups included.

- [ ] **Step 5: Commit**

```bash
git add lib/models/transmission_task_detail.dart \
  lib/services/transmission/transmission_rpc_adapter.dart \
  lib/services/transmission/transmission_modern_rpc_adapter.dart \
  lib/services/transmission/transmission_legacy_rpc_adapter.dart \
  lib/services/transmission_service.dart \
  test/unit/transmission_rpc_adapter_test.dart
git commit -m "feat: add transmission full detail model"
```

## Task 2: Add Transmission Detail Controller

**Files:**
- Create: `lib/features/tasks/presentation/controllers/transmission_task_detail_controller.dart`
- Test: `test/unit/transmission_task_detail_controller_test.dart`

- [ ] **Step 1: Write the failing controller tests**

```dart
test('load stores detail on success', () async {
  const fakeDetail = TransmissionTaskDetail(
    taskId: '7',
    name: 'demo.iso',
    downloaderId: 'trans-1',
    totalSize: 1000,
    pieceCount: 20,
    pieceSize: 50,
    savePath: '/downloads',
    isPrivate: true,
    creator: 'Transmission',
    createdAt: null,
    magnet: 'magnet:?xt=urn:btih:abc',
    availablePercent: 1,
    downloadedEver: 1000,
    uploadedEver: 100,
    ratio: 0.1,
    averageSpeed: 10,
    addedAt: null,
    completedAt: null,
    lastActivityAt: null,
    downloadDuration: Duration.zero,
    seedingDuration: Duration.zero,
    fileCount: 1,
    trackerCount: 1,
    peerCount: 1,
    optionsEditable: true,
  );
  final downloader = createTestDownloader(
    id: 'trans-1',
    type: DownloaderType.transmission,
  );
  final controller = TransmissionTaskDetailController(
    serviceFactory: (_) => FakeTransmissionService.success(fakeDetail),
  );

  await controller.load(taskId: '7', downloader: downloader);

  expect(controller.detail, fakeDetail);
  expect(controller.isLoading, isFalse);
  expect(controller.errorMessage, isNull);
});

test('load exposes error message on failure', () async {
  final downloader = createTestDownloader(
    id: 'trans-1',
    type: DownloaderType.transmission,
  );
  final controller = TransmissionTaskDetailController(
    serviceFactory: (_) => FakeTransmissionService.failure(
      DownloaderServiceException('boom'),
    ),
  );

  await controller.load(taskId: '7', downloader: downloader);

  expect(controller.detail, isNull);
  expect(controller.errorMessage, 'boom');
});

class FakeTransmissionService extends TransmissionService {
  FakeTransmissionService.success(this._detail)
      : _error = null,
        super(createTestDownloader(
          id: 'trans-1',
          type: DownloaderType.transmission,
        ));

  FakeTransmissionService.failure(this._error)
      : _detail = null,
        super(createTestDownloader(
          id: 'trans-1',
          type: DownloaderType.transmission,
        ));

  final TransmissionTaskDetail? _detail;
  final Object? _error;

  @override
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async {
    if (_error != null) throw _error!;
    return _detail!;
  }
}
```

- [ ] **Step 2: Run the controller test file to verify it fails**

Run: `flutter test test/unit/transmission_task_detail_controller_test.dart`

Expected: FAIL with errors such as:

- `Target of URI doesn't exist: 'package:windwalker/features/tasks/presentation/controllers/transmission_task_detail_controller.dart'`
- `Undefined class 'TransmissionTaskDetailController'`

- [ ] **Step 3: Write the minimal controller implementation**

```dart
typedef TransmissionServiceFactory = TransmissionService Function(
  Downloader downloader,
);

class TransmissionTaskDetailController extends ChangeNotifier {
  TransmissionTaskDetailController({
    TransmissionServiceFactory? serviceFactory,
  }) : _serviceFactory =
            serviceFactory ?? ((downloader) => TransmissionService(downloader));

  final TransmissionServiceFactory _serviceFactory;

  TransmissionTaskDetail? _detail;
  bool _isLoading = false;
  String? _errorMessage;

  TransmissionTaskDetail? get detail => _detail;
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
      _detail = await _serviceFactory(downloader).getTaskFullDetail(taskId);
    } on DownloaderServiceException catch (e) {
      _detail = null;
      _errorMessage = e.message;
    } catch (e) {
      _detail = null;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _detail = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run the controller tests to verify they pass**

Run: `flutter test test/unit/transmission_task_detail_controller_test.dart`

Expected: PASS with both success and failure state assertions green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tasks/presentation/controllers/transmission_task_detail_controller.dart \
  test/unit/transmission_task_detail_controller_test.dart
git commit -m "feat: add transmission detail controller"
```

## Task 3: Convert The Current Detail Page Into A Dispatcher And Shared Shell

**Files:**
- Create: `lib/features/tasks/presentation/widgets/task_detail_shell.dart`
- Create: `lib/features/tasks/presentation/pages/generic_task_detail_page.dart`
- Modify: `lib/features/tasks/presentation/pages/task_detail_page.dart`
- Modify: `test/widget/task_detail_neumorphism_test.dart`
- Test: `test/widget/task_detail_route_page_test.dart`

- [ ] **Step 1: Write the failing route-dispatch widget test**

```dart
testWidgets('dispatches transmission tasks to TransmissionTaskDetailPage', (
  tester,
) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(
        id: 'trans-1',
        name: 'NAS',
        type: DownloaderType.transmission,
      ),
    ];

  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      child: const TaskDetailPage(
        taskId: '7',
        downloaderId: 'trans-1',
        taskName: 'demo.iso',
      ),
    ),
  );
  await tester.pump();

  expect(find.byType(TransmissionTaskDetailPage), findsOneWidget);
});
```

- [ ] **Step 2: Run the route widget test to verify it fails**

Run: `flutter test test/widget/task_detail_route_page_test.dart`

Expected: FAIL because `TransmissionTaskDetailPage` and the dispatcher behavior do not exist yet.

- [ ] **Step 3: Extract the shell and turn `TaskDetailPage` into a switch**

```dart
// lib/features/tasks/presentation/pages/task_detail_page.dart
class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;

  @override
  Widget build(BuildContext context) {
    final downloader = context
        .watch<DownloaderController>()
        .getDownloader(downloaderId);

    if (downloader == null) {
      return const Scaffold(
        body: Center(child: Text('Downloader not found')),
      );
    }

    switch (downloader.type) {
      case DownloaderType.transmission:
        return TransmissionTaskDetailPage(
          taskId: taskId,
          downloaderId: downloaderId,
          taskName: taskName,
        );
      case DownloaderType.aria2:
      case DownloaderType.qbittorrent:
        return GenericTaskDetailPage(
          taskId: taskId,
          downloaderId: downloaderId,
          taskName: taskName,
        );
    }
  }
}
```

```dart
// lib/features/tasks/presentation/widgets/task_detail_shell.dart
class TaskDetailShell extends StatelessWidget {
  const TaskDetailShell({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
    required this.body,
    required this.onRefresh,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;
  final Widget body;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Consumer2<TaskController, DownloaderController>(
      builder: (context, taskController, downloaderController, _) {
        final task = taskController.currentTask;
        final downloaderName =
            downloaderController.getDownloader(downloaderId)?.name ?? '--';

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                children: [
                  NeoPageHeader(
                    title: AppLocalizations.of(context)!.taskDetail,
                    onBack: () => context.pop(),
                  ),
                  NeoStatusHeroCard(
                    icon: Icons.download_rounded,
                    iconColor: AppColors.warning,
                    title: task?.name.isNotEmpty == true ? task!.name : taskName,
                    subtitle: downloaderName,
                    badge: NeoBadge(
                      label: task?.status.localizedLabel(context) ??
                          AppLocalizations.of(context)!.loading,
                      backgroundColor:
                          AppColors.warning.withValues(alpha: 0.16),
                      foregroundColor: AppColors.warning,
                    ),
                    progress: (task?.progress ?? 0).clamp(0, 1).toDouble(),
                    leadingMeta:
                        '${(((task?.progress ?? 0).clamp(0, 1).toDouble()) * 100).toStringAsFixed(1)}%',
                    trailingMeta: task?.formattedSpeed ?? '--',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  body,
                ],
              ),
            ),
          ),
          bottomNavigationBar: TaskDetailActionBar(
            taskId: taskId,
            downloaderId: downloaderId,
          ),
        );
      },
    );
  }
}

class TaskDetailActionBar extends StatelessWidget {
  const TaskDetailActionBar({
    super.key,
    required this.taskId,
    required this.downloaderId,
  });

  final String taskId;
  final String downloaderId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TaskController>();
    final task = controller.currentTask;

    return NeoActionBar(
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: (task == null ||
                      (task.status != TaskStatus.downloading &&
                          task.status != TaskStatus.waiting))
                  ? null
                  : () => controller.pauseTaskForDownloader(
                        taskId,
                        downloaderId,
                        context.read<DownloaderController>(),
                      ),
              child: const Text('Pause'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: (task == null || task.status != TaskStatus.paused)
                  ? null
                  : () => controller.resumeTaskForDownloader(
                        taskId,
                        downloaderId,
                        context.read<DownloaderController>(),
                      ),
              child: const Text('Resume'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () async {
                final deleteFiles = await showDeleteTaskDialog(context);
                if (deleteFiles != null && context.mounted) {
                  await controller.removeTaskForDownloader(
                    taskId,
                    downloaderId,
                    context.read<DownloaderController>(),
                    deleteFiles: deleteFiles,
                  );
                  if (context.mounted) context.pop();
                }
              },
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/features/tasks/presentation/pages/generic_task_detail_page.dart
class GenericTaskDetailPage extends StatelessWidget {
  const GenericTaskDetailPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final task = context.watch<TaskController>().currentTask;
    return TaskDetailShell(
      taskId: taskId,
      downloaderId: downloaderId,
      taskName: taskName,
      onRefresh: () => context.read<TaskController>().loadTaskDetailForDownloader(
            taskId,
            downloaderId,
            context.read<DownloaderController>(),
          ),
      body: Column(
        children: [
          _NeoKvSection(
            title: l10n.fileInfoSection,
            items: [
              _NeoKvItem(l10n.fileName, task?.name.isNotEmpty == true ? task!.name : taskName),
              if (task?.fileCount != null) _NeoKvItem(l10n.fileCount, '${task!.fileCount}'),
              _NeoKvItem(l10n.taskId, taskId),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _NeoKvSection(
            title: l10n.downloadInfoSection,
            items: [
              _NeoKvItem(l10n.status, task?.status.localizedLabel(context) ?? l10n.loading),
              _NeoKvItem(
                l10n.progress,
                '${(((task?.progress ?? 0).clamp(0, 1).toDouble()) * 100).toStringAsFixed(1)}%',
              ),
              _NeoKvItem(l10n.currentDownloadSpeed, task?.formattedSpeed ?? '--'),
              _NeoKvItem(l10n.currentUploadSpeed, task?.formattedUploadSpeed ?? '--'),
              _NeoKvItem(
                l10n.downloadedOverTotal,
                task != null
                    ? '${task.formattedDownloaded} / ${task.formattedSize}'
                    : '--',
              ),
              _NeoKvItem(l10n.remainingTime, task?.eta ?? '--'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _NeoKvSection(
            title: l10n.connectionInfoSection,
            items: [
              _NeoKvItem(
                l10n.downloaderName,
                context.read<DownloaderController>().getDownloader(downloaderId)?.name ?? '--',
              ),
              _NeoKvItem(l10n.tracker, task?.tracker ?? '--'),
              _NeoKvItem(l10n.connectionCount, '${task?.connections ?? '--'}'),
              _NeoKvItem(l10n.seeds, '${task?.seeders ?? '--'}'),
              _NeoKvItem(l10n.peers, '${task?.peers ?? '--'}'),
            ],
          ),
        ],
      ),
    );
  }
}

// Move _NeoKvSection, _NeoKvItem, and _NeoKvRow from the old
// task_detail_page.dart into this file unchanged.
```

- [ ] **Step 4: Run the old generic-detail test plus the new dispatcher test**

Run: `flutter test test/widget/task_detail_neumorphism_test.dart test/widget/task_detail_route_page_test.dart`

Expected: PASS, with the generic-detail assertions still green and the new Transmission dispatch assertion green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tasks/presentation/widgets/task_detail_shell.dart \
  lib/features/tasks/presentation/pages/generic_task_detail_page.dart \
  lib/features/tasks/presentation/pages/task_detail_page.dart \
  test/widget/task_detail_neumorphism_test.dart \
  test/widget/task_detail_route_page_test.dart
git commit -m "refactor: split task detail route and shell"
```

## Task 4: Build The Transmission Info Homepage

**Files:**
- Create: `lib/features/tasks/presentation/widgets/task_detail_entry_card.dart`
- Create: `lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_ja.arb`
- Test: `test/widget/transmission_task_detail_page_test.dart`

- [ ] **Step 1: Write the failing Transmission detail widget test**

```dart
testWidgets('renders transmission info groups and detail entry cards', (
  tester,
) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(
        id: 'trans-1',
        name: 'NAS',
        type: DownloaderType.transmission,
      ),
    ];
  final taskController = _SeededTaskController()
    ..seedCurrentTask(
      DownloadTask(
        id: '7',
        gid: '7',
        name: 'demo.iso',
        totalSize: 1000,
        downloaded: 500,
        progress: 0.5,
        downloadSpeed: 10,
        uploadSpeed: 2,
        status: TaskStatus.downloading,
        savePath: '/downloads',
        downloaderId: 'trans-1',
      ),
    );

  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      taskController: taskController,
      child: ChangeNotifierProvider(
        create: (_) => TransmissionTaskDetailController(
          serviceFactory: (_) => FakeTransmissionService.success(
            const TransmissionTaskDetail(
              taskId: '7',
              name: 'demo.iso',
              downloaderId: 'trans-1',
              totalSize: 1000,
              pieceCount: 20,
              pieceSize: 50,
              savePath: '/downloads',
              isPrivate: true,
              creator: 'Transmission',
              createdAt: null,
              magnet: 'magnet:?xt=urn:btih:abc',
              availablePercent: 1,
              downloadedEver: 1000,
              uploadedEver: 100,
              ratio: 0.1,
              averageSpeed: 10,
              addedAt: null,
              completedAt: null,
              lastActivityAt: null,
              downloadDuration: Duration.zero,
              seedingDuration: Duration.zero,
              fileCount: 1,
              trackerCount: 1,
              peerCount: 1,
              optionsEditable: true,
            ),
          ),
        ),
        child: const TransmissionTaskDetailPage(
          taskId: '7',
          downloaderId: 'trans-1',
          taskName: 'demo.iso',
        ),
      ),
    ),
  );
  await tester.pump();

  expect(find.text('Torrent Info'), findsOneWidget);
  expect(find.text('Transfer'), findsOneWidget);
  expect(find.text('Date'), findsOneWidget);
  expect(find.text('Runtime'), findsOneWidget);
  expect(find.text('More Details'), findsOneWidget);
  expect(find.text('Files'), findsOneWidget);
  expect(find.text('Trackers'), findsOneWidget);
  expect(find.text('Peers'), findsOneWidget);
  expect(find.text('Options'), findsOneWidget);
});

class _SeededTaskController extends TaskController {
  void seedCurrentTask(DownloadTask task) {
    debugSetCurrentTaskForTest(task);
  }

  @override
  Future<void> loadTaskDetailForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController,
  ) async {}
}
```

- [ ] **Step 2: Run the widget test to verify it fails**

Run: `flutter test test/widget/transmission_task_detail_page_test.dart`

Expected: FAIL with missing widget/class errors for `TransmissionTaskDetailPage` and new l10n keys.

- [ ] **Step 3: Implement the page, entry-card widget, and strings**

```dart
// lib/features/tasks/presentation/widgets/task_detail_entry_card.dart
class TaskDetailEntryCard extends StatelessWidget {
  const TaskDetailEntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NeoSection(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
```

```dart
// lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart
class TransmissionTaskDetailPage extends StatefulWidget {
  const TransmissionTaskDetailPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;

  @override
  State<TransmissionTaskDetailPage> createState() =>
      _TransmissionTaskDetailPageState();
}

class _TransmissionTaskDetailPageState
    extends State<TransmissionTaskDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final downloader = context
        .read<DownloaderController>()
        .getDownloader(widget.downloaderId)!;
    await context.read<TaskController>().loadTaskDetailForDownloader(
          widget.taskId,
          widget.downloaderId,
          context.read<DownloaderController>(),
        );
    await context.read<TransmissionTaskDetailController>().load(
          taskId: widget.taskId,
          downloader: downloader,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailController = context.watch<TransmissionTaskDetailController>();
    final detail = detailController.detail;

    return TaskDetailShell(
      taskId: widget.taskId,
      downloaderId: widget.downloaderId,
      taskName: widget.taskName,
      onRefresh: _load,
      body: Column(
        children: [
          TransmissionInfoSection(
            title: l10n.taskTorrentInfoSection,
            children: [
              TransmissionInfoRow(
                label: l10n.totalSize,
                value:
                    '${detail?.totalSize ?? 0} (${detail?.pieceCount ?? 0} x ${detail?.pieceSize ?? 0})',
              ),
              TransmissionInfoRow(
                label: l10n.savePath,
                value: detail?.savePath ?? '--',
              ),
              TransmissionInfoRow(
                label: l10n.privacy,
                value: detail?.isPrivate == true ? l10n.yes : l10n.no,
              ),
              TransmissionInfoRow(
                label: l10n.creator,
                value: detail?.creator ?? '--',
              ),
              TransmissionInfoRow(
                label: l10n.createdAt,
                value: detail?.createdAt?.toIso8601String() ?? '--',
              ),
              TransmissionInfoRow(
                label: l10n.magnet,
                value: detail?.magnet ?? '--',
              ),
            ],
          ),
          TransmissionInfoSection(
            title: l10n.taskTransferSection,
            children: [
              TransmissionInfoRow(
                label: l10n.totalDownloaded,
                value: '${detail?.downloadedEver ?? 0}',
              ),
              TransmissionInfoRow(
                label: l10n.availability,
                value: '${((detail?.availablePercent ?? 0) * 100).toStringAsFixed(1)}%',
              ),
              TransmissionInfoRow(
                label: l10n.totalUploaded,
                value: '${detail?.uploadedEver ?? 0}',
              ),
              TransmissionInfoRow(
                label: l10n.shareRatio,
                value: '${detail?.ratio ?? 0}',
              ),
              TransmissionInfoRow(
                label: l10n.averageSpeed,
                value: '${detail?.averageSpeed ?? 0}',
              ),
            ],
          ),
          TransmissionInfoSection(
            title: l10n.taskDateSection,
            children: [
              TransmissionInfoRow(
                label: l10n.addedAt,
                value: detail?.addedAt?.toIso8601String() ?? '--',
              ),
              TransmissionInfoRow(
                label: l10n.completedAt,
                value: detail?.completedAt?.toIso8601String() ?? '--',
              ),
              TransmissionInfoRow(
                label: l10n.lastActivityAt,
                value: detail?.lastActivityAt?.toIso8601String() ?? '--',
              ),
            ],
          ),
          TransmissionInfoSection(
            title: l10n.taskRuntimeSection,
            children: [
              TransmissionInfoRow(
                label: l10n.downloadDuration,
                value: '${detail?.downloadDuration ?? Duration.zero}',
              ),
              TransmissionInfoRow(
                label: l10n.seedingDuration,
                value: '${detail?.seedingDuration ?? Duration.zero}',
              ),
            ],
          ),
          NeoSection(
            title: l10n.taskMoreDetails,
            child: Column(
              children: [
                TaskDetailEntryCard(
                  title: l10n.taskFilesEntry,
                  subtitle: '${detail?.fileCount ?? 0} files',
                  icon: Icons.folder_outlined,
                  onTap: () {},
                ),
                TaskDetailEntryCard(
                  title: l10n.taskTrackersEntry,
                  subtitle: '${detail?.trackerCount ?? 0} trackers',
                  icon: Icons.dns_outlined,
                  onTap: () {},
                ),
                TaskDetailEntryCard(
                  title: l10n.taskPeersEntry,
                  subtitle: '${detail?.peerCount ?? 0} peers',
                  icon: Icons.people_outline_rounded,
                  onTap: () {},
                ),
                TaskDetailEntryCard(
                  title: l10n.taskOptionsEntry,
                  subtitle: l10n.taskOptionsShellSubtitle,
                  icon: Icons.tune_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TransmissionInfoSection extends StatelessWidget {
  const TransmissionInfoSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NeoSection(
      title: title,
      child: Column(children: children),
    );
  }
}

class TransmissionInfoRow extends StatelessWidget {
  const TransmissionInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
```

```json
// lib/l10n/app_en.arb
{
  "taskTorrentInfoSection": "Torrent Info",
  "taskTransferSection": "Transfer",
  "taskDateSection": "Date",
  "taskRuntimeSection": "Runtime",
  "taskMoreDetails": "More Details",
  "taskFilesEntry": "Files",
  "taskTrackersEntry": "Trackers",
  "taskPeersEntry": "Peers",
  "taskOptionsEntry": "Options",
  "taskOptionsShellSubtitle": "Priority, bandwidth, ratio, and idle limits",
  "privacy": "Privacy",
  "creator": "Creator",
  "createdAt": "Created At",
  "magnet": "Magnet",
  "totalDownloaded": "Total Downloaded",
  "availability": "Availability",
  "totalUploaded": "Total Uploaded",
  "shareRatio": "Share Ratio",
  "averageSpeed": "Average Speed",
  "addedAt": "Added",
  "completedAt": "Completed",
  "lastActivityAt": "Last Activity",
  "downloadDuration": "Download",
  "seedingDuration": "Seeding"
}
```

Run after editing ARB files: `flutter gen-l10n`

- [ ] **Step 4: Run l10n generation and the widget test**

Run: `flutter gen-l10n`

Expected: localization files regenerate without errors.

Run: `flutter test test/widget/transmission_task_detail_page_test.dart`

Expected: PASS with all four sections and four entry cards visible.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tasks/presentation/widgets/task_detail_entry_card.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart \
  lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_ja.arb \
  lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart \
  lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart \
  test/widget/transmission_task_detail_page_test.dart
git commit -m "feat: add transmission detail info page"
```

## Task 5: Add Transmission Child Pages And Router Navigation

**Files:**
- Create: `lib/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart`
- Create: `lib/features/tasks/presentation/pages/transmission/transmission_task_trackers_page.dart`
- Create: `lib/features/tasks/presentation/pages/transmission/transmission_task_peers_page.dart`
- Create: `lib/features/tasks/presentation/pages/transmission/transmission_task_options_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart`
- Test: `test/widget/transmission_task_child_pages_test.dart`

- [ ] **Step 1: Write the failing child-page navigation test**

```dart
testWidgets('tapping Files opens the Transmission files shell', (tester) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(
        id: 'trans-1',
        name: 'NAS',
        type: DownloaderType.transmission,
      ),
    ];
  final taskController = _SeededTaskController()
    ..seedCurrentTask(
      DownloadTask(
        id: '7',
        gid: '7',
        name: 'demo.iso',
        totalSize: 1000,
        downloaded: 1000,
        progress: 1,
        downloadSpeed: 0,
        uploadSpeed: 0,
        status: TaskStatus.completed,
        savePath: '/downloads',
        downloaderId: 'trans-1',
      ),
    );
  final router = GoRouter(
    initialLocation: '/tasks/detail/7?downloaderId=trans-1&taskName=demo.iso',
    routes: appRouter.routes,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DownloaderController>.value(
          value: downloaderController,
        ),
        ChangeNotifierProvider<TaskController>.value(
          value: taskController,
        ),
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Files'));
  await tester.pumpAndSettle();

  expect(find.text('Files'), findsWidgets);
  expect(find.text('Transmission file list will appear here'), findsOneWidget);
});
```

- [ ] **Step 2: Run the child-page widget test to verify it fails**

Run: `flutter test test/widget/transmission_task_child_pages_test.dart`

Expected: FAIL because the child routes and shell pages do not exist yet.

- [ ] **Step 3: Add the routes, shell pages, and entry navigation**

```dart
// lib/core/router/app_router.dart
GoRoute(
  path: 'detail/:id',
  name: 'task-detail',
  builder: (context, state) => TaskDetailPage(
    taskId: state.pathParameters['id']!,
    downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
    taskName: state.uri.queryParameters['taskName'] ?? '',
  ),
  routes: [
    GoRoute(
      path: 'transmission/files',
      name: 'transmission-task-files',
      builder: (context, state) => TransmissionTaskFilesPage(
        taskId: state.pathParameters['id']!,
        downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
        taskName: state.uri.queryParameters['taskName'] ?? '',
      ),
    ),
    GoRoute(
      path: 'transmission/trackers',
      name: 'transmission-task-trackers',
      builder: (context, state) => TransmissionTaskTrackersPage(
        taskId: state.pathParameters['id']!,
        downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
        taskName: state.uri.queryParameters['taskName'] ?? '',
      ),
    ),
    GoRoute(
      path: 'transmission/peers',
      name: 'transmission-task-peers',
      builder: (context, state) => TransmissionTaskPeersPage(
        taskId: state.pathParameters['id']!,
        downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
        taskName: state.uri.queryParameters['taskName'] ?? '',
      ),
    ),
    GoRoute(
      path: 'transmission/options',
      name: 'transmission-task-options',
      builder: (context, state) => TransmissionTaskOptionsPage(
        taskId: state.pathParameters['id']!,
        downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
        taskName: state.uri.queryParameters['taskName'] ?? '',
      ),
    ),
  ],
),
```

```dart
// lib/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart
class TransmissionTaskFilesPage extends StatelessWidget {
  const TransmissionTaskFilesPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;

  @override
  Widget build(BuildContext context) {
    return TaskDetailShell(
      taskId: taskId,
      downloaderId: downloaderId,
      taskName: taskName,
      onRefresh: () async {},
      body: const NeoSection(
        title: 'Files',
        child: Text('Transmission file list will appear here'),
      ),
    );
  }
}
```

```dart
// lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart
TaskDetailEntryCard(
  title: l10n.taskFilesEntry,
  subtitle: '${detail?.fileCount ?? 0} files',
  icon: Icons.folder_outlined,
  onTap: () => context.push(
    '/tasks/detail/${widget.taskId}/transmission/files'
    '?downloaderId=${widget.downloaderId}&taskName=${Uri.encodeComponent(widget.taskName)}',
  ),
),
TaskDetailEntryCard(
  title: l10n.taskTrackersEntry,
  subtitle: '${detail?.trackerCount ?? 0} trackers',
  icon: Icons.dns_outlined,
  onTap: () => context.push(
    '/tasks/detail/${widget.taskId}/transmission/trackers'
    '?downloaderId=${widget.downloaderId}&taskName=${Uri.encodeComponent(widget.taskName)}',
  ),
),
TaskDetailEntryCard(
  title: l10n.taskPeersEntry,
  subtitle: '${detail?.peerCount ?? 0} peers',
  icon: Icons.people_outline_rounded,
  onTap: () => context.push(
    '/tasks/detail/${widget.taskId}/transmission/peers'
    '?downloaderId=${widget.downloaderId}&taskName=${Uri.encodeComponent(widget.taskName)}',
  ),
),
TaskDetailEntryCard(
  title: l10n.taskOptionsEntry,
  subtitle: l10n.taskOptionsShellSubtitle,
  icon: Icons.tune_rounded,
  onTap: () => context.push(
    '/tasks/detail/${widget.taskId}/transmission/options'
    '?downloaderId=${widget.downloaderId}&taskName=${Uri.encodeComponent(widget.taskName)}',
  ),
),
```

- [ ] **Step 4: Run the child-page widget test and the router regression tests**

Run: `flutter test test/widget/transmission_task_child_pages_test.dart test/widget/task_detail_route_page_test.dart`

Expected: PASS with all child routes reachable and the dispatcher still routing Transmission tasks correctly.

- [ ] **Step 5: Commit**

```bash
git add lib/core/router/app_router.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_trackers_page.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_peers_page.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_options_page.dart \
  test/widget/transmission_task_child_pages_test.dart
git commit -m "feat: add transmission detail child routes"
```

## Task 6: Run Final Regression Tests And Polish

**Files:**
- Modify: `test/widget/task_detail_neumorphism_test.dart`
- Modify: `test/widget/transmission_task_detail_page_test.dart`
- Modify: `test/widget/transmission_task_child_pages_test.dart`
- Modify: `test/unit/transmission_rpc_adapter_test.dart`

- [ ] **Step 1: Add final regression assertions for preserved shared behavior**

```dart
testWidgets('shared shell keeps pause resume and delete actions visible', (
  tester,
) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(
        id: 'trans-1',
        name: 'NAS',
        type: DownloaderType.transmission,
      ),
    ];
  final taskController = _SeededTaskController()
    ..seedCurrentTask(
      DownloadTask(
        id: '7',
        gid: '7',
        name: 'demo.iso',
        totalSize: 1000,
        downloaded: 1000,
        progress: 1,
        downloadSpeed: 0,
        uploadSpeed: 0,
        status: TaskStatus.paused,
        savePath: '/downloads',
        downloaderId: 'trans-1',
      ),
    );

  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      taskController: taskController,
      child: ChangeNotifierProvider(
        create: (_) => TransmissionTaskDetailController(
          serviceFactory: (_) => FakeTransmissionService.success(
            const TransmissionTaskDetail(
              taskId: '7',
              name: 'demo.iso',
              downloaderId: 'trans-1',
              totalSize: 1000,
              pieceCount: 20,
              pieceSize: 50,
              savePath: '/downloads',
              isPrivate: true,
              creator: 'Transmission',
              createdAt: null,
              magnet: 'magnet:?xt=urn:btih:abc',
              availablePercent: 1,
              downloadedEver: 1000,
              uploadedEver: 100,
              ratio: 0.1,
              averageSpeed: 10,
              addedAt: null,
              completedAt: null,
              lastActivityAt: null,
              downloadDuration: Duration.zero,
              seedingDuration: Duration.zero,
              fileCount: 1,
              trackerCount: 1,
              peerCount: 1,
              optionsEditable: true,
            ),
          ),
        ),
        child: const TransmissionTaskDetailPage(
          taskId: '7',
          downloaderId: 'trans-1',
          taskName: 'demo.iso',
        ),
      ),
    ),
  );
  await tester.pump();

  expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);
  expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
  expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
});
```

- [ ] **Step 2: Run the targeted regression suite and confirm failures are real**

Run: `flutter test test/widget/task_detail_neumorphism_test.dart test/widget/transmission_task_detail_page_test.dart test/widget/transmission_task_child_pages_test.dart test/unit/transmission_rpc_adapter_test.dart`

Expected: FAIL only if shared-shell regressions or localization mismatches remain.

- [ ] **Step 3: Fix the remaining regressions and regenerate l10n if needed**

```dart
// Example polish in transmission_task_detail_page.dart
if (detailController.isLoading && detail == null) {
  return TaskDetailShell(
    taskId: widget.taskId,
    downloaderId: widget.downloaderId,
    taskName: widget.taskName,
    onRefresh: _load,
    body: const Center(child: CircularProgressIndicator()),
  );
}

if (detailController.errorMessage != null && detail == null) {
  return TaskDetailShell(
    taskId: widget.taskId,
    downloaderId: widget.downloaderId,
    taskName: widget.taskName,
    onRefresh: _load,
    body: NeoSection(
      title: AppLocalizations.of(context)!.taskMoreDetails,
      child: Text(detailController.errorMessage!),
    ),
  );
}
```

```bash
flutter gen-l10n
```

- [ ] **Step 4: Run the full targeted suite to verify everything passes**

Run: `flutter test test/widget/task_detail_neumorphism_test.dart test/widget/task_detail_route_page_test.dart test/widget/transmission_task_detail_page_test.dart test/widget/transmission_task_child_pages_test.dart test/unit/transmission_task_detail_controller_test.dart test/unit/transmission_rpc_adapter_test.dart`

Expected: PASS across all six test files.

- [ ] **Step 5: Commit**

```bash
git add test/widget/task_detail_neumorphism_test.dart \
  test/widget/task_detail_route_page_test.dart \
  test/widget/transmission_task_detail_page_test.dart \
  test/widget/transmission_task_child_pages_test.dart \
  test/unit/transmission_task_detail_controller_test.dart \
  test/unit/transmission_rpc_adapter_test.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart \
  lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_ja.arb \
  lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart \
  lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart
git commit -m "test: verify transmission detail flow"
```
