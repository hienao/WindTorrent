import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/home/presentation/pages/management_tab.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';

class StubController extends DownloaderController {
  final List<Downloader> items;
  StubController(this.items) : super();

  @override
  List<Downloader> get downloaders => List.unmodifiable(items);

  @override
  void init() {}

  @override
  Future<void> loadDownloaders() async {}
}

Widget harness(DownloaderController c) => MultiProvider(
      providers: [
        ChangeNotifierProvider<DownloaderController>.value(value: c),
        ChangeNotifierProvider<TaskDomainStore>(create: (_) => TaskDomainStore()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
        locale: const Locale('zh'),
        home: const Scaffold(body: ManagementTab()),
      ),
    );

void main() {
  testWidgets('有 version 时显示版本徽章', (tester) async {
    await tester.pumpWidget(
      harness(
        StubController([
          Downloader(
            id: 'd1',
            name: 'D1',
            type: DownloaderType.aria2,
            host: 'h',
            port: 6800,
            status: DownloaderStatus.online,
            version: '1.36.0',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1.36.0'), findsOneWidget);
  });

  testWidgets('version 为 null 时显示占位 —', (tester) async {
    await tester.pumpWidget(
      harness(
        StubController([
          Downloader(
            id: 'd1',
            name: 'D1',
            type: DownloaderType.aria2,
            host: 'h',
            port: 6800,
            status: DownloaderStatus.offline,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
  });
}
