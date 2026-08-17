import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/services/analytics_privacy_filter.dart';

void main() {
  group('AnalyticsPrivacyFilter', () {
    test('保留普通参数', () {
      final filter = AnalyticsPrivacyFilter();
      final input = <String, Object>{
        'result': 'success',
        'downloader_type': 'aria2',
        'task_count': 5,
      };
      expect(filter.scrub(input), equals(input));
    });

    test('Release 模式截断含 url 的字段并记录违规', () {
      final filter = AnalyticsPrivacyFilter(mode: ReleaseModeAssertion.disabled);
      final input = <String, Object>{
        'task_url': 'http://example.com/file.torrent',
        'result': 'success',
      };
      final result = filter.scrub(input);
      expect(result.containsKey('task_url'), isFalse);
      expect(result['result'], 'success');
      expect(filter.lastViolations, contains('task_url'));
    });

    test('Debug 模式抛异常', () {
      final filter = AnalyticsPrivacyFilter(mode: ReleaseModeAssertion.enabled);
      final input = <String, Object>{'host': '192.168.1.1'};
      expect(
        () => filter.scrub(input),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('匹配所有黑名单关键字', () {
      final seen = <String>[];
      final keys = <String>[
        'url', 'host', 'port', 'path', 'secret', 'password', 'token',
        'task_name', 'file_name', 'display_name', 'email', 'phone',
        'save_path', 'tracker',
      ];
      for (final key in keys) {
        final filter = AnalyticsPrivacyFilter(
          mode: ReleaseModeAssertion.disabled,
        );
        filter.scrub({key: 'value'});
        seen.addAll(filter.lastViolations);
      }
      expect(seen, containsAll(keys));
    });
  });
}
