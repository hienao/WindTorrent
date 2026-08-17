import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_home_shell.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock path_provider channel for GetStorage.init()
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return '/tmp/test_windwalker';
            }
            if (methodCall.method == 'getApplicationSupportDirectory') {
              return '/tmp/test_windwalker';
            }
            return null;
          },
        );
    await GetStorage.init();
  });

  group('HomePage Widget Tests', () {
    late DownloaderController downloaderController;
    late TaskController taskController;

    setUp(() {
      downloaderController = MockDownloaderController();
      taskController = TaskController();
    });

    tearDown(() {
      // 消化 HomeTabContainer postFrame 启动的自动刷新 Timer。
      taskController.stopAutoRefresh();
      taskController.dispose();
    });

    testWidgets('Home shell still boots after neumorphism redesign', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 拟物化改造后，首页外壳仍能正常启动并渲染 Scaffold 与底部导航。
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NeoHomeTabBar), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      )!;
      expect(find.byTooltip(l10n.addTaskButton), findsOneWidget);

      // 消化 HomeTabContainer 内剩余的异步提醒延迟。
      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets('shows data overview header when no downloaders', (
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
      // DataTab（默认首页）渲染 Overview 标题。
      expect(find.text(l10n.data), findsWidgets);

      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets('shows add-downloader entry in data overview', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.add_rounded), findsWidgets);

      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets('shows add downloader FAB on downloaders tab', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      )!;

      // Scope tap to the tab bar to avoid ambiguity with overview quick action.
      final tabFinder = find.descendant(
        of: find.byType(NeoHomeTabBar),
        matching: find.widgetWithText(GestureDetector, l10n.downloadersTab),
      );
      await tester.ensureVisible(tabFinder);
      await tester.tap(tabFinder);
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.addDownloader), findsOneWidget);
      expect(find.byTooltip(l10n.addTaskButton), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));
      taskController.stopAutoRefresh();
    });

    testWidgets(
      'add downloader FAB opens downloader editor from downloaders tab',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            downloaderController: downloaderController,
            taskController: taskController,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final l10n = AppLocalizations.of(
          tester.element(find.byType(Scaffold).first),
        )!;

        // Scope tap to the tab bar to avoid ambiguity with overview quick action.
        final tabFinder = find.descendant(
          of: find.byType(NeoHomeTabBar),
          matching: find.widgetWithText(GestureDetector, l10n.downloadersTab),
        );
        await tester.ensureVisible(tabFinder);
        await tester.tap(tabFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(l10n.addDownloader));
        await tester.pumpAndSettle();

        expect(find.text(l10n.addDownloaderTitle), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 300));
        taskController.stopAutoRefresh();
      },
    );
  });
}
