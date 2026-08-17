import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/realtime/presentation/controllers/realtime_sync_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_detail_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_files_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_options_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_peers_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_sources_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_files_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_peers_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_sources_page.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_task_detail.dart';
import 'package:windwalker/models/qbit_task_file_node.dart';
import 'package:windwalker/models/qbit_task_options.dart';
import 'package:windwalker/models/qbit_task_options_update.dart';
import 'package:windwalker/models/qbit_task_peer.dart';
import 'package:windwalker/models/qbit_task_source.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit_service.dart';

import 'test_helpers.dart';

/// qBit 测试用下载器。
final fakeQBitDownloader = Downloader(
  id: 'qbit-1',
  name: 'Seedbox',
  type: DownloaderType.qbittorrent,
  host: 'localhost',
  port: 8080,
  username: 'admin',
  password: 'admin',
);

/// qBit 信息主页测试用读模型。
const fakeQBitTaskDetail = QBitTaskDetail(
  taskId: 'abc',
  downloaderId: 'qbit-1',
  name: 'Three Kingdoms',
  progress: 0.12,
  queuePosition: 3,
  category: 'tv',
  tags: ['classic', 'chinese'],
  savePath: '/ptd',
  totalSize: 114390000000,
  fileCount: 95,
  sourceCount: 3,
  peerCount: 30,
  httpSourceCount: 0,
  downloadSpeed: 0,
  uploadSpeed: 0,
  state: 'stalledDL',
  downloaded: 171730000,
  uploaded: 71310000,
  shareRatio: 0.42,
  eta: 8640000,
  dlSpeedAvg: 161180,
  upSpeedAvg: 66930,
  seeds: 5,
  leechs: 30,
  connections: 0,
  connectionsLimit: 300,
  dlLimit: -1,
  upLimit: 1048576,
  availability: 85.3,
  pieceSize: 8388608,
  pieceCount: 14643,
  completedPieceCount: 1757,
  createdAt: null,
  addedAt: null,
  completedAt: null,
  lastSeen: null,
  timeElapsed: 1080,
  seedingTime: 0,
  createdBy: '',
  comment: '',
  infoHashV1: 'v1hash',
  infoHashV2: 'v2hash',
);

/// qBit 文件页测试用只读树。
/// demo 目录直接含 `subs`（折叠目录）与 `EP01.srt`（文件）：展开 demo 后两者均可见。
final fakeQBitFileTree = <QBitTaskFileNode>[
  const QBitTaskFileNode(
    path: 'demo',
    name: 'demo',
    isDirectory: true,
    size: 110,
    downloaded: 10,
    progress: 0.09,
    children: [
      QBitTaskFileNode(
        path: 'demo/subs',
        name: 'subs',
        isDirectory: true,
        size: 10,
        downloaded: 10,
        progress: 1,
        children: [],
      ),
      QBitTaskFileNode(
        path: 'demo/EP01.srt',
        name: 'EP01.srt',
        isDirectory: false,
        size: 10,
        downloaded: 10,
        progress: 1,
      ),
    ],
  ),
];

/// Fake qBit service：覆盖详情页各子页面所需的新 facade 方法。
/// 各子页面测试通过具名参数注入相应数据；[saveError] 非空时保存抛异常。
class FakeQBitService extends QBitService {
  FakeQBitService({
    this.detail = fakeQBitTaskDetail,
    this.files = const [],
    this.sources = const [],
    this.peers = const [],
    this.options,
    this.saveError,
    this.syncData,
  }) : super(fakeQBitDownloader);

  final QBitTaskDetail detail;
  final List<QBitTaskFileNode> files;
  final List<QBitTaskSource> sources;
  final List<QBitTaskPeer> peers;
  final QBitTaskOptions? options;
  final String? saveError;
  final Map<String, dynamic>? syncData;
  int updateTaskOptionsCallCount = 0;
  QBitTaskOptionsUpdate? lastOptionsUpdate;

  @override
  Future<QBitTaskDetail?> getTaskFullDetail(String taskId) async => detail;

  @override
  Future<(int, Map<String, dynamic>?)> getTaskSyncUpdate(
      String taskId, int rid) async {
    return (rid + 1, syncData);
  }

  @override
  Future<List<QBitTaskFileNode>> getTaskFiles(String taskId) async => files;

  @override
  Future<List<QBitTaskSource>> getTaskSources(String taskId) async => sources;

  @override
  Future<List<QBitTaskPeer>> getTaskPeers(String taskId) async => peers;

  @override
  Future<QBitTaskOptions> getTaskOptions(String taskId) async => options!;

  @override
  Future<void> updateTaskOptions(
    String taskId, {
    required QBitTaskOptions current,
    required QBitTaskOptionsUpdate update,
  }) async {
    updateTaskOptionsCallCount++;
    lastOptionsUpdate = update;
    if (saveError != null) {
      throw DownloaderServiceException(saveError!);
    }
  }
}

/// qBit 信息主页测试包装器。
Widget buildQBitDetailTestApp({required QBitTaskDetail detail}) {
  return createTestApp(
    downloaderController:
        MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    child: QBitTaskDetailPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: detail.name,
      controller: QBitTaskDetailController(
        serviceFactory: (_) => FakeQBitService(detail: detail),
      ),
    ),
  );
}

/// qBit 文件页测试包装器。
Widget buildQBitFilesTestApp({required List<QBitTaskFileNode> files}) {
  return createTestApp(
    downloaderController:
        MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    child: QBitTaskFilesPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: 'Three Kingdoms',
      controller: QBitTaskFilesController(
        serviceFactory: (_) => FakeQBitService(files: files),
      ),
    ),
  );
}

/// qBit 服务器(来源)页测试包装器。
Widget buildQBitSourcesTestApp({required List<QBitTaskSource> sources}) {
  return createTestApp(
    downloaderController:
        MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    child: QBitTaskSourcesPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: 'Three Kingdoms',
      controller: QBitTaskSourcesController(
        serviceFactory: (_) => FakeQBitService(sources: sources),
      ),
    ),
  );
}

/// qBit 节点(对端)页测试包装器。
Widget buildQBitPeersTestApp({required List<QBitTaskPeer> peers}) {
  return createTestApp(
    downloaderController:
        MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    child: QBitTaskPeersPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: 'Three Kingdoms',
      controller: QBitTaskPeersController(
        serviceFactory: (_) => FakeQBitService(peers: peers),
      ),
    ),
  );
}

/// qBit 选项页测试包装器。
Widget buildQBitOptionsTestApp({
  required QBitTaskOptions options,
  QBitTaskOptionsController? controller,
  RealtimeSyncController? realtimeSyncController,
  TaskDomainStore? taskDomainStore,
}) {
  return createTestApp(
    downloaderController:
        MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
    taskController: _StubTaskController(),
    realtimeSyncController: realtimeSyncController,
    taskDomainStore: taskDomainStore,
    child: QBitTaskOptionsPage(
      taskId: 'abc',
      downloaderId: 'qbit-1',
      taskName: 'Three Kingdoms',
      controller: controller ??
          QBitTaskOptionsController(
            serviceFactory: (_) => FakeQBitService(options: options),
          ),
    ),
  );
}

/// TaskController stub：no-op 网络/timer，避免测试触发真实加载与自动刷新。
class _StubTaskController extends TaskController {
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
