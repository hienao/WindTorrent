import 'package:get_storage/get_storage.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/services/analytics_service.dart';

typedef ReviewClock = DateTime Function();
typedef ReviewAction = Future<void> Function();

class ReviewManager {
  static const _lastReviewKey = 'last_review_request';
  static const _firstDownloaderReviewSignalKey =
      'first_downloader_review_signal';
  static const _successfulTaskAddCountKey = 'successful_task_add_count';
  static const _completedTaskReviewSignalKey = 'completed_task_review_signal';
  static const _healthyUsageLastDayKey = 'healthy_usage_last_day';
  static const _healthyUsageStreakKey = 'healthy_usage_streak';
  static const _requiredSuccessfulTaskAdds = 3;
  static const _requiredHealthyUsageDays = 3;
  static const _cooldownDays = 90;

  final GetStorage _storage;
  final ReviewClock _now;
  final ReviewAction _requestReview;
  final ReviewAction _openStoreListing;

  ReviewManager({
    GetStorage? storage,
    ReviewClock? now,
    ReviewAction? requestReview,
    ReviewAction? openStoreListing,
  }) : _storage = storage ?? GetStorage(),
       _now = now ?? DateTime.now,
       _requestReview =
           requestReview ?? (() => InAppReview.instance.requestReview()),
       _openStoreListing =
           openStoreListing ?? (() => InAppReview.instance.openStoreListing());

  Future<void> recordFirstDownloaderAddedAndMaybeRequestReview() async {
    final alreadySignaled =
        _storage.read<bool>(_firstDownloaderReviewSignalKey) ?? false;
    if (alreadySignaled) return;

    await _storage.write(_firstDownloaderReviewSignalKey, true);
    await _maybeRequestReview(trigger: 'first_downloader');
  }

  Future<void> recordSuccessfulTaskAddAndMaybeRequestReview() async {
    final successfulTaskAdds =
        (_storage.read<int>(_successfulTaskAddCountKey) ?? 0) + 1;
    await _storage.write(_successfulTaskAddCountKey, successfulTaskAdds);

    if (successfulTaskAdds < _requiredSuccessfulTaskAdds) return;

    final requested = await _maybeRequestReview(trigger: 'successful_task_add');
    if (requested) {
      await _storage.write(_successfulTaskAddCountKey, 0);
    }
  }

  Future<void> recordCompletedTaskSeenAndMaybeRequestReview({
    required int completedTaskCount,
  }) async {
    if (completedTaskCount <= 0) return;

    final alreadySignaled =
        _storage.read<bool>(_completedTaskReviewSignalKey) ?? false;
    if (alreadySignaled) return;

    await _storage.write(_completedTaskReviewSignalKey, true);
    await _maybeRequestReview(trigger: 'completed_task');
  }

  Future<void> recordHealthyUsageDayAndMaybeRequestReview({
    required bool hasErrorState,
  }) async {
    if (hasErrorState) {
      await _storage.write(_healthyUsageStreakKey, 0);
      await _storage.remove(_healthyUsageLastDayKey);
      return;
    }

    final today = _dayOrdinal(_now());
    final lastDay = _storage.read<int>(_healthyUsageLastDayKey);
    if (lastDay == today) return;

    final previousStreak = _storage.read<int>(_healthyUsageStreakKey) ?? 0;
    final streak = lastDay != null && today - lastDay == 1
        ? previousStreak + 1
        : 1;

    await _storage.write(_healthyUsageLastDayKey, today);
    await _storage.write(_healthyUsageStreakKey, streak);

    if (streak < _requiredHealthyUsageDays) return;
    await _maybeRequestReview(trigger: 'healthy_usage');
  }

  Future<void> requestReview({String trigger = 'manual'}) async {
    try {
      await _requestReview();
      await _storage.write(_lastReviewKey, _now().millisecondsSinceEpoch);
      Log.i('In-App Review 请求已发起');
      await AnalyticsService.instance.track(
        'review_prompt_result',
        params: <String, Object>{'result': 'completed', 'trigger': trigger},
      );
    } catch (e, st) {
      Log.e('In-App Review 请求失败', error: e, stackTrace: st);
      await AnalyticsService.instance.track(
        'review_prompt_result',
        params: <String, Object>{
          'result': 'failed',
          'trigger': trigger,
          'error_type': e.runtimeType.toString(),
        },
      );
    }
  }

  Future<void> openStoreListing() async {
    await _openStoreListing();
  }

  Future<bool> _maybeRequestReview({required String trigger}) async {
    final now = _now().millisecondsSinceEpoch;
    final lastRequest = _storage.read<int>(_lastReviewKey) ?? 0;
    final cooldown = Duration(days: _cooldownDays).inMilliseconds;
    if (lastRequest > 0 && now - lastRequest < cooldown) return false;

    await AnalyticsService.instance.track(
      'review_prompt_shown',
      params: <String, Object>{'trigger': trigger},
    );
    await requestReview(trigger: trigger);
    return true;
  }

  int _dayOrdinal(DateTime date) {
    return DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }
}
