import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_files_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_files_page.dart';
import 'package:windwalker/models/qbit_task_file_node.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

import 'qbit_test_helpers.dart';
import 'test_helpers.dart';

void main() {
  group('QBitTaskFilesPage', () {
    testWidgets('renders expandable directory tree', (tester) async {
      await tester.pumpWidget(buildQBitFilesTestApp(files: fakeQBitFileTree));
      await tester.pumpAndSettle();

      expect(find.text('demo'), findsOneWidget);
      // 子节点默认折叠
      expect(find.text('subs'), findsNothing);

      await tester.tap(find.text('demo'));
      await tester.pumpAndSettle();

      expect(find.text('subs'), findsOneWidget);
      expect(find.text('EP01.srt'), findsOneWidget);

      // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });

    testWidgets('shows empty state when there are no files',
        (tester) async {
      await tester.pumpWidget(buildQBitFilesTestApp(files: const []));
      await tester.pumpAndSettle();

      expect(find.text('No files'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });

    testWidgets('shows error message when load fails', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController:
              MockDownloaderController()..testDownloaders = [fakeQBitDownloader],
          child: QBitTaskFilesPage(
            taskId: 'abc',
            downloaderId: 'qbit-1',
            taskName: 'Three Kingdoms',
            controller: QBitTaskFilesController(
              serviceFactory: (_) => _FailingQBitService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('connection failed'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    });
  });
}

/// 包裹一个 FakeQBitService 并让 getTaskFiles 抛出，模拟加载失败。
class _FailingQBitService extends FakeQBitService {
  _FailingQBitService() : super(files: const []);

  @override
  Future<List<QBitTaskFileNode>> getTaskFiles(String taskId) async =>
      throw DownloaderServiceException('connection failed');
}
