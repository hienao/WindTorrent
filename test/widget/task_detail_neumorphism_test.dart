import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/pages/task_detail_page.dart';
import 'package:windwalker/models/download_task.dart';

import 'test_helpers.dart';

void main() {
  late MockDownloaderController downloaderController;
  late _TaskDetailController taskController;

  DownloadTask buildTask({
    String id = 'task-1',
    String downloaderId = 'test-1',
    TaskStatus status = TaskStatus.downloading,
  }) {
    return DownloadTask(
      id: id,
      gid: 'gid-1',
      name: 'ubuntu.iso',
      totalSize: 1024 * 1024 * 1024,
      downloaded: 512 * 1024 * 1024,
      progress: 0.5,
      downloadSpeed: 2 * 1024 * 1024,
      uploadSpeed: 128 * 1024,
      status: status,
      savePath: '/downloads',
      downloaderId: downloaderId,
      seeders: 12,
      peers: 5,
      connections: 8,
      tracker: 'https://tracker.example/announce',
      fileCount: 1,
    );
  }

  Widget buildSubject({
    String pageTaskId = 'task-1',
    String pageDownloaderId = 'test-1',
    DownloadTask? currentTask,
    TaskStatus status = TaskStatus.downloading,
  }) {
    downloaderController = MockDownloaderController()
      ..testDownloaders = [createTestDownloader(id: 'test-1', name: 'NAS')];
    taskController = _TaskDetailController();
    final task = currentTask ?? buildTask(status: status);
    // 任务态现由 TaskDomainStore 提供（页面读取单一事实来源）
    final taskDomainStore = TaskDomainStore()
      ..debugSetTasksForDownloader(
        task.downloaderId,
        [task],
      );

    return createTestApp(
      downloaderController: downloaderController,
      taskController: taskController,
      taskDomainStore: taskDomainStore,
      child: TaskDetailPage(
        taskId: pageTaskId,
        downloaderId: pageDownloaderId,
        taskName: 'Fallback name',
      ),
    );
  }

  Future<void> disposeSubject(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // 允许 Shell 的 5s 自动刷新 Timer 在 dispose 后被完全取消，
    // 避免「Timer is still pending」断言失败。
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  }

  testWidgets('renders neumorphic task detail sections', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(NeoPageHeader), findsOneWidget);
    expect(find.byType(NeoStatusHeroCard), findsOneWidget);
    expect(find.text('ubuntu.iso'), findsOneWidget);
    expect(find.text('Download Info'), findsOneWidget);
    expect(find.text('Connection Info'), findsOneWidget);
    expect(find.byType(NeoActionBar), findsOneWidget);

    await disposeSubject(tester);
  });

  testWidgets('keeps pause resume and delete actions visible', (tester) async {
    await tester.pumpWidget(buildSubject(status: TaskStatus.paused));
    await tester.pump();

    expect(find.byType(NeoActionBar), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);

    await disposeSubject(tester);
  });

  testWidgets('does not enable actions from a stale current task', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        pageTaskId: 'task-2',
        currentTask: buildTask(id: 'task-1', status: TaskStatus.downloading),
      ),
    );
    await tester.pump();

    final pause = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Pause'),
    );
    final resume = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Resume'),
    );

    expect(find.text('Fallback name'), findsOneWidget);
    expect(pause.onPressed, isNull);
    expect(resume.onPressed, isNull);
    expect(taskController.currentTask, isNull);

    await disposeSubject(tester);
  });
}

class _TaskDetailController extends TaskController {
  void seedCurrentTask(DownloadTask task) {
    debugSetCurrentTaskForTest(task);
  }

  @override
  Future<void> loadTaskDetailForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController,
  ) async {}

  @override
  Future<void> pauseTaskForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController,
  ) async {}

  @override
  Future<void> resumeTaskForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController,
  ) async {}

  @override
  Future<void> removeTaskForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController, {
    bool deleteFiles = false,
  }) async {}
}
