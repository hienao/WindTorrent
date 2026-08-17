import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/app.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock path_provider channel for GetStorage.init()
    const MethodChannel(
      'plugins.flutter.io/path_provider',
    ).setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '/tmp/test_windwalker_theme';
      }
      return null;
    });
    await GetStorage.init();
  });

  test('AppThemeMode.fromCode resolves persisted values', () {
    expect(AppThemeMode.fromCode('system'), AppThemeMode.system);
    expect(AppThemeMode.fromCode('light'), AppThemeMode.light);
    expect(AppThemeMode.fromCode('dark'), AppThemeMode.dark);
    // Unknown value falls back to system.
    expect(AppThemeMode.fromCode(null), AppThemeMode.system);
    expect(AppThemeMode.fromCode('bogus'), AppThemeMode.system);
  });

  testWidgets('WindTorrentApp exposes NeoThemeTokens in light theme', (
    tester,
  ) async {
    await tester.pumpWidget(const WindTorrentApp());
    await tester.pump();

    // Read the theme from a widget rendered inside MaterialApp's subtree
    // (Theme.of walks up to the nearest Theme ancestor, which is created
    // by MaterialApp itself).
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    final extension = Theme.of(context).extension<NeoThemeTokens>();

    expect(extension, isNotNull);
    expect(extension!.isDark, isFalse);
  });
}
