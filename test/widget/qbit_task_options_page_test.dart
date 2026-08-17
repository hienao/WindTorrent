import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_options_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';
import 'package:windwalker/models/qbit_task_options.dart';
import 'package:windwalker/models/qbit_task_options_update.dart';

import 'qbit_test_helpers.dart';

void main() {
  testWidgets('queue action applies immediately and does not enable save',
      (tester) async {
    final service = FakeQBitService(
      options: const QBitTaskOptions(
        queuePosition: 3,
        category: 'tv',
        tags: ['classic'],
        availableCategories: ['tv', 'movie'],
        availableTags: ['classic', 'favorite'],
      ),
    );
    final controller = QBitTaskOptionsController(
      serviceFactory: (_) => service,
    );

    await tester.pumpWidget(buildQBitOptionsTestApp(
      options: service.options!,
      controller: controller,
    ));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.tap(find.text('Top of queue'));
    await tester.pumpAndSettle();

    expect(service.updateTaskOptionsCallCount, 1);
    expect(service.lastOptionsUpdate?.queueAction, QBitQueuePriorityAction.top);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });

  testWidgets('options page shows category choices from realtime snapshot',
      (tester) async {
    final service = FakeQBitService(
      options: const QBitTaskOptions(
        queuePosition: 3,
        category: 'tv',
        tags: ['classic'],
        availableCategories: [],
        availableTags: [],
      ),
    );
    final controller = QBitTaskOptionsController(
      serviceFactory: (_) => service,
    );
    // 分类 / 标签现由 TaskDomainStore 提供（单一事实来源）
    final taskDomainStore = TaskDomainStore();
    taskDomainStore.debugApplyQBitSnapshot(
      QBitRealtimeSnapshot.fromJson(
        downloaderId: 'qbit-1',
        json: {
          'rid': 1,
          'full_update': true,
          'categories': {
            'ani-rss': {'name': 'ani-rss', 'savePath': ''},
            'radarr': {'name': 'radarr', 'savePath': ''},
          },
          'tags': ['RENAME', '已整理'],
          'server_state': {'dl_info_speed': 0, 'up_info_speed': 0},
          'torrents': <String, dynamic>{},
        },
      ),
    );

    await tester.pumpWidget(buildQBitOptionsTestApp(
      options: service.options!,
      controller: controller,
      taskDomainStore: taskDomainStore,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();

    expect(find.text('ani-rss'), findsOneWidget);
    expect(find.text('radarr'), findsOneWidget);
    expect(find.text('Add'), findsWidgets);
  });

  testWidgets('options page disables queue action controls when queue is off',
      (tester) async {
    await tester.pumpWidget(buildQBitOptionsTestApp(
      options: const QBitTaskOptions(
        queuePosition: -1,
        category: 'tv',
        tags: ['classic'],
        availableCategories: ['tv'],
        availableTags: ['classic'],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Top of queue'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Top of queue')).onPressed,
      isNull,
    );
  });
}
