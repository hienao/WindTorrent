import 'package:windwalker/features/update/domain/update_check_result.dart';

enum UpdatePromptDecision {
  none,
  badgeOnly,
  dialogAllowed,
}

class UpdatePromptPolicy {
  const UpdatePromptPolicy({
    this.cooldown = const Duration(days: 7),
  });

  final Duration cooldown;

  UpdatePromptDecision evaluate({
    required UpdateCheckResult result,
    required DateTime now,
    required bool hasActiveDownloads,
    required bool dialogConsumedInSession,
    required DateTime? lastPromptAt,
    required String? lastPromptDayKey,
    required int? dismissedVersionCode,
  }) {
    if (!result.hasUpdate) {
      return UpdatePromptDecision.none;
    }

    if (hasActiveDownloads) return UpdatePromptDecision.badgeOnly;
    if (dialogConsumedInSession) return UpdatePromptDecision.badgeOnly;
    if (dismissedVersionCode == result.availableVersionCode) {
      return UpdatePromptDecision.badgeOnly;
    }

    final dayKey = _dayKey(now);
    if (lastPromptDayKey == dayKey) return UpdatePromptDecision.badgeOnly;
    if (lastPromptAt != null && now.difference(lastPromptAt) < cooldown) {
      return UpdatePromptDecision.badgeOnly;
    }

    return UpdatePromptDecision.dialogAllowed;
  }

  String dayKey(DateTime value) => _dayKey(value);

  String _dayKey(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
  }
}
