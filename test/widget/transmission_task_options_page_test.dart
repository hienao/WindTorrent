import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_options_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_detail_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_options_page.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_options.dart';
import 'package:windwalker/services/transmission_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'test_helpers.dart';

const _defaultOptions = TransmissionTaskOptions(
  bandwidthPriority: 0,
  honorsSessionLimits: true,
  downloadLimited: true,
  downloadLimitKBps: 100,
  uploadLimited: true,
  uploadLimitKBps: 3000,
  seedRatioMode: TransmissionLimitMode.global,
  seedRatioLimit: 0,
  idleLimitMode: TransmissionLimitMode.global,
  idleLimitMinutes: 0,
);

Downloader _testDownloader() => Downloader(
      id: 'trans-1',
      name: 'NAS',
      type: DownloaderType.transmission,
      host: 'localhost',
      port: 9091,
    );

class _FakeTransmissionService extends TransmissionService {
  _FakeTransmissionService()
      : options = _defaultOptions, super(Downloader(
          id: 'trans-1',
          name: 'Test',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  final TransmissionTaskOptions options;

  @override
  Future<TransmissionTaskOptions> getTaskOptions(String taskId) async =>
      options;

  @override
  Future<void> updateTaskOptions(
    String taskId,
    dynamic update,
  ) async {}
}

class _FakeServiceThatThrows extends TransmissionService {
  _FakeServiceThatThrows()
      : super(Downloader(
          id: 'trans-1',
          name: 'Test',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
        ));

  @override
  Future<TransmissionTaskOptions> getTaskOptions(String taskId) async {
    throw DownloaderServiceException('network error');
  }

  @override
  Future<void> updateTaskOptions(
    String taskId,
    dynamic update,
  ) async {
    throw DownloaderServiceException('network error');
  }
}

/// Minimal app wrapper — passes controller directly to the page.
Widget _buildApp({
  required TransmissionTaskOptionsController controller,
  required DownloaderController downloaderController,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DownloaderController>.value(
        value: downloaderController,
      ),
      ChangeNotifierProvider<TaskController>.value(
        value: TaskController(),
      ),
      ChangeNotifierProvider<TaskDomainStore>.value(
        value: TaskDomainStore(),
      ),
      ChangeNotifierProvider<TransmissionTaskDetailController>.value(
        value: TransmissionTaskDetailController(),
      ),
    ],
    child: MaterialApp(
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
      home: TransmissionTaskOptionsPage(
        taskId: '7',
        downloaderId: 'trans-1',
        taskName: 'demo.iso',
        controller: controller,
      ),
    ),
  );
}

void main() {
  testWidgets('renders form sections when data loaded', (tester) async {
    final controller = TransmissionTaskOptionsController(
      serviceFactory: (_) => _FakeTransmissionService(),
    );

    final downloaderController = MockDownloaderController()
      ..testDownloaders = [
        createTestDownloader(
          id: 'trans-1',
          name: 'NAS',
          type: DownloaderType.transmission,
        ),
      ];

    // Pre-load so the page shows form immediately.
    await controller.load(taskId: '7', downloader: _testDownloader());

    await tester.pumpWidget(_buildApp(
      controller: controller,
      downloaderController: downloaderController,
    ));
    await tester.pump();

    expect(find.text('Transfer Priority'), findsOneWidget);
    expect(find.text('Bandwidth'), findsOneWidget);
    expect(find.text('Share Ratio Limit'), findsOneWidget);
    expect(find.text('Idle Limit'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets('renders error state with retry button', (tester) async {
    final controller = TransmissionTaskOptionsController(
      serviceFactory: (_) => _FakeServiceThatThrows(),
    );

    final downloaderController = MockDownloaderController()
      ..testDownloaders = [
        createTestDownloader(
          id: 'trans-1',
          name: 'NAS',
          type: DownloaderType.transmission,
        ),
      ];

    // Pre-load triggers the error.
    await controller.load(taskId: '7', downloader: _testDownloader());

    await tester.pumpWidget(_buildApp(
      controller: controller,
      downloaderController: downloaderController,
    ));
    await tester.pump();

    expect(find.text('network error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets('save button disabled when not dirty', (tester) async {
    final controller = TransmissionTaskOptionsController(
      serviceFactory: (_) => _FakeTransmissionService(),
    );

    final downloaderController = MockDownloaderController()
      ..testDownloaders = [
        createTestDownloader(
          id: 'trans-1',
          name: 'NAS',
          type: DownloaderType.transmission,
        ),
      ];

    await controller.load(taskId: '7', downloader: _testDownloader());

    await tester.pumpWidget(_buildApp(
      controller: controller,
      downloaderController: downloaderController,
    ));
    await tester.pump();

    final saveButtonFinder = find.widgetWithText(FilledButton, 'Save');
    expect(saveButtonFinder, findsOneWidget);
    final saveButton = tester.widget<FilledButton>(saveButtonFinder);
    expect(saveButton.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });
}
