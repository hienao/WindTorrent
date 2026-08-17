import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_editor_page.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/connection_result.dart';

class GateMockController extends DownloaderController {
  ConnectionResult result;
  GateMockController(this.result) : super();

  @override
  Future<ConnectionResult> addDownloader(Downloader downloader) async => result;

  @override
  Future<ConnectionResult> updateDownloader(Downloader downloader) async =>
      result;
}

Widget harness(DownloaderController c) =>
    ChangeNotifierProvider<DownloaderController>.value(
      value: c,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
        home: DownloaderEditorPage(),
      ),
    );

void main() {
  testWidgets('版本不符时不 pop 且显示 SnackBar 提示版本', (tester) async {
    final c = GateMockController(
      const ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        '版本过低',
        actualVersion: '1.35.0',
        minVersion: '1.36',
      ),
    );
    await tester.pumpWidget(harness(c));

    await tester.enterText(find.byType(TextFormField).at(0), 'D1');
    await tester.enterText(find.byType(TextFormField).at(1), '127.0.0.1');
    await tester.enterText(find.byType(TextFormField).at(2), '6800');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret');

    await tester.tap(find.text('保存配置'));
    await tester.pump();
    await tester.pump(); // process async result & snackbar

    // 仍在编辑页（未 pop）：Scaffold 和 Form 仍然存在
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(Form), findsOneWidget);

    // 出现版本提示 SnackBar
    expect(find.textContaining('版本过低'), findsOneWidget);
  });

  testWidgets('成功时 pop 离开页面', (tester) async {
    final c = GateMockController(
      const ConnectionSuccess(serverVersion: '1.36.0'),
    );
    await tester.pumpWidget(harness(c));

    await tester.enterText(find.byType(TextFormField).at(0), 'D1');
    await tester.enterText(find.byType(TextFormField).at(1), '127.0.0.1');
    await tester.enterText(find.byType(TextFormField).at(2), '6800');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret');

    await tester.tap(find.text('保存配置'));
    await tester.pumpAndSettle();

    // 成功 → pop → 不再有标题
    expect(find.text('添加下载器'), findsNothing);
  });
}
