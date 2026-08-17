import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_tracker.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_trackers_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_trackers_page.dart';
import 'package:windwalker/services/transmission_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

import 'test_helpers.dart';

void main() {
  group('TransmissionTaskTrackersPage', () {
    testWidgets('renders tracker cards with host, tier, and seeder count',
        (tester) async {
      final fakeTrackers = [
        const TransmissionTaskTracker(
          id: 1,
          host: 'tracker.example.com:8080',
          announce: 'http://tracker.example.com:8080/announce',
          tier: 0,
          seederCount: 42,
          leecherCount: 10,
          downloadCount: 200,
        ),
        const TransmissionTaskTracker(
          id: 2,
          host: 'backup.tracker.org',
          announce: 'http://backup.tracker.org/announce',
          tier: 1,
          seederCount: 5,
          leecherCount: 3,
          downloadCount: 50,
          errorMessage: 'Connection refused',
        ),
      ];

      final downloaderController = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(
            id: 'trans-1',
            name: 'NAS',
            type: DownloaderType.transmission,
          ),
        ];

      final controller = TransmissionTaskTrackersController(
        serviceFactory: (_) => FakeTrackersService(fakeTrackers),
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          child: TransmissionTaskTrackersPage(
            taskId: '7',
            downloaderId: 'trans-1',
            taskName: 'demo.iso',
            controller: controller,
          ),
        ),
      );
      // trigger load
      await controller.load(
        taskId: '7',
        downloader: downloaderController.downloaders.first,
      );
      await tester.pump();

      expect(find.text('tracker.example.com:8080'), findsOneWidget);
      expect(find.text('Tier 0'), findsOneWidget);
      expect(find.textContaining('Seeds: 42'), findsOneWidget);
      expect(find.textContaining('Leeches: 10'), findsOneWidget);
      expect(find.textContaining('Downloads: 200'), findsOneWidget);

      expect(find.text('backup.tracker.org'), findsOneWidget);
      expect(find.text('Tier 1'), findsOneWidget);
      expect(find.text('Connection refused'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });

    testWidgets('shows error message on load failure', (tester) async {
      final downloaderController = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(
            id: 'trans-1',
            name: 'NAS',
            type: DownloaderType.transmission,
          ),
        ];

      final controller = TransmissionTaskTrackersController(
        serviceFactory: (_) => FakeTrackersServiceError(),
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          child: TransmissionTaskTrackersPage(
            taskId: '7',
            downloaderId: 'trans-1',
            taskName: 'demo.iso',
            controller: controller,
          ),
        ),
      );
      await controller.load(
        taskId: '7',
        downloader: downloaderController.downloaders.first,
      );
      await tester.pump();

      expect(find.text('tracker fetch failed'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });

    testWidgets('shows empty state when no trackers', (tester) async {
      final downloaderController = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(
            id: 'trans-1',
            name: 'NAS',
            type: DownloaderType.transmission,
          ),
        ];

      final controller = TransmissionTaskTrackersController(
        serviceFactory: (_) => FakeTrackersService([]),
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          child: TransmissionTaskTrackersPage(
            taskId: '7',
            downloaderId: 'trans-1',
            taskName: 'demo.iso',
            controller: controller,
          ),
        ),
      );
      await controller.load(
        taskId: '7',
        downloader: downloaderController.downloaders.first,
      );
      await tester.pump();

      expect(find.text('No trackers'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });
  });
}

class FakeTrackersService extends TransmissionService {
  FakeTrackersService(this._data)
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  final List<TransmissionTaskTracker> _data;

  @override
  Future<List<TransmissionTaskTracker>> getTaskTrackers(String taskId) async =>
      _data;
}

class FakeTrackersServiceError extends TransmissionService {
  FakeTrackersServiceError()
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  @override
  Future<List<TransmissionTaskTracker>> getTaskTrackers(String taskId) async =>
      throw DownloaderServiceException('tracker fetch failed');
}
