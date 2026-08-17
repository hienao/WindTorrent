import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_peer.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_peers_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_peers_page.dart';
import 'package:windwalker/services/transmission_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

import 'test_helpers.dart';

void main() {
  group('TransmissionTaskPeersPage', () {
    testWidgets('renders peer rows with IP, client name, and progress',
        (tester) async {
      final fakePeers = [
        const TransmissionTaskPeer(
          address: '192.168.1.10',
          clientName: 'qBittorrent/4.3.8',
          port: 51413,
          progress: 0.75,
          downloadSpeed: 1024,
          uploadSpeed: 512,
          isDownloadingToUs: true,
          isUploadingFromUs: false,
        ),
        const TransmissionTaskPeer(
          address: '10.0.0.5',
          clientName: 'libtorrent/2.0.7',
          port: 6881,
          progress: 0.25,
          downloadSpeed: 0,
          uploadSpeed: 2048,
          isDownloadingToUs: false,
          isUploadingFromUs: true,
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

      final controller = TransmissionTaskPeersController(
        serviceFactory: (_) => FakePeersService(fakePeers),
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          child: TransmissionTaskPeersPage(
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

      expect(find.text('192.168.1.10:51413'), findsOneWidget);
      expect(find.text('qBittorrent/4.3.8'), findsOneWidget);
      expect(find.text('75.0%'), findsOneWidget);
      expect(find.text('DL: 1.0 KB/s'), findsOneWidget);
      expect(find.text('UL: 512 B/s'), findsOneWidget);

      expect(find.text('10.0.0.5:6881'), findsOneWidget);
      expect(find.text('libtorrent/2.0.7'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.text('UL: 2.0 KB/s'), findsOneWidget);

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

      final controller = TransmissionTaskPeersController(
        serviceFactory: (_) => FakePeersServiceError(),
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          child: TransmissionTaskPeersPage(
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

      expect(find.text('peer fetch failed'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });

    testWidgets('shows empty state when no peers', (tester) async {
      final downloaderController = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(
            id: 'trans-1',
            name: 'NAS',
            type: DownloaderType.transmission,
          ),
        ];

      final controller = TransmissionTaskPeersController(
        serviceFactory: (_) => FakePeersService([]),
      );

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          child: TransmissionTaskPeersPage(
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

      expect(find.text('No peers'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });
  });
}

class FakePeersService extends TransmissionService {
  FakePeersService(this._data)
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  final List<TransmissionTaskPeer> _data;

  @override
  Future<List<TransmissionTaskPeer>> getTaskPeers(String taskId) async => _data;
}

class FakePeersServiceError extends TransmissionService {
  FakePeersServiceError()
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  @override
  Future<List<TransmissionTaskPeer>> getTaskPeers(String taskId) async =>
      throw DownloaderServiceException('peer fetch failed');
}
