import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/realtime/presentation/controllers/realtime_sync_controller.dart';
import 'package:windwalker/features/home/presentation/pages/home_tab_container.dart';
import 'package:windwalker/features/home/presentation/pages/management_tab.dart';
import 'package:windwalker/features/add_task/presentation/pages/add_task_page.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_config_page.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_editor_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/tasks_page.dart';
import 'package:windwalker/features/add_task/presentation/services/torrent_file_picker.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_controller.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_backup_controller.dart';
import 'package:windwalker/features/settings/presentation/pages/about_page.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_detail_controller.dart';
import 'package:windwalker/features/settings/presentation/pages/settings_page.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_backup_version.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/speed_config_descriptor.dart';
import 'package:windwalker/models/transmission_realtime_snapshot.dart';
import 'package:windwalker/services/connection_result.dart';

/// Mock TaskController — extends real controller so
/// Provider resolves correctly. Records addTask calls for assertions.
class MockTaskController extends TaskController {
  AddTaskRequest? lastAddTaskRequest;

  @override
  Future<bool> addTask(
    AddTaskRequest request,
    DownloaderController downloaderController,
  ) async {
    lastAddTaskRequest = request;
    return true;
  }
}

/// Mock DownloaderController — extends real controller so
/// Consumer DownloaderController resolves correctly.
/// Overrides network/timer methods to be no-ops for testing.
class MockDownloaderController extends DownloaderController {
  final List<Downloader> _testDownloaders = [];
  final Map<String, int> _testGlobalStats = {
    'downloading': 0,
    'waiting': 0,
    'paused': 0,
    'completed': 0,
    'error': 0,
    'seeding': 0,
    'total': 0,
    'totalSpeed': 0,
    'uploadSpeed': 0,
    'downloaderCount': 0,
    'onlineCount': 0,
  };
  SpeedConfigDescriptor? testSpeedConfigDescriptor;
  DownloaderSpeedConfig? testSpeedConfig;
  DownloaderSpeedConfig? savedSpeedConfig;
  bool saveSpeedConfigResult = true;
  Downloader? updatedDownloader;
  Downloader? addedDownloader;

  MockDownloaderController() : super();

  /// Inject test downloaders for testing
  set testDownloaders(List<Downloader> downloaders) {
    _testDownloaders.clear();
    _testDownloaders.addAll(downloaders);
    notifyListeners();
  }

  /// Inject aggregated global stats for testing overview widgets.
  set testGlobalStats(Map<String, int> stats) {
    _testGlobalStats
      ..clear()
      ..addAll(stats);
    notifyListeners();
  }

  @override
  List<Downloader> get downloaders => List.unmodifiable(_testDownloaders);

  @override
  Downloader? getDownloader(String id) {
    return _testDownloaders
        .where((downloader) => downloader.id == id)
        .firstOrNull;
  }

  @override
  Map<String, int> get globalStats => Map.unmodifiable(_testGlobalStats);

  @override
  void init() {}

  @override
  Future<void> loadDownloaders() async {}

  @override
  Future<void> refreshAllStatus() async {}

  @override
  Future<void> refreshGlobalStats() async {}

  @override
  Future<void> refreshStatus(String id, {bool notify = true}) async {}

  @override
  Future<ConnectionResult> testConnection(Downloader downloader) async =>
      const ConnectionSuccess();

  @override
  void stopPeriodicRefresh() {}

  @override
  SpeedConfigDescriptor? getSpeedConfigDescriptor(String downloaderId) =>
      testSpeedConfigDescriptor;

  @override
  Future<DownloaderSpeedConfig?> getSpeedConfig(String downloaderId) async =>
      testSpeedConfig;

  @override
  Future<bool> setSpeedConfig(
    String downloaderId,
    DownloaderSpeedConfig config,
  ) async {
    savedSpeedConfig = config;
    return saveSpeedConfigResult;
  }

  AddTaskRequest? lastAddTaskRequest;

  Future<String> addTask(AddTaskRequest request) async {
    lastAddTaskRequest = request;
    return 'mock-task-id';
  }

  Future<String> addDownload(
    String downloaderId,
    String url, {
    String? savePath,
  }) {
    return addTask(
      AddTaskRequest(downloaderId: downloaderId, url: url, savePath: savePath),
    );
  }

  @override
  Future<ConnectionResult> updateDownloader(Downloader downloader) async {
    updatedDownloader = downloader;
    return const ConnectionSuccess();
  }

  @override
  Future<ConnectionResult> addDownloader(Downloader downloader) async {
    addedDownloader = downloader;
    return const ConnectionSuccess();
  }

  /// Records the most recently removed downloader id, for delete assertions.
  String? removedDownloaderId;

