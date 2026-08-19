import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/services/analytics_env.dart';
import 'package:windwalker/services/analytics_privacy_filter.dart';

/// Firebase Analytics 的窄抽象，便于测试替换。
///
/// AnalyticsService 依赖此类型而非具体 FirebaseAnalytics，遵循依赖倒置。
/// 生产环境用默认构造注入真实 FirebaseAnalytics；测试用 _FakeBackend 子类
/// 绕过 Firebase 初始化。
class AnalyticsBackend {
  AnalyticsBackend([FirebaseAnalytics? analytics]) : _injected = analytics;

  /// 测试用构造函数：不绑定真实 FirebaseAnalytics（子类需 override 所有方法）。
  const AnalyticsBackend.forTest() : _injected = null;

  final FirebaseAnalytics? _injected;

  /// 惰性获取 FirebaseAnalytics.instance，延迟到方法调用时。
  /// 这样测试环境的初始化异常会被 AnalyticsService 的 try/catch 捕获。
  FirebaseAnalytics get _analytics => _injected ?? FirebaseAnalytics.instance;

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  Future<void> setUserProperty({required String name, String? value}) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  Future<void> setUserId(String? id) async {
    await _analytics.setUserId(id: id);
  }
}

/// 埋点统一入口。
///
/// 职责：
/// - 注入公共 env params（app_version/platform/locale 等）
/// - 隐私护栏过滤敏感字段
/// - 上报事件 / 用户属性 / userId
/// - 上报失败静默降级（只日志，不抛异常，不阻塞业务）
class AnalyticsService {
  AnalyticsService({
    AnalyticsEnvProvider? envProvider,
    AnalyticsPrivacyFilter? privacyFilter,
    AnalyticsBackend? backend,
  }) : _envProvider = envProvider ?? AnalyticsEnvProvider(),
       _privacyFilter = privacyFilter ?? AnalyticsPrivacyFilter(),
       _backend = backend ?? AnalyticsBackend();

  static final instance = AnalyticsService._default();

  AnalyticsService._default()
    : _envProvider = AnalyticsEnvProvider(),
      _privacyFilter = AnalyticsPrivacyFilter(),
      _backend = AnalyticsBackend();

  static const _tag = 'AnalyticsService';

  final AnalyticsEnvProvider _envProvider;
  final AnalyticsPrivacyFilter _privacyFilter;
  final AnalyticsBackend _backend;

  /// 上报事件（自动合并 env params + 隐私护栏）。
  Future<void> track(String name, {Map<String, Object>? params}) async {
    try {
      final env = await _envProvider.getEnvParams();
      // Build identity is reserved metadata and cannot be overridden by an
      // individual event call.
      final merged = <String, Object>{...?params, ...env};
      final safe = _privacyFilter.scrub(merged);
      await _backend.logEvent(name: name, parameters: safe);
    } catch (e) {
      Log.w('上报事件失败: $name, error=$e', tag: _tag);
    }
  }

  /// 设置用户属性（分群）。
  ///
  /// 属性名走隐私护栏黑名单校验（spec §3.4：user_property 也走同一套校验）。
  Future<void> setUserProperty(String name, String? value) async {
    // 隐私护栏：属性名校验（值通常为枚举字符串，不单独过滤）
    final nameScrub = _privacyFilter.scrub({name: value ?? ''});
    if (!nameScrub.containsKey(name)) {
      Log.w('用户属性名被隐私护栏拦截: $name', tag: _tag);
      return;
    }
    try {
      await _backend.setUserProperty(name: name, value: value);
    } catch (e) {
      Log.w('设置用户属性失败: $name, error=$e', tag: _tag);
    }
  }

  /// 批量设置用户属性。
  Future<void> setUserProperties(Map<String, Object?> properties) async {
    for (final entry in properties.entries) {
      await setUserProperty(entry.key, entry.value?.toString());
    }
  }

  /// Mirrors build identity to Firebase user properties for segmentation.
  Future<void> syncBuildUserProperties() async {
    try {
      final env = await _envProvider.getEnvParams();
      await setUserProperties(<String, Object?>{
        'distribution_channel': env['distribution_channel'],
        'release_track': env['release_track'],
      });
    } catch (e) {
      Log.w('同步构建渠道用户属性失败: $e', tag: _tag);
    }
  }

  /// 绑定/解绑用户 ID。
  Future<void> setUserId(String? userId) async {
    try {
      await _backend.setUserId(userId);
    } catch (e) {
      Log.w('设置 userId 失败: error=$e', tag: _tag);
    }
  }

  /// 退出登录时清理用户相关属性。
  Future<void> resetUserProperties() async {
    const properties = ['user_role', 'account_age_days'];
    for (final p in properties) {
      await setUserProperty(p, null);
    }
    await setUserId(null);
  }
}
