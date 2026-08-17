import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/features/tasks/presentation/widgets/task_detail_entry_card.dart';
import 'package:windwalker/features/tasks/presentation/pages/task_detail_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_detail_controller.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_detail.dart';
import 'package:windwalker/services/transmission_service.dart';

import 'test_helpers.dart';

const _fakeDetail = TransmissionTaskDetail(
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

void main() {
  testWidgets('tapping Files opens the Transmission files shell', (tester) async {
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
          status: TaskStatus.completed,
          savePath: '/downloads',
          downloaderId: 'trans-1',
        ),
      );
    // 镜像 appRouter 的 /tasks/detail/:id + transmission/files 子路由结构，
    // 以便验证详情页入口跳转到 files 子页面。
    final router = GoRouter(
      initialLocation: '/tasks/detail/7?downloaderId=trans-1&taskName=demo.iso',
      routes: [
        GoRoute(
          path: '/tasks',
          name: 'tasks',
          builder: (context, state) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'detail/:id',
              name: 'task-detail',
              builder: (context, state) => TaskDetailPage(
                taskId: state.pathParameters['id']!,
                downloaderId:
                    state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
              routes: [
                GoRoute(
                  path: 'transmission/files',
                  name: 'transmission-task-files',
                  builder: (context, state) => TransmissionTaskFilesPage(
                    taskId: state.pathParameters['id']!,
                    downloaderId:
                        state.uri.queryParameters['downloaderId'] ?? '',
                    taskName: state.uri.queryParameters['taskName'] ?? '',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DownloaderController>.value(
            value: downloaderController,
          ),
          ChangeNotifierProvider<TaskController>.value(
            value: taskController,
          ),
          ChangeNotifierProvider<TaskDomainStore>(
            create: (_) => TaskDomainStore(),
          ),
          ChangeNotifierProvider<TransmissionTaskDetailController>(
            create: (_) => TransmissionTaskDetailController(
              serviceFactory: (_) => _FakeTransmissionService(),
            ),
          ),
          ChangeNotifierProvider<SettingsController>(
            create: (_) => SettingsController(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 点击「Files」入口卡片（ListTile）跳转到 files 子页面。
    final filesEntry = find.ancestor(
      of: find.text('Files'),
      matching: find.byType(TaskDetailEntryCard),
    );
    await tester.ensureVisible(filesEntry);
    await tester.pump();
    // warnIfMissed: false — 列表项在滚动后，几何位置可能在重新布局后轻微漂移，
    // 但 onTap 已绑定到对应 ListTile，命中其区域即可触发跳转。
    await tester.tap(filesEntry, warnIfMissed: false);
    await tester.pumpAndSettle();

    // 路由跳转后 files 页面已渲染（Shell 可见）。
    expect(find.byType(TransmissionTaskFilesPage), findsOneWidget);

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
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

class _FakeTransmissionService extends TransmissionService {
  _FakeTransmissionService()
      : super(Downloader(
          id: 'trans-1',
          name: 'Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  @override
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async =>
      _fakeDetail;
}