  @override
  Future<void> removeDownloader(String id) async {
    removedDownloaderId = id;
  }
}

/// Pump the app with mock providers for testing.
/// Creates a fresh GoRouter per call to avoid shared state between tests.
Widget createTestApp({
  required DownloaderController downloaderController,
  TaskController? taskController,
  TaskDomainStore? taskDomainStore,
  RealtimeSyncController? realtimeSyncController,
  SettingsController? settingsController,
  SettingsBackupController? settingsBackupController,
  UpdateController? updateController,
  String initialLocation = '/',
  Widget? child,
}) {
  // Fresh router per test to avoid state pollution
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeTabContainer(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'webdav',
            name: 'settings-webdav',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
      GoRoute(
        path: '/downloaders',
        name: 'downloaders',
        builder: (context, state) => const ManagementTab(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        builder: (context, state) {
          final downloaderId = state.uri.queryParameters['id'];
          final downloaderTypeStr = state.uri.queryParameters['type'];
          final downloaderType = downloaderTypeStr != null
              ? DownloaderType.values.firstWhere(
                  (e) => e.name == downloaderTypeStr,
                  orElse: () => DownloaderType.aria2,
                )
              : null;
          return TasksPage(
            downloaderId: downloaderId,
            downloaderType: downloaderType,
          );
        },
      ),
      GoRoute(
        path: '/downloaders/new',
        name: 'downloader-create',
        builder: (context, state) => const DownloaderEditorPage(),
      ),
      GoRoute(
        path: '/downloaders/:id/edit',
        name: 'downloader-edit',
        builder: (context, state) =>
            DownloaderEditorPage(downloaderId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/downloaders/:id/config',
        name: 'downloader-config',
        builder: (context, state) =>
            DownloaderConfigPage(downloaderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppConstants.addTaskRoute,
        name: 'addTask',
        builder: (context, state) => const AddTaskPage(),
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DownloaderController>.value(
        value: downloaderController,
      ),
      ChangeNotifierProvider<TaskController>.value(
        value: taskController ?? TaskController(),
      ),
      // 任务域单一事实来源（页面读取 qBit / Transmission 共享任务态）
      ChangeNotifierProvider<TaskDomainStore>.value(
        value: taskDomainStore ?? TaskDomainStore(),
      ),
      ChangeNotifierProvider<RealtimeSyncController>.value(
        value: realtimeSyncController ?? buildRealtimeSyncControllerForTest(),
      ),
      ChangeNotifierProvider<TransmissionTaskDetailController>.value(
        value: TransmissionTaskDetailController(),
      ),
      ChangeNotifierProvider<SettingsController>.value(
        value: settingsController ?? SettingsController(),
      ),
      ChangeNotifierProvider<SettingsBackupController>.value(
        value: settingsBackupController ?? FakeSettingsBackupController(),
      ),
      ChangeNotifierProvider<UpdateController>.value(
        value:
            updateController ??
            buildUpdateControllerForTest(
              result: const UpdateCheckResult.unknown(),
              shouldOfferDialog: false,
            ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
      locale: const Locale('en'),
      builder: (context, routed) {
        if (child == null) return routed!;
        // When a page is injected directly (bypassing the router), give it a
        // Navigator ancestor so widgets like PopupMenuButton find an Overlay.
        return Navigator(
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: (_) => Material(child: child)),
        );
      },
    ),
  );
}

/// Create a test Downloader instance
Downloader createTestDownloader({
  String id = 'test-1',
  String name = 'Test Aria2',
  DownloaderType type = DownloaderType.aria2,
  String host = '192.168.1.100',
  int port = 6800,
  DownloaderStatus status = DownloaderStatus.online,
  int taskCount = 5,
  int downloadSpeed = 1048576,
  int uploadSpeed = 0,
  Map<String, int>? taskStats,
  String? version,
  bool useHttps = false,
}) {
  return Downloader(
    id: id,
    name: name,
    type: type,
    host: host,
    port: port,
    status: status,
    taskCount: taskCount,
    downloadSpeed: downloadSpeed,
    uploadSpeed: uploadSpeed,
    taskStats: taskStats ?? {},
    version: version,
    useHttps: useHttps,
  );
}

/// Fake UpdateController — overrides state getters and async methods so
/// widget tests can drive update UI without hitting Play services or storage.
class FakeUpdateController extends UpdateController {
  FakeUpdateController({
    required UpdateCheckResult result,
    required bool shouldOfferDialog,
  }) : _result = result,
       _shouldOfferDialog = shouldOfferDialog,
       super();

  final UpdateCheckResult _result;
  final bool _shouldOfferDialog;

  @override
  bool get hasUpdate => _result.hasUpdate;

  @override
  UpdateCheckStatus get status => _result.status;

  @override
  int? get availableVersionCode => _result.availableVersionCode;

  @override
  bool get shouldShowUpdateBadge => _result.hasUpdate;

  @override
  bool get shouldOfferUpdateDialog => _shouldOfferDialog;

  @override
  Future<void> runSilentCheck({DateTime? now}) async {}

  @override
  Future<void> checkForUpdatesManually() async {}
}

/// Fake SettingsBackupController — overrides state getters and async methods
/// so widget tests can drive backup UI without hitting Drive API.
class FakeSettingsBackupController extends SettingsBackupController {
  FakeSettingsBackupController() : super();

  FakeSettingsBackupController.configured() : super() {
    _fakeHasConfig = true;
  }

  FakeSettingsBackupController.unconfigured() : super();

  bool _fakeHasConfig = false;
  final WebDavConfig _fakeConfig = const WebDavConfig(
    rootUrl: 'https://dav.example.com/root/',
    remoteDirectory: 'WindTorrent/Backups',
    username: 'tester',
    password: 'secret',
  );

  List<DownloaderBackupVersion>? _seededBackups;

  /// Pre-populate available backups for testing the version list sheet.
  void seedAvailableBackups(List<DownloaderBackupVersion> backups) {
    _seededBackups = backups;
  }

  @override
  bool get hasConfig => _fakeHasConfig;

  @override
  WebDavConfig? get config => _fakeHasConfig ? _fakeConfig : null;

  @override
  String? get configSummary =>
      _fakeHasConfig ? _fakeConfig.maskedSummary : null;

  @override
  List<DownloaderBackupVersion> get availableBackups =>
      _seededBackups ?? super.availableBackups;

  @override
  Future<void> exportBackup() async {}

  @override
  Future<void> loadAvailableBackups() async {}

  @override
  Future<void> restoreBackup({required String fileId}) async {}

  @override
  Future<void> deleteBackup({required String fileId}) async {
    _seededBackups = (_seededBackups ?? <DownloaderBackupVersion>[])
        .where((backup) => backup.fileId != fileId)
        .toList();
    notifyListeners();
  }

  @override
  Future<void> undoLastRestore() async {}
}

UpdateController buildUpdateControllerForTest({
  required UpdateCheckResult result,
  required bool shouldOfferDialog,
}) {
  return FakeUpdateController(
    result: result,
    shouldOfferDialog: shouldOfferDialog,
  );
}

/// 构建测试用 `RealtimeSyncController`。
///
/// 注入空轮询工厂，避免测试触发真实网络请求；不调用 `start()`，避免启动 timer。
/// 调用方可通过 [downloaderController] / [taskDomainStore] 绑定下游，
/// 以便 `refreshNow()` 的回写逻辑（写入 TaskDomainStore）在测试中可见。
RealtimeSyncController buildRealtimeSyncControllerForTest({
  DownloaderController? downloaderController,
  TaskDomainStore? taskDomainStore,
}) {
  final controller = RealtimeSyncController(
    qbitPollerFactory: (_, _) async => <String, dynamic>{
      'rid': 0,
      'full_update': true,
      'torrents': <String, dynamic>{},
    },
    transmissionPollerFactory: (_) async =>
        TransmissionRealtimeSnapshot.fromRpc(
          downloaderId: '',
          torrents: const [],
        ),
  );
  if (downloaderController != null) {
    controller.attach(downloaderController: downloaderController);
  }
  if (taskDomainStore != null) {
    controller.attachStore(taskDomainStore);
  }
  return controller;
}

/// Fake TorrentFilePicker for testing
class FakeTorrentFilePicker extends TorrentFilePicker {
  final PickedTorrentFile? result;

  FakeTorrentFilePicker({this.result});

  @override
  Future<PickedTorrentFile?> pick() async => result;
}

/// Pump the AddTaskPage with mock providers for testing.
Widget createAddTaskTestApp({
  required DownloaderController downloaderController,
  TaskController? taskController,
  TorrentFilePicker? torrentFilePicker,
  Future<String?> Function(Downloader downloader)? defaultSavePathLoader,
}) {
  final router = GoRouter(
    initialLocation: '/add-task',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'add-task',
            builder: (context, state) => AddTaskPage(
              torrentFilePicker: torrentFilePicker,
              defaultSavePathLoader: defaultSavePathLoader,
            ),
          ),
        ],
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DownloaderController>.value(
        value: downloaderController,
      ),
      ChangeNotifierProvider<TaskController>.value(
        value: taskController ?? TaskController(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
      locale: const Locale('zh'),
    ),
  );
}
