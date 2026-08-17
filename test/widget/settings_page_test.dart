import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_controller.dart';
import 'package:windwalker/models/downloader_backup_version.dart';

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

  group('SettingsPage Widget Tests', () {
    late DownloaderController downloaderController;
    late SettingsController settingsController;

    setUp(() {
      downloaderController = MockDownloaderController();
      settingsController = SettingsController();
    });

    testWidgets('shows settings title and Neo settings rows', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(NeoPageHeader), findsOneWidget);
      expect(find.text('Theme mode'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('shows language tile with current setting', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Follow System'), findsOneWidget);
    });

    testWidgets('tapping language row opens Neo picker sheet', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      expect(find.text('Follow System'), findsNWidgets(2));
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('exposes theme mode picker', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Theme mode'), findsOneWidget);
    });
  });

  group('SettingsPage Backup & Restore', () {
    late DownloaderController downloaderController;
    late SettingsController settingsController;

    setUp(() {
      downloaderController = MockDownloaderController();
      settingsController = SettingsController();
    });

    testWidgets('shows backup and restore rows when WebDAV is configured', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          settingsBackupController: FakeSettingsBackupController.configured(),
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup & Restore'), findsOneWidget);
      expect(find.text('Back up to WebDAV'), findsOneWidget);
      expect(find.text('Restore from WebDAV'), findsOneWidget);
      expect(find.text('WebDAV Server'), findsOneWidget);
    });

    testWidgets('backup rows direct users to configure WebDAV when needed', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          settingsBackupController: FakeSettingsBackupController.unconfigured(),
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup & Restore'), findsOneWidget);
      expect(
        find.text('Configure WebDAV to use backup'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('restore row opens version list bottom sheet', (tester) async {
      final controller = FakeSettingsBackupController.configured()
        ..seedAvailableBackups([
          DownloaderBackupVersion(
            fileId: 'file-1',
            fileName: 'backup-2026-06-27.json',
            backupId: 'b1',
            createdAt: DateTime(2026, 6, 27, 10, 30),
            appVersion: '1.2.0',
            downloaderCount: 3,
            isLatest: true,
          ),
        ]);

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          settingsBackupController: controller,
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore from WebDAV'));
      await tester.pumpAndSettle();

      expect(find.text('Select backup version'), findsOneWidget);
      expect(find.text('1.2.0 · 3 downloaders'), findsOneWidget);
    });

    testWidgets('selecting backup version opens confirmation dialog', (
      tester,
    ) async {
      final controller = FakeSettingsBackupController.configured()
        ..seedAvailableBackups([
          DownloaderBackupVersion(
            fileId: 'file-1',
            fileName: 'backup-2026-06-27.json',
            backupId: 'b1',
            createdAt: DateTime(2026, 6, 27, 10, 30),
            appVersion: '1.2.0',
            downloaderCount: 3,
            isLatest: true,
          ),
        ]);

      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          settingsBackupController: controller,
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      // Open version sheet
      await tester.tap(find.text('Restore from WebDAV'));
      await tester.pumpAndSettle();

      // Tap the version entry
      await tester.tap(find.text('1.2.0 · 3 downloaders'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm restore and replace'), findsOneWidget);
      expect(
        find.text('This will replace all current downloader configurations.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'backup row shows credentials subtitle when WebDAV is configured',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            downloaderController: downloaderController,
            settingsController: settingsController,
            settingsBackupController: FakeSettingsBackupController.configured(),
            initialLocation: '/settings',
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Includes downloader addresses and credentials'),
          findsOneWidget,
        );
      },
    );
  });
}
