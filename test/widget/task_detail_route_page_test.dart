import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/aria2/aria2_task_detail_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/task_detail_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';

import 'test_helpers.dart';

void main() {
  testWidgets(
      'dispatches transmission tasks to TransmissionTaskDetailPage', (tester) async {
    final downloaderController = MockDownloaderController()
      ..testDownloaders = [
        createTestDownloader(
          id: 'trans-1',
          name: 'NAS',
          type: DownloaderType.transmission,
        ),
      ];
    final taskController = _StubTaskController();

    await tester.pumpWidget(
      createTestApp(
        downloaderController: downloaderController,
        taskController: taskController,
        child: const TaskDetailPage(
          taskId: '7',
          downloaderId: 'trans-1',
          taskName: 'demo.iso',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TransmissionTaskDetailPage), findsOneWidget);

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets(
      'dispatches aria2 tasks to Aria2TaskDetailPage', (tester) async {
    final downloaderController = MockDownloaderController()
      ..testDownloaders = [
        createTestDownloader(id: 'aria-1', name: 'NAS', type: DownloaderType.aria2),
      ];
    final taskController = _StubTaskController();

    await tester.pumpWidget(
      createTestApp(
        downloaderController: downloaderController,
        taskController: taskController,
        child: const TaskDetailPage(
          taskId: '7',
          downloaderId: 'aria-1',
          taskName: 'demo.iso',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TransmissionTaskDetailPage), findsNothing);
    expect(find.byType(Aria2TaskDetailPage), findsOneWidget);

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets(
      'Aria2 detail page 仍走 TaskController 详情加载路径', (tester) async {
    final downloaderController = MockDownloaderController()
      ..testDownloaders = [
        createTestDownloader(id: 'aria-1', name: 'NAS', type: DownloaderType.aria2),
      ];
    final taskController = _StubTaskController();

    await tester.pumpWidget(
      createTestApp(
        downloaderController: downloaderController,
        taskController: taskController,
        child: const TaskDetailPage(
          taskId: 'gid-1',
          downloaderId: 'aria-1',
          taskName: 'demo',
        ),
      ),
    );

    await tester.pump();
    // Aria2 不纳入全局实时轮询，首次进入仍通过 loadTaskDetailForDownloader 加载详情。
    expect(taskController.loadTaskDetailCallCount, 1);

    // 销毁页面避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets('dispatches qbittorrent tasks to QBitTaskDetailPage',
      (tester) async {
    final downloaderController = MockDownloaderController()
      ..testDownloaders = [
        createTestDownloader(
          id: 'qbit-1',
          name: 'Seedbox',
          type: DownloaderType.qbittorrent,
        ),
      ];
    final taskController = _StubTaskController();

    await tester.pumpWidget(
      createTestApp(
        downloaderController: downloaderController,
        taskController: taskController,
        child: const TaskDetailPage(
          taskId: 'abc',
          downloaderId: 'qbit-1',
          taskName: 'Three Kingdoms',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(QBitTaskDetailPage), findsOneWidget);

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });
}

/// TaskController stub that no-ops network/timer methods so the dispatcher
/// page doesn't trigger real loads or auto-refresh during tests.
class _StubTaskController extends TaskController {
  _StubTaskController();

  int loadTaskDetailCallCount = 0;

  @override
  Future<void> loadTaskDetailForDownloader(
    String taskId,
    String downloaderId,
    DownloaderController downloaderController,
  ) async {
    loadTaskDetailCallCount++;
  }

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
