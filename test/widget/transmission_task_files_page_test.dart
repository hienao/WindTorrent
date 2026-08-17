import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_files_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_file_node.dart';
import 'package:windwalker/services/transmission_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';

import 'test_helpers.dart';

void main() {
  const fakeFiles = [
    TransmissionTaskFileNode(
      path: 'dir1',
      name: 'dir1',
      isDirectory: true,
      size: 2048,
      downloaded: 1024,
      progress: 0.5,
      children: [
        TransmissionTaskFileNode(
          path: 'dir1/file1.txt',
          name: 'file1.txt',
          isDirectory: false,
          size: 1024,
          downloaded: 1024,
          progress: 1.0,
        ),
        TransmissionTaskFileNode(
          path: 'dir1/file2.txt',
          name: 'file2.txt',
          isDirectory: false,
          size: 1024,
          downloaded: 512,
          progress: 0.5,
        ),
      ],
    ),
    TransmissionTaskFileNode(
      path: 'readme.md',
      name: 'readme.md',
      isDirectory: false,
      size: 500,
      downloaded: 500,
      progress: 1.0,
    ),
  ];

  group('TransmissionTaskFilesPage', () {
    testWidgets('shows loading indicator while loading', (tester) async {
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

      // 使用永不完成的 future 保持 loading 状态
      final filesController = TransmissionTaskFilesController(
        serviceFactory: (_) => _NeverCompleteTransmissionService(),
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
          child: TransmissionTaskFilesPage(
            taskId: '7',
            downloaderId: 'trans-1',
            taskName: 'demo.iso',
            controller: filesController,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });

    testWidgets('shows file and directory names after loading', (tester) async {
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

      final filesController = TransmissionTaskFilesController(
        serviceFactory: (_) => FakeTransmissionFilesService(fakeFiles),
      );

      // 预加载数据
      await filesController.load(
        taskId: '7',
        downloader: downloaderController.getDownloader('trans-1')!,
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
          child: TransmissionTaskFilesPage(
            taskId: '7',
            downloaderId: 'trans-1',
            taskName: 'demo.iso',
            controller: filesController,
          ),
        ),
      );
      await tester.pump();

      // 目录名和根文件应可见
      expect(find.text('dir1'), findsOneWidget);
      expect(find.text('readme.md'), findsOneWidget);
      // 第一层目录默认展开，子文件应可见
      expect(find.text('file1.txt'), findsOneWidget);
      expect(find.text('file2.txt'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });

    testWidgets('collapses and re-expands directory on tap', (tester) async {
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

      final filesController = TransmissionTaskFilesController(
        serviceFactory: (_) => FakeTransmissionFilesService(fakeFiles),
      );
      await filesController.load(
        taskId: '7',
        downloader: downloaderController.getDownloader('trans-1')!,
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
          child: TransmissionTaskFilesPage(
            taskId: '7',
            downloaderId: 'trans-1',
            taskName: 'demo.iso',
            controller: filesController,
          ),
        ),
      );
      await tester.pump();

      // 第一层目录默认已展开，子文件可见
      expect(find.text('file1.txt'), findsOneWidget);
      expect(find.text('file2.txt'), findsOneWidget);

      // 点击目录折叠
      await tester.tap(find.text('dir1'));
      await tester.pump();

      expect(find.text('file1.txt'), findsNothing);
      expect(find.text('file2.txt'), findsNothing);

      // 再次点击展开
      await tester.tap(find.text('dir1'));
      await tester.pump();

      expect(find.text('file1.txt'), findsOneWidget);
      expect(find.text('file2.txt'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });

    testWidgets('shows error message when load fails', (tester) async {
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

      final filesController = TransmissionTaskFilesController(
        serviceFactory: (_) => _FailingTransmissionService(),
      );
      await filesController.load(
        taskId: '7',
        downloader: downloaderController.getDownloader('trans-1')!,
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
          child: TransmissionTaskFilesPage(
            taskId: '7',
            downloaderId: 'trans-1',
            taskName: 'demo.iso',
            controller: filesController,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('connection failed'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });
  });
}

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

class FakeTransmissionFilesService extends TransmissionService {
  FakeTransmissionFilesService(this._files)
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  final List<TransmissionTaskFileNode> _files;

  @override
  Future<List<TransmissionTaskFileNode>> getTaskFiles(String taskId) async =>
      _files;
}

class _NeverCompleteTransmissionService extends TransmissionService {
  _NeverCompleteTransmissionService()
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  @override
  Future<List<TransmissionTaskFileNode>> getTaskFiles(String taskId) =>
      Completer<List<TransmissionTaskFileNode>>().future;
}

class _FailingTransmissionService extends TransmissionService {
  _FailingTransmissionService()
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  @override
  Future<List<TransmissionTaskFileNode>> getTaskFiles(String taskId) async =>
      throw DownloaderServiceException('connection failed');
}
