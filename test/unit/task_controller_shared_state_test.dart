import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/download_task.dart';

/// 用于 TaskController 单元测试的最小化 Mock DownloaderController
/// 继承 DownloaderController 以确保类型兼容
class MockDownloaderControllerForTask extends DownloaderController {
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
}

/// 创建测试用 DownloadTask
DownloadTask createTestTask({
  String id = 'test-task',
  String name = 'Test Task',
  int downloadSpeed = 0,
  int uploadSpeed = 0,
  TaskStatus status = TaskStatus.downloading,
  String downloaderId = 'd1',
}) {
  return DownloadTask(
    id: id,
    gid: id,
    name: name,
    downloadSpeed: downloadSpeed,
    uploadSpeed: uploadSpeed,
    status: status,
    downloaderId: downloaderId,
  );
}

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

  group('TaskController 共享状态', () {
    late TaskController controller;

    setUp(() {
      controller = TaskController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('tasksForDownloader 应返回对应下载器缓存', () {
      controller.debugSetTasksForTest('d1', []);
      controller.debugSetTasksForTest('d2', []);

      expect(controller.tasksForDownloader('d1'), isA<List>());
      expect(controller.tasksForDownloader('d2'), isA<List>());
      // 未设置的下载器返回空列表
      expect(controller.tasksForDownloader('unknown'), isEmpty);
    });

    test('allTasks 应聚合所有下载器的任务并按速度排序', () {
      controller.debugSetTasksForTest('d1', [
        createTestTask(id: 't1', name: 'Task 1', downloadSpeed: 100),
      ]);
      controller.debugSetTasksForTest('d2', [
        createTestTask(id: 't2', name: 'Task 2', downloadSpeed: 500),
      ]);

      final all = controller.allTasks;
      expect(all.length, 2);
      // 按下载速度降序排列
      expect(all[0].downloadSpeed, 500);
      expect(all[1].downloadSpeed, 100);
    });

    test('isLoadingDownloader 应反映单个下载器的加载状态', () {
      expect(controller.isLoadingDownloader('d1'), isFalse);
    });

    test('isRefreshingAll 初始为 false', () {
      expect(controller.isRefreshingAll, isFalse);
    });

    test('TaskController 对 qBit / Transmission 读取委托给 TaskDomainStore', () {
      final store = TaskDomainStore();
      final storeController = TaskController(taskDomainStore: store);

      store.debugSetTasksForDownloader('q1', [
        DownloadTask(
          id: 'abc',
          gid: 'abc',
          name: 'demo',
          downloaderId: 'q1',
        ),
      ]);

      expect(storeController.tasksForDownloader('q1').single.name, 'demo');
      expect(storeController.taskForDownloader('q1', 'abc')?.name, 'demo');
      expect(storeController.taskForDownloader('q1', 'missing'), isNull);
      // 未设置数据的下载器返回空
      expect(storeController.tasksForDownloader('unknown'), isEmpty);

      storeController.dispose();
    });

    group('共享任务操作入口', () {
      test('addTask 在 downloader 不存在时应返回 false', () async {
        final mockDc = MockDownloaderControllerForTask();
        final result = await controller.addTask(
          AddTaskRequest(
            downloaderId: 'nonexistent',
            url: 'http://example.com/file.zip',
          ),
          mockDc,
        );
        expect(result, isFalse);
      });

      test('pauseTaskForDownloader 在 downloader 不存在时应安全返回', () async {
        final mockDc = MockDownloaderControllerForTask();
        // 不应抛异常
        await controller.pauseTaskForDownloader('task-1', 'nonexistent', mockDc);
      });

      test('resumeTaskForDownloader 在 downloader 不存在时应安全返回', () async {
        final mockDc = MockDownloaderControllerForTask();
        await controller.resumeTaskForDownloader('task-1', 'nonexistent', mockDc);
      });

      test('removeTaskForDownloader 在 downloader 不存在时应安全返回', () async {
        final mockDc = MockDownloaderControllerForTask();
        await controller.removeTaskForDownloader('task-1', 'nonexistent', mockDc);
      });

      test('hasActiveTransfers 为 true when downloading or waiting task exists', () {
        controller.debugSetTasksForTest('d1', [
          createTestTask(id: 't1', status: TaskStatus.downloading),
          createTestTask(id: 't2', status: TaskStatus.paused),
        ]);

        expect(controller.hasActiveTransfers, isTrue);
      });
    });
  });
}
