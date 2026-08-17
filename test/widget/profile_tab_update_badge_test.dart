import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('Profile tab shows update badge near about entry', (
    tester,
  ) async {
    final taskController = TaskController();

    final updateController = buildUpdateControllerForTest(
      result: const UpdateCheckResult.available(2026061501),
      shouldOfferDialog: false,
    );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        taskController: taskController,
        updateController: updateController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mine'));
    await tester.pumpAndSettle();

    expect(find.byType(NeoSettingRow), findsWidgets);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About WindTorrent'), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget);

    // 清理由 HomeTabContainer → AllTasksTabPage 启动的 25s periodic Timer
    taskController.stopAutoRefresh();
  });
}
