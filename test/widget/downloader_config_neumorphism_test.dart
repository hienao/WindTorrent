import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_config_page.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/speed_config_descriptor.dart';

import 'test_helpers.dart';

void main() {
  const descriptor = SpeedConfigDescriptor(
    sections: [
      ConfigSection(
        title: 'Speed Limit Mode',
        description: 'Apply normal speed limits',
        fields: [
          ConfigField(
            key: 'speedLimitModeEnabled',
            label: 'Enable speed limit mode',
            type: ConfigFieldType.toggle,
          ),
          ConfigField(
            key: 'downloadLimitKB',
            label: 'Download limit',
            type: ConfigFieldType.kbps,
            hint: '0 means unlimited',
          ),
          ConfigField(
            key: 'uploadLimitKB',
            label: 'Upload limit',
            type: ConfigFieldType.kbps,
            hint: '0 means unlimited',
          ),
        ],
      ),
    ],
  );

  testWidgets('supported config page renders neumorphic speed config layout', (
    tester,
  ) async {
    final controller = MockDownloaderController()
      ..testDownloaders = [createTestDownloader(id: 'aria2')]
      ..testSpeedConfigDescriptor = descriptor
      ..testSpeedConfig = const DownloaderSpeedConfig(
        speedLimitModeEnabled: true,
        downloadLimitKB: 4096,
        uploadLimitKB: 1024,
      );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: controller,
        child: const DownloaderConfigPage(downloaderId: 'aria2'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NeoStatusHeroCard), findsOneWidget);
    expect(find.byType(NeoFormFieldShell), findsNWidgets(2));
    expect(_editableText('4096'), findsOneWidget);
    expect(_editableText('1024'), findsOneWidget);
    expect(find.byType(NeoActionBar), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('unsupported descriptor shows empty state without action bar', (
    tester,
  ) async {
    final controller = MockDownloaderController()
      ..testDownloaders = [createTestDownloader(id: 'aria2')]
      ..testSpeedConfigDescriptor = null;

    await tester.pumpWidget(
      createTestApp(
        downloaderController: controller,
        child: const DownloaderConfigPage(downloaderId: 'aria2'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NeoEmptyState), findsOneWidget);
    expect(find.byType(NeoActionBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });
}

Finder _editableText(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is EditableText && widget.controller.text == value,
  );
}
