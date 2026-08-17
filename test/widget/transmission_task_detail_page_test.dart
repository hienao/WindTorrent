import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_detail.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_detail_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/services/transmission_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

import 'test_helpers.dart';

void main() {
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

  testWidgets('renders transmission info groups and detail entry cards',
      (tester) async {
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
            serviceFactory: (_) => FakeTransmissionService(fakeDetail),
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

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets('shared shell keeps pause resume and delete actions visible',
      (tester) async {
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
            serviceFactory: (_) => FakeTransmissionService(fakeDetail),
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

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets('keeps existing transmission detail visible during refresh',
      (tester) async {
    final downloader = createTestDownloader(
      id: 'trans-1',
      name: 'NAS',
      type: DownloaderType.transmission,
    );
    final downloaderController = MockDownloaderController()
      ..testDownloaders = [downloader];
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
    final delayedRefresh = Completer<TransmissionTaskDetail>();
    final fakeService = _SequenceTransmissionService([
      Future.value(fakeDetail),
      delayedRefresh.future,
    ]);
    final detailController = TransmissionTaskDetailController(
      serviceFactory: (_) => fakeService,
    );

    await detailController.load(taskId: '7', downloader: downloader);

    await tester.pumpWidget(
      createTestApp(
        downloaderController: downloaderController,
        taskController: taskController,
        child: ChangeNotifierProvider<TransmissionTaskDetailController>.value(
          value: detailController,
          child: const TransmissionTaskDetailPage(
            taskId: '7',
            downloaderId: 'trans-1',
            taskName: 'demo.iso',
          ),
        ),
      ),
    );

    expect(find.text('Torrent Info'), findsOneWidget);

    await tester.pump();
    await tester.pump();

    expect(detailController.detail, isNotNull);
    expect(find.text('Torrent Info'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    delayedRefresh.complete(fakeDetail);
    await tester.pumpAndSettle(const Duration(milliseconds: 10));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
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

class FakeTransmissionService extends TransmissionService {
  FakeTransmissionService(this._detail)
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  final TransmissionTaskDetail _detail;

  @override
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async =>
      _detail;
}

class _SequenceTransmissionService extends TransmissionService {
  _SequenceTransmissionService(this._responses)
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  final List<Future<TransmissionTaskDetail>> _responses;
  int _index = 0;

  @override
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async {
    if (_index >= _responses.length) {
      throw DownloaderServiceException('unexpected extra refresh');
    }
    return _responses[_index++];
  }
}
