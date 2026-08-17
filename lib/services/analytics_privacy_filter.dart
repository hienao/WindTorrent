import 'package:flutter/foundation.dart';
import 'package:windwalker/core/utils/log.dart';

/// 控制隐私护栏在 Debug 模式下的行为。
enum ReleaseModeAssertion {
  /// Debug 模式抛异常（生产环境行为）。
  enabled,

  /// 不抛异常（用于测试模拟 release 模式）。
  disabled,
}

/// 隐私护栏：拦截字段名命中黑名单关键字的参数。
///
/// Debug 模式（kDebugMode && assertion enabled）：抛 ArgumentError 尽早暴露。
/// Release 模式：截断字段 + Log.w 告警，lastViolations 记录被截断的字段名。
class AnalyticsPrivacyFilter {
  AnalyticsPrivacyFilter({ReleaseModeAssertion? mode}) : _forceMode = mode;

  static const _tag = 'AnalyticsPrivacy';
  static const _blacklist = [
    'url',
    'host',
    'port',
    'path',
    'secret',
    'password',
    'token',
    'task_name',
    'file_name',
    'display_name',
    'email',
    'phone',
    'save_path',
    'tracker',
  ];

  final ReleaseModeAssertion? _forceMode;
  List<String> lastViolations = const [];

  /// 过滤参数，返回安全副本。
  Map<String, Object> scrub(Map<String, Object>? params) {
    lastViolations = const [];
    if (params == null || params.isEmpty) return const {};

    final violations = <String>[];
    final safe = <String, Object>{};

    for (final entry in params.entries) {
      if (_isViolating(entry.key)) {
        violations.add(entry.key);
      } else {
        safe[entry.key] = entry.value;
      }
    }

    if (violations.isEmpty) return safe;

    lastViolations = violations;
    final shouldThrow = _effectiveMode() == ReleaseModeAssertion.enabled;

    for (final v in violations) {
      Log.w('隐私护栏拦截字段: $v', tag: _tag);
    }

    if (shouldThrow) {
      throw ArgumentError('隐私护栏：字段含黑名单关键字 $violations');
    }

    return safe;
  }

  bool _isViolating(String key) {
    final lower = key.toLowerCase();
    return _blacklist.any((kw) => lower.contains(kw));
  }

  ReleaseModeAssertion _effectiveMode() {
    if (_forceMode != null) return _forceMode;
    return kDebugMode
        ? ReleaseModeAssertion.enabled
        : ReleaseModeAssertion.disabled;
  }
}
