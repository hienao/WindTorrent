import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_options_controller.dart';
import 'package:windwalker/models/qbit_task_options.dart';
import 'package:windwalker/models/qbit_task_options_update.dart';

import '../widget/qbit_test_helpers.dart';

void main() {
  test('queue action applies immediately and does not make deferred form dirty',
      () async {
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

    await controller.load(taskId: 'abc', downloader: fakeQBitDownloader);

    expect(controller.isDirty, isFalse);

    await controller.applyQueueActionNow(
      taskId: 'abc',
      downloader: fakeQBitDownloader,
      action: QBitQueuePriorityAction.top,
    );

    expect(service.updateTaskOptionsCallCount, 1);
    expect(service.lastOptionsUpdate?.queueAction, QBitQueuePriorityAction.top);
    expect(controller.queueAction, QBitQueuePriorityAction.unchanged);
    expect(controller.isDirty, isFalse);
  });

  test('options controller only saves dirty changes and preserves input on failure',
      () async {
    final controller = QBitTaskOptionsController(
      serviceFactory: (_) => FakeQBitService(
        options: const QBitTaskOptions(
          queuePosition: 3,
          category: 'tv',
          tags: ['classic'],
          availableCategories: ['tv', 'movie'],
          availableTags: ['classic', 'favorite'],
        ),
        saveError: 'save failed',
      ),
    );

    await controller.load(taskId: 'abc', downloader: fakeQBitDownloader);
    controller.updateCategory('movie');
    controller.updateTags(['classic', 'favorite']);

    expect(controller.isDirty, isTrue);

    await controller.save(taskId: 'abc', downloader: fakeQBitDownloader);

    expect(controller.errorMessage, 'save failed');
    // 失败后用户输入应保留，便于修正后重试。
    expect(controller.categoryDraft, 'movie');
    expect(controller.tagDrafts, ['classic', 'favorite']);
  });

  test('queue action is disabled when qBit reports queue position -1',
      () async {
    final controller = QBitTaskOptionsController(
      serviceFactory: (_) => FakeQBitService(
        options: const QBitTaskOptions(
          queuePosition: -1,
          category: 'tv',
          tags: ['classic'],
          availableCategories: ['tv'],
          availableTags: ['classic'],
        ),
      ),
    );

    await controller.load(taskId: 'abc', downloader: fakeQBitDownloader);

    expect(controller.queueActionsEnabled, isFalse);
  });

  test('save succeeds and clears dirty state', () async {
    final controller = QBitTaskOptionsController(
      serviceFactory: (_) => FakeQBitService(
        options: const QBitTaskOptions(
          queuePosition: 3,
          category: 'tv',
          tags: ['classic'],
          availableCategories: ['tv', 'movie'],
          availableTags: ['classic', 'favorite'],
        ),
      ),
    );

    await controller.load(taskId: 'abc', downloader: fakeQBitDownloader);
    controller.updateCategory('movie');

    expect(controller.isDirty, isTrue);

    await controller.save(taskId: 'abc', downloader: fakeQBitDownloader);

    expect(controller.errorMessage, isNull);
    expect(controller.isDirty, isFalse);
  });

  test('queue action 触发共享任务刷新回调', () async {
    final refreshed = <String>[];
    final controller = QBitTaskOptionsController(
      serviceFactory: (_) => FakeQBitService(
        options: const QBitTaskOptions(
          queuePosition: 3,
          category: 'tv',
          tags: ['classic'],
          availableCategories: ['tv'],
          availableTags: ['classic'],
        ),
      ),
      onTaskChanged: (downloaderId) => refreshed.add(downloaderId),
    );

    await controller.load(taskId: 'abc', downloader: fakeQBitDownloader);

    await controller.applyQueueActionNow(
      taskId: 'abc',
      downloader: fakeQBitDownloader,
      action: QBitQueuePriorityAction.top,
    );

    expect(refreshed, ['qbit-1']);
  });

  test('save 成功后触发共享任务刷新回调', () async {
    final refreshed = <String>[];
    final controller = QBitTaskOptionsController(
      serviceFactory: (_) => FakeQBitService(
        options: const QBitTaskOptions(
          queuePosition: 3,
          category: 'tv',
          tags: ['classic'],
          availableCategories: ['tv'],
          availableTags: ['classic'],
        ),
      ),
      onTaskChanged: (downloaderId) => refreshed.add(downloaderId),
    );

    await controller.load(taskId: 'abc', downloader: fakeQBitDownloader);
    controller.updateCategory('movie');

    await controller.save(taskId: 'abc', downloader: fakeQBitDownloader);

    expect(refreshed, ['qbit-1']);
  });
}
