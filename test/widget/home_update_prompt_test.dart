import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('Home shows gentle update dialog when controller allows it', (
    tester,
  ) async {
    final taskController = TaskController();

    final updateController = buildUpdateControllerForTest(
      result: const UpdateCheckResult.available(2026061501),
      shouldOfferDialog: true,
    );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        taskController: taskController,
        updateController: updateController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Open Google Play'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    // 清理由 HomeTabContainer → AllTasksTabPage 启动的 25s periodic Timer
    taskController.stopAutoRefresh();
  });
}
