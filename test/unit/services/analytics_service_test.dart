import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/services/analytics_env.dart';
import 'package:windwalker/services/analytics_privacy_filter.dart';
import 'package:windwalker/services/analytics_service.dart';

/// 记录所有上报调用的假 AnalyticsBackend。
class _FakeBackend extends AnalyticsBackend {
  _FakeBackend() : super.forTest();

  final List<Map<String, Object>> logEventCalls = [];
  final Map<String, String?> userProperties = {};
  String? userId;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    logEventCalls.add({'name': name, 'parameters': parameters ?? const {}});
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) async {
    userProperties[name] = value;
  }

  @override
  Future<void> setUserId(String? id) async {
    userId = id;
  }
}

/// 假 env provider：返回固定值，不依赖平台插件。
class _FakeEnvProvider implements AnalyticsEnvProvider {
  @override
  Future<Map<String, Object>> getEnvParams() async {
    return <String, Object>{
      'platform': 'test_platform',
      'distribution_channel': 'github',
      'release_track': 'beta',
    };
  }
}

/// 抛异常的 env provider：验证静默降级。
class _ThrowingEnvProvider implements AnalyticsEnvProvider {
  @override
  Future<Map<String, Object>> getEnvParams() async {
    throw Exception('env provider failed');
  }
}

void main() {
  group('AnalyticsService', () {
    test('track 上报事件并注入 env params', () async {
      final fake = _FakeBackend();
      final service = AnalyticsService(
        backend: fake,
        envProvider: _FakeEnvProvider(),
        privacyFilter: AnalyticsPrivacyFilter(
          mode: ReleaseModeAssertion.disabled,
        ),
      );

      await service.track('test_event', params: {'result': 'success'});

      expect(fake.logEventCalls, hasLength(1));
      expect(fake.logEventCalls.first['name'], 'test_event');
      final params =
          fake.logEventCalls.first['parameters'] as Map<String, Object>;
      expect(params['result'], 'success');
      expect(params['platform'], 'test_platform');
    });

    test('track 隐私护栏截断敏感字段', () async {
      final fake = _FakeBackend();
      final service = AnalyticsService(
        backend: fake,
        envProvider: _FakeEnvProvider(),
        privacyFilter: AnalyticsPrivacyFilter(
          mode: ReleaseModeAssertion.disabled,
        ),
      );

      await service.track('test_event', params: {'host': 'secret-host'});

      expect(fake.logEventCalls, hasLength(1));
      final params =
          fake.logEventCalls.first['parameters'] as Map<String, Object>;
      expect(params.containsKey('host'), isFalse);
    });

    test('build identity cannot be overridden by event parameters', () async {
      final fake = _FakeBackend();
      final service = AnalyticsService(
        backend: fake,
        envProvider: _FakeEnvProvider(),
        privacyFilter: AnalyticsPrivacyFilter(
          mode: ReleaseModeAssertion.disabled,
        ),
      );

      await service.track(
        'test_event',
        params: <String, Object>{
          'distribution_channel': 'play',
          'release_track': 'stable',
        },
      );

      final params =
          fake.logEventCalls.single['parameters'] as Map<String, Object>;
      expect(params['distribution_channel'], 'github');
      expect(params['release_track'], 'beta');
    });

    test('syncBuildUserProperties mirrors channel and track', () async {
      final fake = _FakeBackend();
      final service = AnalyticsService(
        backend: fake,
        envProvider: _FakeEnvProvider(),
        privacyFilter: AnalyticsPrivacyFilter(
          mode: ReleaseModeAssertion.disabled,
        ),
      );

      await service.syncBuildUserProperties();

      expect(fake.userProperties['distribution_channel'], 'github');
      expect(fake.userProperties['release_track'], 'beta');
    });

    test('setUserId 上报到 backend', () async {
      final fake = _FakeBackend();
      final service = AnalyticsService(
        backend: fake,
        envProvider: _FakeEnvProvider(),
        privacyFilter: AnalyticsPrivacyFilter(
          mode: ReleaseModeAssertion.disabled,
        ),
      );

      await service.setUserId('uid-123');
      expect(fake.userId, 'uid-123');

      await service.setUserId(null);
      expect(fake.userId, isNull);
    });

    test('setUserProperty 上报到 backend', () async {
      final fake = _FakeBackend();
      final service = AnalyticsService(
        backend: fake,
        envProvider: _FakeEnvProvider(),
        privacyFilter: AnalyticsPrivacyFilter(
          mode: ReleaseModeAssertion.disabled,
        ),
      );

      await service.setUserProperty('is_anonymous', 'true');
      expect(fake.userProperties['is_anonymous'], 'true');
    });

    test('track 异常不抛出（静默失败）', () async {
      final fake = _FakeBackend();
      final service = AnalyticsService(
        backend: fake,
        envProvider: _ThrowingEnvProvider(),
        privacyFilter: AnalyticsPrivacyFilter(
          mode: ReleaseModeAssertion.disabled,
        ),
      );

      await service.track('test_event');
      expect(fake.logEventCalls, isEmpty);
    });

    test('resetUserProperties 清理 userId 和用户属性', () async {
      final fake = _FakeBackend();
      final service = AnalyticsService(
        backend: fake,
        envProvider: _FakeEnvProvider(),
        privacyFilter: AnalyticsPrivacyFilter(
          mode: ReleaseModeAssertion.disabled,
        ),
      );

      await service.setUserProperty('user_role', 'vip');
      await service.setUserId('uid-123');
      await service.resetUserProperties();

      expect(fake.userId, isNull);
      expect(fake.userProperties['user_role'], isNull);
    });
  });
}
