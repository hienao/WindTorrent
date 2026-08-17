import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/domain/update_prompt_policy.dart';

void main() {
  group('UpdatePromptPolicy', () {
    final now = DateTime(2026, 6, 15, 10);

    test('returns dialogAllowed when update exists and all limits pass', () {
      final decision = const UpdatePromptPolicy().evaluate(
        result: const UpdateCheckResult.available(2026061501),
        now: now,
        hasActiveDownloads: false,
        dialogConsumedInSession: false,
        lastPromptAt: now.subtract(const Duration(days: 8)),
        lastPromptDayKey: '2026-06-07',
        dismissedVersionCode: null,
      );

      expect(decision, UpdatePromptDecision.dialogAllowed);
    });

    test('returns badgeOnly when active downloads exist', () {
      final decision = const UpdatePromptPolicy().evaluate(
        result: const UpdateCheckResult.available(2026061501),
        now: now,
        hasActiveDownloads: true,
        dialogConsumedInSession: false,
        lastPromptAt: null,
        lastPromptDayKey: null,
        dismissedVersionCode: null,
      );

      expect(decision, UpdatePromptDecision.badgeOnly);
    });

    test('returns none when result is unsupported', () {
      final decision = const UpdatePromptPolicy().evaluate(
        result: const UpdateCheckResult.unsupported(),
        now: now,
        hasActiveDownloads: false,
        dialogConsumedInSession: false,
        lastPromptAt: null,
        lastPromptDayKey: null,
        dismissedVersionCode: null,
      );

      expect(decision, UpdatePromptDecision.none);
    });
  });
}
