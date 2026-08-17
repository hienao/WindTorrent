import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/add_task/presentation/pages/add_task_page.dart';
import 'package:windwalker/features/home/presentation/pages/all_tasks_tab_page.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_overview_widgets.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (methodCall) async => '/tmp/test_windwalker',
        );
    await GetStorage.init();
  });

  group('Neumorphic DataTab', () {
    late MockDownloaderController downloaderController;
    late TaskController taskController;

    setUp(() {
      downloaderController = MockDownloaderController();
      taskController = TaskController();
      downloaderController.testDownloaders = [
        createTestDownloader(
          id: 'aria',
          name: 'NAS Aria2',
          type: DownloaderType.aria2,
          status: DownloaderStatus.online,
          taskCount: 7,
          downloadSpeed: 1048576,
          uploadSpeed: 262144,
          taskStats: {'downloading': 3, 'completed': 4},
        ),
        createTestDownloader(
          id: 'qbit',
          name: 'SeedBox qBit',
          type: DownloaderType.qbittorrent,
          status: DownloaderStatus.error,
          taskCount: 2,
          downloadSpeed: 0,
          uploadSpeed: 131072,
        ),
      ];
      downloaderController.testGlobalStats = {
        'downloading': 3,
        'waiting': 2,
        'paused': 1,
        'seeding': 4,
        'completed': 9,
        'error': 1,
        'total': 20,
        'totalSpeed': 1048576,
        'uploadSpeed': 393216,
        'downloaderCount': 2,
        'onlineCount': 1,
      };
    });

    tearDown(() {
      taskController.stopAutoRefresh();
      taskController.dispose();
    });

    testWidgets(
      'renders brand header, overview panel, status matrix and distribution',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            downloaderController: downloaderController,
            taskController: taskController,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.byType(NeoOverviewHeader), findsOneWidget);
        expect(find.byType(NeoOverviewSummaryPanel), findsOneWidget);
        expect(find.byType(NeoStatusMatrix), findsOneWidget);
        expect(find.text(l10n.data), findsWidgets);
        expect(find.text('Total 20 tasks'), findsOneWidget);
        expect(find.text(l10n.windTorrentConsole), findsOneWidget);
        // Status matrix values are in view.
        expect(find.text('3'), findsWidgets);
        expect(find.text('9'), findsWidgets);
        // The distribution sits below the fold; scroll it into view. Downloader
        // names live in the distribution rows, so they only appear after scroll.
        await tester.scrollUntilVisible(
          find.byType(NeoDownloaderDistribution),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(NeoDownloaderDistribution), findsOneWidget);
        expect(find.text('NAS Aria2'), findsOneWidget);
        expect(find.text('SeedBox qBit'), findsOneWidget);
        expect(
          find.byKey(const Key('downloader-type-icon-aria2-medium')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('downloader-type-icon-qbittorrent-medium')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.storage_rounded), findsNothing);
        // AllTasksTabPage mounts an auto-refresh timer; stop it before tear-down.
        taskController.stopAutoRefresh();
      },
    );

    testWidgets('quick actions switch to downloaders and tasks tabs', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // The summary panel's "查看任务" quick action jumps to the tasks tab.
      await tester.tap(
        find.descendant(
          of: find.byType(NeoOverviewSummaryPanel),
          matching: find.text(l10n.viewTasks),
        ),
      );
      await tester.pumpAndSettle();
      // Switching to the tasks tab mounts the AllTasksTabPage.
      expect(find.byType(AllTasksTabPage), findsOneWidget);

      // Switch back to the overview via the shell tab bar (localized label),
      // then the "下载器" quick action jumps to the downloaders tab. The
      // downloaders tab renders each downloader's name.
      await tester.tap(find.text(l10n.data));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NeoOverviewSummaryPanel),
          matching: find.text(l10n.downloadersTab),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NAS Aria2'), findsWidgets);
      taskController.stopAutoRefresh();
    });

    testWidgets('public FAB opens add task route', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('Add Task'));
      await tester.pumpAndSettle();

      expect(find.byType(AddTaskPage), findsOneWidget);
      taskController.stopAutoRefresh();
    });

    testWidgets('status tiles keep a stable height across screen widths', (
      tester,
    ) async {
      Future<double> pumpMatrixAndReadFirstTileHeight(double width) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
            locale: const Locale('en'),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: NeoStatusMatrix(
                    stats: downloaderController.globalStats,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tileFinder = find.descendant(
          of: find.byType(NeoStatusMatrix),
          matching: find.byType(NeoSurface),
        );
        return tester.getSize(tileFinder.first).height;
      }

      final phoneTileHeight = await pumpMatrixAndReadFirstTileHeight(320);
      final tabletTileHeight = await pumpMatrixAndReadFirstTileHeight(620);

      expect(tabletTileHeight, phoneTileHeight);
    });
  });
}
