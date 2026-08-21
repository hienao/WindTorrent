import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_controller.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory' ||
                methodCall.method == 'getApplicationSupportDirectory') {
              return '/tmp/test_windwalker';
            }
            return null;
          },
        );
    await GetStorage.init();
  });

  group('SettingsPage', () {
    late DownloaderController downloaderController;
    late SettingsController settingsController;

    setUp(() {
      downloaderController = MockDownloaderController();
      settingsController = SettingsController();
    });

    testWidgets('shows settings and local JSON backup rows', (tester) async {
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
      expect(find.text('Backup & Restore'), findsOneWidget);
      expect(find.text('Export configuration to JSON'), findsOneWidget);
      expect(find.text('Import configuration from JSON'), findsOneWidget);
      expect(find.textContaining('WebDAV'), findsNothing);
    });

    testWidgets('tapping export starts local export', (tester) async {
      final backupController = FakeSettingsBackupController();
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          settingsBackupController: backupController,
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export configuration to JSON'));
      await tester.pump();

      expect(backupController.exportCalls, 1);
    });

    testWidgets('import requires confirmation before opening picker', (
      tester,
    ) async {
      final backupController = FakeSettingsBackupController();
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          settingsBackupController: backupController,
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import configuration from JSON'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm import and replace'), findsOneWidget);
      expect(
        find.text('This will replace all current downloader configurations.'),
        findsOneWidget,
      );
      expect(backupController.importCalls, 0);

      await tester.tap(find.text('Select JSON file'));
      await tester.pumpAndSettle();

      expect(backupController.importCalls, 1);
    });

    testWidgets('shows credential and validation warnings', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          settingsController: settingsController,
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Includes downloader addresses and credentials'),
        findsOneWidget,
      );
      expect(
        find.text('The file is validated before any configuration is replaced'),
        findsOneWidget,
      );
    });
  });
}
