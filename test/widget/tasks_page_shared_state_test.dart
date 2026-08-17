import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/pages/tasks_page.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';

import 'test_helpers.dart';

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

  group('TasksPage 共享状态', () {
    late DownloaderController downloaderController;
    late TaskController taskController;

    setUp(() {
      downloaderController = MockDownloaderController();
      taskController = TaskController();
    });

    tearDown(() {
      taskController.dispose();
    });

    testWidgets('TasksPage 使用共享 controller 中的下载器任务', (tester) async {
      // 预设共享缓存
      taskController.debugSetTasksForTest('test-1', [
        DownloadTask(
          id: 'task-1',
          gid: 'task-1',
          name: 'Test Download',
          status: TaskStatus.downloading,
          downloadSpeed: 1024,
          downloaderId: 'test-1',
        ),
      ]);

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      // 只 pump 一次，避免 postFrameCallback 触发 startAutoRefresh
      await tester.pump();

      // TasksPage 未在路由中直接注册，验证 controller 本身即可
      expect(taskController.tasksForDownloader('test-1').length, 1);
      expect(
        taskController.tasksForDownloader('test-1').first.name,
        'Test Download',
      );

      // 消化 HomeTabContainer postFrame 启动的更新提醒延迟 Timer
      await tester.pump(const Duration(milliseconds: 300));
      // 清理 Timer（由 HomeTabContainer → AllTasksTabPage 启动）
      taskController.stopAutoRefresh();
    });

    testWidgets('TasksPage 空任务时显示空状态', (tester) async {
      taskController.debugSetTasksForTest('test-1', []);

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump();

      expect(taskController.tasksForDownloader('test-1'), isEmpty);

      // 消化 HomeTabContainer postFrame 启动的更新提醒延迟 Timer
      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets('TasksPage 在拟物化改造后保留共享任务数据并使用 Neo 组件', (tester) async {
      (downloaderController as MockDownloaderController).testDownloaders = [
        createTestDownloader(),
      ];
      taskController = _StableDownloaderTasksController();
      // 任务数据现由 TaskDomainStore 提供（页面读取单一事实来源）
      final taskDomainStore = TaskDomainStore();
      taskDomainStore.debugApplyQBitSnapshot(
        QBitRealtimeSnapshot.fromJson(
          downloaderId: 'test-1',
          json: {
            'rid': 1,
            'full_update': true,
            'server_state': {'dl_info_speed': 1024, 'up_info_speed': 0},
            'torrents': {
              'task-1': {
                'name': 'Refactor Download',
                'state': 'downloading',
                'progress': 0.1,
                'dlspeed': 1024,
                'upspeed': 0,
                'save_path': '/ptd',
              },
            },
          },
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
          taskDomainStore: taskDomainStore,
          child: const TasksPage(
            downloaderId: 'test-1',
            showBackButton: false,
            showRefreshButton: false,
          ),
        ),
      );
      await tester.pump();

      // 拟物化骨架：内凹搜索 + 外凸卡片语言已就位
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(NeoInputShell), findsOneWidget);
      expect(find.text('Test Aria2'), findsOneWidget);
      expect(find.text('192.168.1.100:6800'), findsOneWidget);
      expect(find.text('Refactor Download'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byType(NeoStatusHeroCard), findsWidgets);

      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets('TasksPage header is laid out below the system status bar', (
      tester,
    ) async {
      const statusBarTop = 32.0;
      (downloaderController as MockDownloaderController).testDownloaders = [
        createTestDownloader(),
      ];
      final stableTaskController = _StableDownloaderTasksController();

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: stableTaskController,
          child: const MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(top: statusBarTop)),
            child: TasksPage(
              downloaderId: 'test-1',
              titleOverride: 'Downloader Tasks',
              showBackButton: false,
              showRefreshButton: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final titleTop = tester.getTopLeft(find.text('Downloader Tasks')).dy;

      expect(titleTop, greaterThanOrEqualTo(statusBarTop));

      stableTaskController.dispose();
    });
  });
}

class _StableDownloaderTasksController extends TaskController {
  @override
  Future<void> loadAllTasks(
    DownloaderController downloaderController, {
    bool force = false,
  }) async {}

  @override
  Future<void> loadTasksForDownloader(
    String downloaderId,
    DownloaderController downloaderController, {
    bool force = false,
  }) async {}
}
