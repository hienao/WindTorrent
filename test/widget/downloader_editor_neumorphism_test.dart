import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_editor_page.dart';
import 'package:windwalker/models/downloader.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('new downloader page renders neumorphic editor layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        child: const DownloaderEditorPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Downloader'), findsOneWidget);
    expect(find.text('Aria2'), findsOneWidget);
    expect(find.text('qBittorrent'), findsOneWidget);
    expect(find.text('Transmission'), findsOneWidget);
    expect(find.byType(NeoFormFieldShell), findsWidgets);
    expect(find.byType(NeoActionBar), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('back button aligns with the page content edge', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        child: const DownloaderEditorPage(),
      ),
    );
    await tester.pumpAndSettle();

    final backLeft = tester
        .getTopLeft(find.byIcon(Icons.arrow_back_rounded))
        .dx;

    expect(backLeft, moreOrLessEquals(16, epsilon: 0.1));
  });

  testWidgets('switching to qBittorrent updates auth fields and port', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        child: const DownloaderEditorPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('qBittorrent'));
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('RPC Secret'), findsNothing);
    expect(_editableText('8080'), findsOneWidget);
  });

  testWidgets('editing downloader pre-fills existing values', (tester) async {
    final controller = _EditorMockDownloaderController();
    controller.testDownloaders = [
      createTestDownloader(
        id: 'existing',
        name: 'Living Room qBit',
        type: DownloaderType.qbittorrent,
        host: '10.0.0.8',
        port: 8081,
      ).copyWith(username: 'neo', password: 'secret'),
    ];

    await tester.pumpWidget(
      createTestApp(
        downloaderController: controller,
        child: const DownloaderEditorPage(downloaderId: 'existing'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Downloader'), findsOneWidget);
    expect(_editableText('Living Room qBit'), findsOneWidget);
    expect(_editableText('10.0.0.8'), findsOneWidget);
    expect(_editableText('8081'), findsOneWidget);
    expect(_editableText('neo'), findsOneWidget);
  });
}

class _EditorMockDownloaderController extends MockDownloaderController {
  @override
  Downloader? getDownloader(String id) {
    for (final downloader in downloaders) {
      if (downloader.id == id) return downloader;
    }
    return null;
  }
}

Finder _editableText(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is EditableText && widget.controller.text == value,
  );
}
