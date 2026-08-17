import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/add_task/presentation/pages/add_task_page.dart';
import 'package:windwalker/features/add_task/presentation/services/torrent_file_picker.dart';
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

  group('AddTaskPage torrent flow', () {
    late MockDownloaderController controller;

    setUp(() {
      controller = MockDownloaderController();
      // Pre-populate with a downloader so the page renders
      controller.testDownloaders = [createTestDownloader()];
    });

    testWidgets('renders v2 neumorphic add task structure', (tester) async {
      await tester.pumpWidget(
        createAddTaskTestApp(downloaderController: controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('添加任务'), findsOneWidget);
      expect(find.text('选择下载器'), findsWidgets);
      expect(find.text('下载链接'), findsOneWidget);
      expect(find.byType(NeoPageHeader), findsOneWidget);
      expect(find.byType(NeoInputShell), findsWidgets);
      expect(find.byType(NeoActionBar), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();

      expect(find.text('保存路径'), findsOneWidget);
      expect(
        find.byKey(const Key('downloader-type-icon-aria2-medium')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_download_rounded), findsNothing);
      expect(find.byIcon(Icons.downloading_rounded), findsNothing);
      expect(find.byIcon(Icons.file_download_rounded), findsNothing);
    });

    testWidgets('downloader picker rows use shared downloader icons', (
      tester,
    ) async {
      final pickerController = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(id: 'aria', type: DownloaderType.aria2),
          createTestDownloader(
            id: 'qbit',
            type: DownloaderType.qbittorrent,
            name: 'SeedBox qB',
          ),
        ];

      await tester.pumpWidget(
        createAddTaskTestApp(downloaderController: pickerController),
      );
      await tester.pumpAndSettle();

      // Open the downloader picker by tapping the selected downloader card.
      await tester.tap(find.text('Test Aria2'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('downloader-type-icon-aria2-medium')),
        findsWidgets,
      );
      expect(
        find.byKey(const Key('downloader-type-icon-qbittorrent-medium')),
        findsOneWidget,
      );
    });

    testWidgets('header is laid out below the system status bar', (
      tester,
    ) async {
      const statusBarTop = 32.0;

      await tester.pumpWidget(
        createTestApp(
          downloaderController: controller,
          child: const MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(top: statusBarTop)),
            child: AddTaskPage(),
          ),
        ),
      );
      await tester.pump();

      final titleTop = tester.getTopLeft(find.text('Add Task')).dy;

      expect(titleTop, greaterThanOrEqualTo(statusBarTop));
    });

    testWidgets('back button aligns with the page content edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        createAddTaskTestApp(downloaderController: controller),
      );
      await tester.pumpAndSettle();

      final backLeft = tester
          .getTopLeft(find.byIcon(Icons.arrow_back_rounded))
          .dx;

      expect(backLeft, moreOrLessEquals(16, epsilon: 0.1));
    });

    testWidgets('shows torrent file name after picking', (tester) async {
      final picker = FakeTorrentFilePicker(
        result: PickedTorrentFile(
          fileName: 'ubuntu.torrent',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      await tester.pumpWidget(
        createAddTaskTestApp(
          downloaderController: controller,
          torrentFilePicker: picker,
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the torrent picker area
      await tester.tap(find.text('选择 torrent 文件'));
      await tester.pumpAndSettle();

      expect(find.text('ubuntu.torrent'), findsOneWidget);
    });

    testWidgets('shows no torrent initially', (tester) async {
      await tester.pumpWidget(
        createAddTaskTestApp(downloaderController: controller),
      );
      await tester.pumpAndSettle();

      // Should not find any torrent file name
      expect(find.text('已选择：ubuntu.torrent'), findsNothing);
    });

    testWidgets('cancel picking shows no file', (tester) async {
      final picker = FakeTorrentFilePicker(result: null);

      await tester.pumpWidget(
        createAddTaskTestApp(
          downloaderController: controller,
          torrentFilePicker: picker,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择 torrent 文件'));
      await tester.pumpAndSettle();

      // No torrent file name should appear
      expect(find.text('ubuntu.torrent'), findsNothing);
    });

    testWidgets('submit without downloader shows snackbar', (tester) async {
      // Use a fresh controller with no downloaders
      final emptyController = MockDownloaderController();

      await tester.pumpWidget(
        createAddTaskTestApp(downloaderController: emptyController),
      );
      await tester.pumpAndSettle();

      // Tap submit button
      await tester.tap(find.text('开始下载'));
      await tester.pumpAndSettle();

      // Should show "please select downloader" snackbar (zh locale)
      expect(find.text('请先选择一个下载器'), findsOneWidget);
    });

    testWidgets('can clear selected torrent file by choosing link source', (
      tester,
    ) async {
      final picker = FakeTorrentFilePicker(
        result: PickedTorrentFile(
          fileName: 'test.torrent',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      await tester.pumpWidget(
        createAddTaskTestApp(
          downloaderController: controller,
          torrentFilePicker: picker,
        ),
      );
      await tester.pumpAndSettle();

      // Pick a torrent file
      await tester.tap(find.text('选择 torrent 文件'));
      await tester.pumpAndSettle();
      expect(find.text('test.torrent'), findsOneWidget);

      await tester.tap(find.text('2. 下载链接').last);
      await tester.pumpAndSettle();

      expect(find.text('test.torrent'), findsNothing);
    });

    testWidgets('submit with torrent file calls addTask', (tester) async {
      final picker = FakeTorrentFilePicker(
        result: PickedTorrentFile(
          fileName: 'debian.torrent',
          bytes: Uint8List.fromList([4, 5, 6]),
        ),
      );

      final taskController = MockTaskController();

      await tester.pumpWidget(
        createAddTaskTestApp(
          downloaderController: controller,
          taskController: taskController,
          torrentFilePicker: picker,
        ),
      );
      await tester.pumpAndSettle();

      // Pick torrent file
      await tester.tap(find.text('选择 torrent 文件'));
      await tester.pumpAndSettle();

      // Tap submit button
      await tester.tap(find.text('开始下载'));
      await tester.pumpAndSettle();

      // Verify addTask was called with torrent data via TaskController
      expect(taskController.lastAddTaskRequest, isNotNull);
      expect(
        taskController.lastAddTaskRequest!.torrentFileName,
        'debian.torrent',
      );
      expect(taskController.lastAddTaskRequest!.hasTorrentSource, isTrue);
    });
  });

  group('AddTaskPage qBittorrent bulk input mode', () {
    /// qBittorrent 多行 URL 字段会把保存路径区推出默认视口，滚动让其可见后再断言。
    Future<void> scrollSavePathIntoView(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
    }

    /// 保存路径字段的 hintText 不作为 Text widget 出现，需直接读 InputDecoration。
    String? savePathHint(WidgetTester tester) {
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      for (final field in fields) {
        final hint = field.decoration?.hintText;
        if (hint != null &&
            (hint.contains('media') ||
                hint.contains('保存') ||
                hint.contains('读取') ||
                hint.contains('Save') ||
                hint.contains('Loading'))) {
          return hint;
        }
      }
      return null;
    }

    testWidgets('qBittorrent downloader shows bulk input mode and resolved save-path hint',
        (tester) async {
      final controller = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(
            id: 'qb',
            name: 'Test qB',
            type: DownloaderType.qbittorrent,
          ),
        ];

      await tester.pumpWidget(
        createAddTaskTestApp(
          downloaderController: controller,
          defaultSavePathLoader: (_) async => '/downloads/media',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('qBittorrent 模式：一行一个磁力链接'), findsOneWidget);

      // URL field collapses to a multi-line TextField under qBittorrent mode.
      final linkField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.maxLines == 5,
        ),
      );
      expect(linkField.minLines, 5);
      expect(linkField.maxLines, 5);

      await scrollSavePathIntoView(tester);
      expect(savePathHint(tester), '/downloads/media');
    });

    testWidgets('empty save-path field shows loading hint while default path is pending',
        (tester) async {
      final completer = Completer<String?>();
      final controller = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(
            id: 'qb',
            name: 'Test qB',
            type: DownloaderType.qbittorrent,
          ),
        ];

      await tester.pumpWidget(
        createAddTaskTestApp(
          downloaderController: controller,
          defaultSavePathLoader: (_) => completer.future,
        ),
      );
      await tester.pump();
      await scrollSavePathIntoView(tester);

      expect(savePathHint(tester), '正在读取默认保存路径...');

      completer.complete('/downloads/media');
      await tester.pump();
      await tester.pump();

      expect(savePathHint(tester), '/downloads/media');
    });
  });

  group('AddTaskPage qBittorrent submit normalization', () {
    testWidgets('submit with qBittorrent multiline input normalizes url before addTask',
        (tester) async {
      final controller = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(
            id: 'qb',
            name: 'Test qB',
            type: DownloaderType.qbittorrent,
          ),
        ];
      final taskController = MockTaskController();

      await tester.pumpWidget(
        createAddTaskTestApp(
          downloaderController: controller,
          taskController: taskController,
          defaultSavePathLoader: (_) async => '/downloads/media',
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField).first,
        ' magnet:?xt=urn:btih:AAA\n\n magnet:?xt=urn:btih:BBB ',
      );

      await tester.tap(find.text('开始下载'));
      await tester.pumpAndSettle();

      expect(
        taskController.lastAddTaskRequest!.url,
        'magnet:?xt=urn:btih:AAA\nmagnet:?xt=urn:btih:BBB',
      );
    });

    testWidgets('manual save path survives downloader switch', (tester) async {
      final controller = MockDownloaderController()
        ..testDownloaders = [
          createTestDownloader(
            id: 'qb',
            name: 'Test qB',
            type: DownloaderType.qbittorrent,
          ),
          createTestDownloader(
            id: 'aria',
            name: 'Test Aria2',
            type: DownloaderType.aria2,
          ),
        ];

      await tester.pumpWidget(
        createAddTaskTestApp(
          downloaderController: controller,
          defaultSavePathLoader: (downloader) async {
            if (downloader.id == 'qb') return '/downloads/media';
            return null;
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      // 保存路径字段被 qB 多行 URL 挤出视口，先滚到可见再录入
      await tester.dragUntilVisible(
        find.byType(TextFormField).last,
        find.byType(ListView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '/custom/path');

      // 滚回顶部以操作下载器选择器（hitTestable 保证可点击）
      await tester.dragUntilVisible(
        find.text('Test qB').hitTestable(),
        find.byType(ListView),
        const Offset(0, 150),
      );
      await tester.pumpAndSettle();

      // 切到 Aria2，保存路径不应被清空
      await tester.tap(find.text('Test qB').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Aria2').hitTestable());
      await tester.pumpAndSettle();

      expect(find.text('/custom/path'), findsOneWidget);
    });
  });
}
