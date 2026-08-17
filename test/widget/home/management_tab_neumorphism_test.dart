import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_config_page.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_editor_page.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_downloader_widgets.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_home_shell.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/tasks_page.dart';
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

  group('Neumorphic ManagementTab', () {
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
          host: '192.168.1.8',
          port: 6800,
          status: DownloaderStatus.online,
          version: '1.37.0',
          taskCount: 9,
          downloadSpeed: 1048576,
        ),
      ];
    });

    /// Switches to the downloaders tab via the shell tab bar. "Downloaders"
    /// also appears as the page header, so scope the tap to a tab button.
    Future<void> goToDownloadersTab(WidgetTester tester) async {
      final tabFinder = find.descendant(
        of: find.byType(NeoHomeTabBar),
        matching: find.widgetWithText(GestureDetector, 'Downloaders'),
      );
      await tester.ensureVisible(tabFinder);
      await tester.tap(tabFinder);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'renders neumorphic downloader page without internal scaffold chrome',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            downloaderController: downloaderController,
            taskController: taskController,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await goToDownloadersTab(tester);

        // The shared shell FAB is a NeoHomeFab, not a Material FAB; the tab no
        // longer hosts its own Scaffold/AppBar. Other tabs always render an
        // AppBar inside IndexedStack, so assert the neumorphic content rather
        // than that zero AppBars exist globally.
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.byType(NeoHomeFab), findsOneWidget);
        expect(find.text(l10n.manageConfiguredDownloaders), findsOneWidget);
        expect(find.text(l10n.configuredDownloaders), findsOneWidget);
        expect(find.byType(NeoDownloaderCard), findsOneWidget);
        taskController.stopAutoRefresh();
      },
    );

    testWidgets('card shows identity metadata and hides speed and task count', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await goToDownloadersTab(tester);

      expect(find.text('NAS Aria2'), findsOneWidget);
      expect(find.text('192.168.1.8:6800'), findsOneWidget);
      expect(find.text('Aria2'), findsOneWidget);
      expect(find.text('1.37.0'), findsOneWidget);
      expect(find.text('HTTP'), findsOneWidget);
      expect(find.text('online'), findsNothing);
      expect(find.text('9 个任务'), findsNothing);
      expect(find.text('1.0 MB/s'), findsNothing);
      expect(
        find.byKey(const Key('downloader-type-icon-aria2-large')),
        findsOneWidget,
      );
      taskController.stopAutoRefresh();
    });

    testWidgets('more menu exposes edit and delete actions', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await goToDownloadersTab(tester);
      await tester.tap(find.text(l10n.moreActions));
      await tester.pumpAndSettle();

      expect(find.text(l10n.edit), findsOneWidget);
      expect(find.text(l10n.delete), findsOneWidget);
      taskController.stopAutoRefresh();
    });

    testWidgets('delete confirmation calls removeDownloader', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await goToDownloadersTab(tester);
      await tester.tap(find.text(l10n.moreActions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.delete));
      await tester.pumpAndSettle();

      expect(find.byType(NeoDownloaderDeleteDialog), findsOneWidget);

      await tester.tap(find.text(l10n.delete).last);
      await tester.pumpAndSettle();

      expect(downloaderController.removedDownloaderId, 'aria');
      taskController.stopAutoRefresh();
    });

    testWidgets('tasks action opens downloader scoped tasks page', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await goToDownloadersTab(tester);
      // Scope tap to the card to avoid ambiguity with TasksPage header.
      await tester.tap(find.descendant(
        of: find.byType(NeoDownloaderCard),
        matching: find.text(l10n.taskList),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TasksPage), findsOneWidget);
      taskController.stopAutoRefresh();
    });

    testWidgets('config action opens downloader config page', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await goToDownloadersTab(tester);
      await tester.tap(find.text(l10n.config));
      await tester.pumpAndSettle();

      // Routing reaches the config page for this downloader id. The mock
      // controller returns no config descriptor; the page internally surfaces
      // an unsupported-config state, so we assert the page type resolved.
      expect(find.byType(DownloaderConfigPage), findsOneWidget);
      taskController.stopAutoRefresh();
    });

    testWidgets('edit action from more menu opens downloader editor', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await goToDownloadersTab(tester);
      await tester.tap(find.text(l10n.moreActions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.edit));
      await tester.pumpAndSettle();

      // Routing reaches the editor page. The mock getDownloader returns the
      // test downloader, so the editor loads in edit mode with pre-filled data.
      expect(find.byType(DownloaderEditorPage), findsOneWidget);
      taskController.stopAutoRefresh();
    });
  });
}
