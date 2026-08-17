import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('About page shows check update tile and update status', (
    tester,
  ) async {
    final updateController = buildUpdateControllerForTest(
      result: const UpdateCheckResult.available(2026061501),
      shouldOfferDialog: false,
    );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        updateController: updateController,
        initialLocation: '/about',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WindTorrent'), findsWidgets);
    expect(find.byType(NeoCard), findsWidgets);
    expect(find.byType(NeoSettingRow), findsWidgets);
    expect(find.text('Check for Updates'), findsOneWidget);
    expect(find.text('New version available'), findsOneWidget);
  });

  testWidgets('About page shows unavailable text when status is unknown', (
    tester,
  ) async {
    final updateController = buildUpdateControllerForTest(
      result: const UpdateCheckResult.unknown(),
      shouldOfferDialog: false,
    );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        updateController: updateController,
        initialLocation: '/about',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't check for updates"), findsOneWidget);
    expect(find.text("You're up to date"), findsNothing);
  });

  testWidgets('About page shows Neo update dialog when update is available', (
    tester,
  ) async {
    final updateController = buildUpdateControllerForTest(
      result: const UpdateCheckResult.available(2026061501),
      shouldOfferDialog: false,
    );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        updateController: updateController,
        initialLocation: '/about',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for Updates'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(NeoCard), findsWidgets);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
  });
}
