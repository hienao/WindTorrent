import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/utils/review_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const container = 'review_manager_test';

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return '/tmp/test_windwalker';
            }
            if (methodCall.method == 'getApplicationSupportDirectory') {
              return '/tmp/test_windwalker';
            }
            return null;
          },
        );
    await GetStorage.init(container);
  });

  group('ReviewManager success moments', () {
    late GetStorage storage;
    late DateTime now;
    late int requestCount;

    ReviewManager createManager() {
      return ReviewManager(
        storage: storage,
        now: () => now,
        requestReview: () async {
          requestCount++;
        },
      );
    }

    setUp(() async {
      storage = GetStorage(container);
      await storage.erase();
      now = DateTime(2026, 6, 21, 10);
      requestCount = 0;
    });

    test('requests after first downloader is added once', () async {
      final manager = createManager();

      await manager.recordFirstDownloaderAddedAndMaybeRequestReview();
      await manager.recordFirstDownloaderAddedAndMaybeRequestReview();

      expect(requestCount, 1);
    });

    test('requests after the third successful task add', () async {
      final manager = createManager();

      await manager.recordSuccessfulTaskAddAndMaybeRequestReview();
      await manager.recordSuccessfulTaskAddAndMaybeRequestReview();

      expect(requestCount, 0);

      await manager.recordSuccessfulTaskAddAndMaybeRequestReview();

      expect(requestCount, 1);
    });

    test('requests after first completed task is observed once', () async {
      final manager = createManager();

      await manager.recordCompletedTaskSeenAndMaybeRequestReview(
        completedTaskCount: 0,
      );
      expect(requestCount, 0);

      await manager.recordCompletedTaskSeenAndMaybeRequestReview(
        completedTaskCount: 1,
      );
      await manager.recordCompletedTaskSeenAndMaybeRequestReview(
        completedTaskCount: 2,
      );

      expect(requestCount, 1);
    });

    test('requests after three consecutive healthy usage days', () async {
      final manager = createManager();

      await manager.recordHealthyUsageDayAndMaybeRequestReview(
        hasErrorState: false,
      );
      now = now.add(const Duration(days: 1));
      await manager.recordHealthyUsageDayAndMaybeRequestReview(
        hasErrorState: false,
      );

      expect(requestCount, 0);

      now = now.add(const Duration(days: 1));
      await manager.recordHealthyUsageDayAndMaybeRequestReview(
        hasErrorState: false,
      );

      expect(requestCount, 1);
    });

    test('resets healthy usage streak after an error day', () async {
      final manager = createManager();

      await manager.recordHealthyUsageDayAndMaybeRequestReview(
        hasErrorState: false,
      );
      now = now.add(const Duration(days: 1));
      await manager.recordHealthyUsageDayAndMaybeRequestReview(
        hasErrorState: true,
      );
      now = now.add(const Duration(days: 1));
      await manager.recordHealthyUsageDayAndMaybeRequestReview(
        hasErrorState: false,
      );
      now = now.add(const Duration(days: 1));
      await manager.recordHealthyUsageDayAndMaybeRequestReview(
        hasErrorState: false,
      );

      expect(requestCount, 0);

      now = now.add(const Duration(days: 1));
      await manager.recordHealthyUsageDayAndMaybeRequestReview(
        hasErrorState: false,
      );

      expect(requestCount, 1);
    });

    test('honors global cooldown across success moments', () async {
      final manager = createManager();

      await manager.recordFirstDownloaderAddedAndMaybeRequestReview();
      await manager.recordSuccessfulTaskAddAndMaybeRequestReview();
      await manager.recordSuccessfulTaskAddAndMaybeRequestReview();
      await manager.recordSuccessfulTaskAddAndMaybeRequestReview();

      expect(requestCount, 1);

      now = now.add(const Duration(days: 91));
      await manager.recordCompletedTaskSeenAndMaybeRequestReview(
        completedTaskCount: 1,
      );

      expect(requestCount, 2);
    });
  });
}
