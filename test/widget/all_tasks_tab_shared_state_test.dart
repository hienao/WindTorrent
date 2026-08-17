import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/home/presentation/pages/all_tasks_tab_page.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
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

  group('AllTasksTabPage 共享状态', () {
    late DownloaderController downloaderController;
    late TaskController taskController;

    setUp(() {
      downloaderController = MockDownloaderController();
      taskController = TaskController();
    });

    tearDown(() {
      taskController.dispose();
    });

    testWidgets('AllTasksTabPage 使用共享 controller 聚合任务', (tester) async {
      taskController.debugSetTasksForTest('d1', [
        DownloadTask(
          id: 't1',
          gid: 't1',
          name: 'Task A',
          downloadSpeed: 500,
          status: TaskStatus.downloading,
          downloaderId: 'd1',
        ),
      ]);
      taskController.debugSetTasksForTest('d2', [
        DownloadTask(
          id: 't2',
          gid: 't2',
          name: 'Task B',
          downloadSpeed: 100,
          status: TaskStatus.waiting,
          downloaderId: 'd2',
        ),
      ]);

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump();

      // 验证共享聚合逻辑
      final all = taskController.allTasks;
      expect(all.length, 2);
      expect(all[0].downloadSpeed, 500);
      expect(all[1].downloadSpeed, 100);

      // 消化 HomeTabContainer postFrame 启动的更新提醒延迟 Timer
      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets('AllTasksTabPage 初始无任务时 allTasks 为空', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump();

      expect(taskController.allTasks, isEmpty);

      // 消化 HomeTabContainer postFrame 启动的更新提醒延迟 Timer
      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets('AllTasksTabPage 在拟物化改造后仍显示搜索框与任务卡片', (tester) async {
      (downloaderController as MockDownloaderController).testDownloaders = [
        createTestDownloader(),
      ];
      taskController = _StableAllTasksController();
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
          child: const AllTasksTabPage(),
        ),
      );
      await tester.pump();

      // 拟物化骨架：内凹搜索 + 外凸卡片语言已就位
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(NeoInputShell), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets('All tasks tab uses Neo filter strip and v2 task cards', (
      tester,
    ) async {
      final downloaderController = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(id: 'test-1', name: 'NAS Aria2'),
        ];
      final taskController = _StableAllTasksController();
      // 任务数据现由 TaskDomainStore 提供（页面读取单一事实来源）
      final taskDomainStore = TaskDomainStore();
      taskDomainStore.debugApplyQBitSnapshot(
        QBitRealtimeSnapshot.fromJson(
          downloaderId: 'test-1',
          json: {
            'rid': 1,
            'full_update': true,
            'server_state': {'dl_info_speed': 2048, 'up_info_speed': 0},
            'torrents': {
              'task-1': {
                'name': 'Global Download',
                'state': 'downloading',
                'progress': 0.1,
                'dlspeed': 2048,
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
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Task List'));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(NeoPageHeader),
          matching: find.text('Task List'),
        ),
        findsOneWidget,
      );
      expect(find.text('Global Download'), findsOneWidget);
      expect(find.byType(NeoFilterStrip<TaskStatus?>), findsOneWidget);
      expect(find.byType(NeoStatusHeroCard), findsWidgets);

      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets(
      'AllTasksTabPage header is laid out below the system status bar',
      (tester) async {
        const statusBarTop = 32.0;

        await tester.pumpWidget(
          createTestApp(
            downloaderController: downloaderController,
            taskController: taskController,
            child: const MediaQuery(
              data: MediaQueryData(padding: EdgeInsets.only(top: statusBarTop)),
              child: AllTasksTabPage(),
            ),
          ),
        );
        await tester.pump();

        final titleTop = tester.getTopLeft(find.text('Task List')).dy;

        expect(titleTop, greaterThanOrEqualTo(statusBarTop));

        await tester.pump(const Duration(milliseconds: 300));
        taskController.stopAutoRefresh();
      },
    );
  });
}

class _StableAllTasksController extends TaskController {
  @override
  Future<void> loadAllTasks(
    DownloaderController downloaderController, {
    bool force = false,
  }) async {}
}
