# WindWalker 埋点体系实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 WindWalker 建立完整、隐私安全的 Firebase Analytics 埋点体系，覆盖启动/认证/下载器/任务/更新/评价/设置七大模块，共 20 个自定义事件 + 9 个 user_property。

**Architecture:** 统一 `AnalyticsService` 单例封装事件上报/用户属性/隐私护栏；现有 `AuthTelemetryService` 重构为薄封装消除重复；各 controller 与关键 UI 页面在业务节点调用埋点。严格隐私护栏（字段黑名单硬规则），沿用现有 `result/error_type/reason` 命名三件套。

**Tech Stack:** Flutter 3.24.5、firebase_analytics ^12.0.2、connectivity_plus ^7.0.0、device_info_plus ^13.1.0、package_info_plus ^10.1.0、get_storage ^2.1.1、mockito ^5.6.4（测试）

**Spec:** `docs/superpowers/specs/2026-06-22-analytics-tracking-design.md`

---

## 文件结构总览

**新建文件：**
- `lib/services/analytics_service.dart` — 埋点统一入口（单例），封装 track/setUserProperty/setUserId/隐私护栏/env params 注入
- `lib/services/analytics_env.dart` — env params 提供者（从 AuthTelemetryService._getEnvParams 抽出，独立可测）
- `lib/services/analytics_privacy_filter.dart` — 隐私护栏黑名单过滤器（独立可测）
- `test/unit/services/analytics_service_test.dart` — AnalyticsService 单元测试
- `test/unit/services/analytics_privacy_filter_test.dart` — 隐私护栏单元测试

**修改文件：**
- `lib/services/auth_telemetry_service.dart` — 重构为 AnalyticsService 薄封装
- `lib/main.dart` — 启动埋点（first_open / launch / init_failed）
- `lib/core/utils/startup_trace.dart` — 接入 app_launch 上报
- `lib/features/auth/presentation/controllers/auth_controller.dart` — session_state_changed / sign_out / setUserId / user_property
- `lib/features/downloaders/presentation/controllers/downloader_controller.dart` — 4 个下载器事件 + 删旧接口 + user_property
- `lib/features/tasks/presentation/controllers/task_controller.dart` — 4 个任务事件 + 删旧接口 + user_property
- `lib/features/tasks/presentation/pages/tasks_page.dart` — task_list_viewed
- `lib/features/tasks/presentation/pages/task_detail_page.dart` — task_detail_viewed
- `lib/features/update/presentation/controllers/update_controller.dart` — 2 个更新事件
- `lib/core/utils/review_manager.dart` — 2 个评价事件
- `lib/features/settings/presentation/controllers/settings_controller.dart` — 2 个设置事件 + user_property

**删除测试（因旧接口被删，对应测试一并删除）：**
- `test/unit/downloader_controller_add_task_test.dart` — 测试 `DownloaderController.addTask`（已删）

---

## Task 1: 隐私护栏过滤器（analytics_privacy_filter.dart）

**Files:**
- Create: `lib/services/analytics_privacy_filter.dart`
- Test: `test/unit/services/analytics_privacy_filter_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/unit/services/analytics_privacy_filter_test.dart
import 'package:flutter/foundation.dart';
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
      final filter = AnalyticsPrivacyFilter(mode: ReleaseModeAssertion.disabled);
      final keys = [
        'url', 'host', 'port', 'path', 'secret', 'password', 'token',
        'task_name', 'file_name', 'display_name', 'email', 'phone',
        'save_path', 'tracker',
      ];
      for (final key in keys) {
        filter.scrub({key: 'value'});
      }
      expect(filter.lastViolations, containsAll(keys));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/unit/services/analytics_privacy_filter_test.dart`
Expected: FAIL — `AnalyticsPrivacyFilter` 未定义 / import 失败

- [ ] **Step 3: 写最小实现**

```dart
// lib/services/analytics_privacy_filter.dart
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
  AnalyticsPrivacyFilter({ReleaseModeAssertion? mode})
    : _forceMode = mode;

  static const _tag = 'AnalyticsPrivacy';
  static const _blacklist = [
    'url', 'host', 'port', 'path', 'secret', 'password', 'token',
    'task_name', 'file_name', 'display_name', 'email', 'phone',
    'save_path', 'tracker',
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
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/unit/services/analytics_privacy_filter_test.dart`
Expected: PASS（4 个测试）

- [ ] **Step 5: 提交**

```bash
git add lib/services/analytics_privacy_filter.dart test/unit/services/analytics_privacy_filter_test.dart
git commit -m "feat(analytics): add privacy filter with field blacklist"
```

---

## Task 2: Env Params 提供者（analytics_env.dart）

**Files:**
- Create: `lib/services/analytics_env.dart`
- Test: `test/unit/services/analytics_env_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/unit/services/analytics_env_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/services/analytics_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/tmp/test_windwalker';
        }
        return null;
      },
    );
    await GetStorage.init();
  });

  test('getEnvParams 返回必填字段', () async {
    final provider = AnalyticsEnvProvider();
    final env = await provider.getEnvParams();

    expect(env.containsKey('app_version'), isTrue);
    expect(env.containsKey('app_build'), isTrue);
    expect(env.containsKey('platform'), isTrue);
    expect(env.containsKey('locale'), isTrue);
    expect(env.containsKey('network_type'), isTrue);
  });

  test('缓存后第二次调用不重新读 PackageInfo', () async {
    final provider = AnalyticsEnvProvider();
    await provider.getEnvParams();
    // 第二次调用应走缓存，network_type 仍会刷新但其余字段不变
    final env2 = await provider.getEnvParams();
    expect(env2.containsKey('app_version'), isTrue);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/unit/services/analytics_env_test.dart`
Expected: FAIL — `AnalyticsEnvProvider` 未定义

- [ ] **Step 3: 写最小实现**

```dart
// lib/services/analytics_env.dart
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:windwalker/core/utils/log.dart';

/// 环境参数提供者：注入 app_version/platform/locale/network_type 等公共参数。
///
/// 从 AuthTelemetryService._getEnvParams 抽出，独立可测。
/// 除 network_type 外的字段缓存复用。
class AnalyticsEnvProvider {
  AnalyticsEnvProvider();

  static const _tag = 'AnalyticsEnv';
  Map<String, Object>? _cached;

  Future<Map<String, Object>> getEnvParams() async {
    final networkType = await _getNetworkType();
    if (_cached != null) {
      return <String, Object>{
        ..._cached!,
        'network_type': networkType,
      };
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final locale = ui.PlatformDispatcher.instance.locale;
    final env = <String, Object>{
      'app_version': packageInfo.version,
      'app_build': packageInfo.buildNumber,
      'platform': Platform.operatingSystem,
      'os_version': _shortOsVersion(Platform.operatingSystemVersion),
      'locale': locale.toLanguageTag(),
      'network_type': networkType,
    };

    if (Platform.isAndroid) {
      try {
        final android = await DeviceInfoPlugin().androidInfo;
        env['android_api_level'] = android.version.sdkInt;
        env['android_release'] = android.version.release;
      } catch (e) {
        Log.w('读取 Android 设备信息失败: $e', tag: _tag);
      }
    }

    _cached = env;
    return env;
  }

  Future<String> _getNetworkType() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty) return 'unknown';
      if (results.length > 1) return 'multi';
      return results.first.name;
    } catch (e) {
      Log.w('读取网络类型失败: $e', tag: _tag);
      return 'unknown';
    }
  }

  String _shortOsVersion(String osVersion) {
    if (osVersion.length <= 80) return osVersion;
    return osVersion.substring(0, 80);
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/unit/services/analytics_env_test.dart`
Expected: PASS（2 个测试）

- [ ] **Step 5: 提交**

```bash
git add lib/services/analytics_env.dart test/unit/services/analytics_env_test.dart
git commit -m "feat(analytics): extract env params provider"
```

---

## Task 3: AnalyticsService 单例（analytics_service.dart）

**Files:**
- Create: `lib/services/analytics_service.dart`
- Test: `test/unit/services/analytics_service_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/unit/services/analytics_service_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 记录上报到 Firebase Analytics MethodChannel 的事件
  final List<Map<String, dynamic>> loggedEvents = [];

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_analytics'),
      (MethodCall call) async {
        if (call.method == 'logEvent') {
          loggedEvents.add(Map<String, dynamic>.from(call.arguments as Map));
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/tmp/test_windwalker';
        }
        return null;
      },
    );
    await GetStorage.init();
  });

  setUp(() {
    loggedEvents.clear();
  });

  test('track 上报事件并注入 env params', () async {
    final service = AnalyticsService(
      envProvider: _FakeEnvProvider(),
      privacyFilter: AnalyticsPrivacyFilter(
        mode: ReleaseModeAssertion.disabled,
      ),
    );

    await service.track('test_event', params: {'result': 'success'});

    expect(loggedEvents, hasLength(1));
    expect(loggedEvents.first['eventName'], 'test_event');
    final params = loggedEvents.first['parameters'] as Map;
    expect(params['result'], 'success');
    expect(params['platform'], 'test_platform'); // 来自 fake env
  });

  test('track 隐私护栏截断敏感字段', () async {
    final service = AnalyticsService(
      envProvider: _FakeEnvProvider(),
      privacyFilter: AnalyticsPrivacyFilter(
        mode: ReleaseModeAssertion.disabled,
      ),
    );

    await service.track('test_event', params: {'host': 'secret-host'});

    expect(loggedEvents, hasLength(1));
    final params = loggedEvents.first['parameters'] as Map;
    expect(params.containsKey('host'), isFalse);
  });

  test('setUserId 上报到 channel', () async {
    String? reportedUserId;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_analytics'),
      (MethodCall call) async {
        if (call.method == 'setUserId') {
          reportedUserId = call.arguments as String?;
        }
        return null;
      },
    );

    final service = AnalyticsService(
      envProvider: _FakeEnvProvider(),
      privacyFilter: AnalyticsPrivacyFilter(
        mode: ReleaseModeAssertion.disabled,
      ),
    );

    await service.setUserId('uid-123');
    expect(reportedUserId, 'uid-123');

    await service.setUserId(null);
    expect(reportedUserId, isNull);
  });

  test('track 异常不抛出（静默失败 + 日志）', () async {
    final service = AnalyticsService(
      envProvider: _ThrowingEnvProvider(),
      privacyFilter: AnalyticsPrivacyFilter(
        mode: ReleaseModeAssertion.disabled,
      ),
    );

    // 不应抛异常
    await service.track('test_event');
    expect(loggedEvents, isEmpty);
  });
}

class _FakeEnvProvider implements AnalyticsEnvProvider {
  @override
  Map<String, Object>? _cached;

  @override
  Future<Map<String, Object>> getEnvParams() async {
    return {'platform': 'test_platform'};
  }
}

/// 注意：AnalyticsEnvProvider 不是 abstract，测试需要继承。
/// 改用实现接口的方式 —— 见 Task 3 实现中提取接口。
class _ThrowingEnvProvider implements AnalyticsEnvProvider {
  @override
  Map<String, Object>? _cached;

  @override
  Future<Map<String, Object>> getEnvParams() async {
    throw Exception('env provider failed');
  }
}
```

注意：测试中 `_FakeEnvProvider` 用 `implements`，因此 `AnalyticsEnvProvider` 需要被引用为可实现的接口。实现时把 `AnalyticsEnvProvider` 的核心方法抽到一个抽象接口，或让测试直接继承。**实现时采用方案：让 `AnalyticsService` 接受 `AnalyticsEnvProvider` 类型参数，测试中用 `implements` mock ——这要求 `AnalyticsEnvProvider` 可被 implements（普通类即可，Dart 支持 implements 普通类）。** `_cached` 字段在 fake 中置空即可。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/unit/services/analytics_service_test.dart`
Expected: FAIL — `AnalyticsService` 未定义

- [ ] **Step 3: 写最小实现**

```dart
// lib/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/services/analytics_env.dart';
import 'package:windwalker/services/analytics_privacy_filter.dart';

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
    FirebaseAnalytics? analytics,
  }) : _envProvider = envProvider ?? AnalyticsEnvProvider(),
       _privacyFilter = privacyFilter ?? AnalyticsPrivacyFilter(),
       _analytics = analytics ?? FirebaseAnalytics.instance;

  static final instance = AnalyticsService._default();

  AnalyticsService._default()
    : _envProvider = AnalyticsEnvProvider(),
      _privacyFilter = AnalyticsPrivacyFilter(),
      _analytics = FirebaseAnalytics.instance;

  static const _tag = 'AnalyticsService';

  final AnalyticsEnvProvider _envProvider;
  final AnalyticsPrivacyFilter _privacyFilter;
  final FirebaseAnalytics _analytics;

  /// 上报事件（自动合并 env params + 隐私护栏）。
  Future<void> track(
    String name, {
    Map<String, Object>? params,
  }) async {
    try {
      final env = await _envProvider.getEnvParams();
      final merged = <String, Object>{...env, ...?params};
      final safe = _privacyFilter.scrub(merged);
      await _analytics.logEvent(name: name, parameters: safe);
    } catch (e, st) {
      Log.w('上报事件失败: $name, error=$e', tag: _tag);
      Log.d('$st', tag: _tag);
    }
  }

  /// 设置用户属性（分群）。
  Future<void> setUserProperty(String name, String? value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
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

  /// 绑定/解绑用户 ID。
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      Log.w('设置 userId 失败: error=$e', tag: _tag);
    }
  }

  /// 退出登录时清理用户相关属性。
  Future<void> resetUserProperties() async {
    const properties = [
      'user_role', 'account_age_days',
    ];
    for (final p in properties) {
      await setUserProperty(p, null);
    }
    await setUserId(null);
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/unit/services/analytics_service_test.dart`
Expected: PASS（4 个测试）

- [ ] **Step 5: 提交**

```bash
git add lib/services/analytics_service.dart test/unit/services/analytics_service_test.dart
git commit -m "feat(analytics): add AnalyticsService singleton"
```

---

## Task 4: 重构 AuthTelemetryService 为薄封装

**Files:**
- Modify: `lib/services/auth_telemetry_service.dart`

- [ ] **Step 1: 重写为薄封装**

```dart
// lib/services/auth_telemetry_service.dart
import 'package:windwalker/services/analytics_service.dart';
import 'package:windwalker/services/auth_provider.dart';

/// 认证埋点（薄封装 AnalyticsService，保持外部 API 不变）。
///
/// 历史原因：早期独立的 env params 逻辑已下沉到 AnalyticsService，
/// 此处仅保留领域语义化的方法名。
class AuthTelemetryService {
  AuthTelemetryService._();

  static Future<void> trackGoogleSignInSuccess() async {
    await AnalyticsService.instance.track(
      'auth_google_sign_in_result',
      params: <String, Object>{'result': 'success'},
    );
  }

  static Future<void> trackGoogleSignInFailure({
    required String errorType,
    AuthFailureReason? reason,
    String? providerCode,
  }) async {
    await AnalyticsService.instance.track(
      'auth_google_sign_in_result',
      params: <String, Object>{
        'result': 'failed',
        'error_type': errorType,
        'reason': reason?.name ?? AuthFailureReason.unknown.name,
        'provider_code': providerCode ?? 'none',
      },
    );
  }
}
```

- [ ] **Step 2: 运行现有认证测试验证回归**

Run: `flutter test test/unit/auth_controller_test.dart`
Expected: PASS（API 不变，零回归）

- [ ] **Step 3: 提交**

```bash
git add lib/services/auth_telemetry_service.dart
git commit -m "refactor(analytics): AuthTelemetryService as thin wrapper"
```

---

## Task 5: 启动埋点（main.dart + startup_trace.dart）

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/core/utils/startup_trace.dart`

- [ ] **Step 1: 先读取 startup_trace.dart 了解现有结构**

Run: `cat lib/core/utils/startup_trace.dart`（或用 Read 工具）

了解 `markFirstFrameBuilt()` 的实现位置，确定在哪插入 `app_launch` 上报。

- [ ] **Step 2: 在 startup_trace.dart 中接入 app_launch 上报**

在 `markFirstFrameBuilt()` 内，首帧构建完成时计算从 `main_enter` 的耗时并上报。新增 `reportLaunchIfNeeded()` 方法：

```dart
// 在 StartupTrace 类内新增
static int? _mainEnterMillis;

static void setMainEnterMillis(int millis) {
  _mainEnterMillis = millis;
}

/// 上报启动耗时事件（首帧构建完成时调用一次）。
static Future<void> reportLaunchIfNeeded() async {
  if (_launchReported) return;
  _launchReported = true;
  if (_mainEnterMillis == null) return;

  final firstFrameMillis = _marks['first_frame_built'];
  if (firstFrameMillis == null) return;

  final duration = firstFrameMillis - _mainEnterMillis;
  await AnalyticsService.instance.track(
    'app_launch',
    params: <String, Object>{
      'launch_duration_ms': duration,
      'init_phase': 'completed',
      'cold_start': true, // best-effort，Flutter 无直接 API 判断冷热启
    },
  );
}

static bool _launchReported = false;
```

- [ ] **Step 3: 在 main.dart 中埋 first_open + init_failed**

```dart
// lib/main.dart（关键改动点）
// 在文件顶部 main() 第一行记录 main_enter 时间戳
void main() async {
  StartupTrace.mark('main_enter');
  StartupTrace.setMainEnterMillis(DateTime.now().millisecondsSinceEpoch);
  WidgetsFlutterBinding.ensureInitialized();
  StartupTrace.mark('binding_ready');

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  StartupTrace.mark('edge_to_edge_ready');

  Log.init(tag: 'WindWalker', usePlatformLogging: !kDebugMode);
  StartupTrace.mark('log_ready');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    StartupTrace.markFirstFrameBuilt();
    StartupTrace.reportLaunchIfNeeded();
  });
  WidgetsBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    if (timings.isNotEmpty) {
      StartupTrace.markFirstFrameRasterized();
    }
  });

  // first_open 上报（基于 GetStorage 标记位）
  await _trackFirstOpenIfNeeded();

  StartupTrace.mark('firebase_init_start');
  try {
    await Firebase.initializeApp();
    await FirebaseAuth.instance.setLanguageCode('en');
    StartupTrace.mark('firebase_init_done');
  } catch (e, st) {
    await AnalyticsService.instance.track(
      'app_init_failed',
      params: <String, Object>{
        'phase': 'firebase',
        'error_type': e.runtimeType.toString(),
      },
    );
    rethrow; // fail-fast 原则：不吞异常
  }

  StartupTrace.mark('get_storage_init_start');
  try {
    await GetStorage.init();
    StartupTrace.mark('get_storage_init_done');
  } catch (e, st) {
    await AnalyticsService.instance.track(
      'app_init_failed',
      params: <String, Object>{
        'phase': 'get_storage',
        'error_type': e.runtimeType.toString(),
      },
    );
    rethrow;
  }

  StartupTrace.mark('run_app');
  runApp(const WindWalkerApp());
}

Future<void> _trackFirstOpenIfNeeded() async {
  try {
    final storage = GetStorage();
    final flagged = storage.read<bool>('app_first_open') ?? false;
    if (!flagged) {
      await storage.write('app_first_open', true);
      await AnalyticsService.instance.track('app_first_open_tracked');
    }
  } catch (e) {
    // first_open 是软标记，失败不影响启动
  }
}
```

注意：`_trackFirstOpenIfNeeded` 在 `GetStorage.init()` **之前**调用会有问题（storage 未初始化）。必须移到 `GetStorage.init()` 之后。修正实现时把 `_trackFirstOpenIfNeeded()` 调用放在 `GetStorage.init()` 之后、`runApp` 之前。

- [ ] **Step 4: 验证编译**

Run: `flutter analyze lib/main.dart lib/core/utils/startup_trace.dart`
Expected: 无错误

- [ ] **Step 5: 运行全量测试验证无回归**

Run: `flutter test`
Expected: 全部 PASS

- [ ] **Step 6: 提交**

```bash
git add lib/main.dart lib/core/utils/startup_trace.dart
git commit -m "feat(analytics): add startup lifecycle events"
```

---

## Task 6: 认证模块补埋（session_state / sign_out / user_property）

**Files:**
- Modify: `lib/features/auth/presentation/controllers/auth_controller.dart`
- Test: `test/unit/auth_controller_test.dart`

- [ ] **Step 1: 读取现有 auth_controller.dart 全文**

用 Read 工具读取 `lib/features/auth/presentation/controllers/auth_controller.dart`，确认 `_init`、`_authSub`、`signInWithGoogle`、`signOut` 的结构。

- [ ] **Step 2: 写 session_state_changed 和 sign_out 的失败测试**

在 `test/unit/auth_controller_test.dart` 末尾追加：

```dart
test('signOut 成功上报 auth_sign_out_result', () async {
  final storage = GetStorage();
  storage.write('user_uid', 'test-uid');
  storage.write('auth_last_check', DateTime.now().millisecondsSinceEpoch);

  final controller = AuthController(authProvider: fakeAuth, storage: storage);
  await Future<void>.delayed(const Duration(milliseconds: 100));

  // signOut 内部会调 AnalyticsService，mock channel 捕获
  await controller.signOut();

  // 验证不抛异常即可（channel mock 在 setUpAll 配置后捕获事件）
  expect(controller.isAuthenticated, isFalse);
});
```

- [ ] **Step 3: 运行测试验证通过**（现有 API 已支持，新增事件不影响）

Run: `flutter test test/unit/auth_controller_test.dart`
Expected: PASS

- [ ] **Step 4: 在 auth_controller.dart 中补埋事件**

在 `_authSub.listen` 回调内增加状态翻转检测：

```dart
// _authSub.listen 回调改造
bool _wasAuthenticated = false;

_authSub = _authProvider.authStateChanges().listen(
  (authUser) {
    final isAuth = authUser != null;
    final source = _wasAuthenticated == isAuth
        ? null  // 状态未翻转，不上报
        : (authUser != null ? 'provider' : 'provider');

    _user = authUser == null ? null : _toAppUser(authUser);
    if (authUser == null) {
      _clearCachedUser();
    }
    notifyListeners();

    // 状态翻转上报
    if (source != null && _wasAuthenticated != isAuth) {
      _wasAuthenticated = isAuth;
      final state = isAuth ? 'signed_in' : 'signed_out';
      AnalyticsService.instance.track(
        'auth_session_state_changed',
        params: {'state': state, 'source': source},
      );
      AnalyticsService.instance.setUserId(isAuth ? authUser!.uid : null);
      if (isAuth) {
        AnalyticsService.instance.setUserProperty('is_anonymous', 'false');
      } else {
        AnalyticsService.instance.setUserProperty('is_anonymous', 'true');
        AnalyticsService.instance.resetUserProperties();
      }
    }
  },
  onError: (Object e) {
    Log.w('AuthController: authStateChanges 监听失败: $e');
  },
);
```

在 `signInWithGoogle` 成功分支后，标记 `_wasAuthenticated = true` 并上报来源为 `explicit`。

在 `signOut` 内补埋：

```dart
Future<void> signOut() async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    await _authProvider.signOut();
    _clearCachedUser();
    await AnalyticsService.instance.track(
      'auth_sign_out_result',
      params: {'result': 'success'},
    );
  } catch (e) {
    _errorMessage = '退出登录失败，请重试';
    Log.e('退出登录失败', error: e);
    await AnalyticsService.instance.track(
      'auth_sign_out_result',
      params: {'result': 'failed', 'error_type': e.runtimeType.toString()},
    );
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

- [ ] **Step 5: 在 _init 初始化时设置 is_anonymous**

```dart
// _init() 开头
void _init() {
  AnalyticsService.instance.setUserProperty('is_anonymous', 'true');
  // ... 原有逻辑
}
```

- [ ] **Step 6: 运行测试验证**

Run: `flutter test test/unit/auth_controller_test.dart`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add lib/features/auth/presentation/controllers/auth_controller.dart test/unit/auth_controller_test.dart
git commit -m "feat(analytics): auth session state, sign_out, user properties"
```

---

## Task 7: 删除 TaskController 遗留旧接口

**Files:**
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`
- Delete: `test/unit/downloader_controller_add_task_test.dart`（仅测试 `DownloaderController.addTask`，已在 Task 8 删除）

- [ ] **Step 1: 读取 task_controller.dart 全文确认待删行号**

用 Read 工具读取 `lib/features/tasks/presentation/controllers/task_controller.dart`，确认：
- 删除 `pauseTask` / `resumeTask` / `removeTask` / `addDownload`（旧接口，约 399-467 行）
- 删除 `loadTasks` / `loadTaskDetail`（旧接口，约 333-384 行）
- 删除 `searchTasks`（约 470 行）
- 删除 `_tasks` / `_isLoading` 兼容字段及 getters（约 36-37, 100-101 行）
- 删除 `setCurrentDownloaderId`（setter）和 `currentDownloaderId`（getter），约 102-109 行
- **保留** `_currentDownloaderId` 私有字段（`clearCurrentTaskForDetail` 仍用）

- [ ] **Step 2: 删除旧接口方法**

精确删除以下方法（保留文件其余部分）：

```dart
// 删除以下方法整块：
// - Future<void> loadTasks(String downloaderId, DownloaderController) （旧）
// - Future<void> loadTaskDetail(String taskId, DownloaderController) （旧）
// - Future<void> pauseTask(String taskId, DownloaderController) （旧）
// - Future<void> resumeTask(String taskId, DownloaderController) （旧）
// - Future<void> removeTask(String taskId, DownloaderController, {bool deleteFiles}) （旧）
// - Future<bool> addDownload(String url, DownloaderController, {String? savePath}) （旧）
// - List<DownloadTask> searchTasks(String query)

// 删除以下字段和 getter：
// - List<DownloadTask> _tasks = [];
// - bool _isLoading = false;
// - List<DownloadTask> get tasks => ...
// - bool get isLoading => ...
// - String get currentDownloaderId => _currentDownloaderId;
// - void setCurrentDownloaderId(String downloaderId) {...}
```

**注意**：`clearCurrentTaskForDetail` 内引用 `_currentDownloaderId`，字段保留。

- [ ] **Step 3: 删除依赖旧接口的测试文件**

```bash
rm test/unit/downloader_controller_add_task_test.dart
```

- [ ] **Step 4: 验证编译**

Run: `flutter analyze lib/features/tasks/presentation/controllers/task_controller.dart`
Expected: 无错误，无对已删方法的引用

- [ ] **Step 5: 运行全量测试验证无回归**

Run: `flutter test`
Expected: 全部 PASS（如有测试引用了 `tasks`/`isLoading`/`setCurrentDownloaderId`/`searchTasks`，相应修正）

- [ ] **Step 6: 提交**

```bash
git add lib/features/tasks/presentation/controllers/task_controller.dart test/unit/downloader_controller_add_task_test.dart
git commit -m "refactor(tasks): remove legacy TaskController methods (dead code)"
```

---

## Task 8: 删除 DownloaderController 遗留旧接口

**Files:**
- Modify: `lib/features/downloaders/presentation/controllers/downloader_controller.dart`

- [ ] **Step 1: 确认待删方法**

读取 `downloader_controller.dart`，删除：
- `addDownload(String downloaderId, String url, {String? savePath})`（约 238-246 行）
- `addTask(AddTaskRequest request)`（约 208-234 行）

**保留**：`testConnection`、`_createService`、`addDownloader`、`updateDownloader`、`removeDownloader`、`refreshStatus` 等。

- [ ] **Step 2: 删除方法**

精确删除 `addTask` 和 `addDownload` 两个方法块。

- [ ] **Step 3: 验证编译 + 测试**

Run: `flutter analyze lib/features/downloaders/presentation/controllers/downloader_controller.dart && flutter test`
Expected: 无错误，全部 PASS

- [ ] **Step 4: 提交**

```bash
git add lib/features/downloaders/presentation/controllers/downloader_controller.dart
git commit -m "refactor(downloaders): remove legacy addTask/addDownload (dead code)"
```

---

## Task 9: 下载器模块埋点

**Files:**
- Modify: `lib/features/downloaders/presentation/controllers/downloader_controller.dart`

- [ ] **Step 1: 在 addDownloader 内补埋 downloader_add_result**

```dart
Future<ConnectionResult> addDownloader(Downloader downloader) async {
  final result = await testConnection(downloader);
  if (result is ConnectionSuccess) {
    _downloaders.add(
      downloader.copyWith(
        status: DownloaderStatus.online,
        version: result.serverVersion,
      ),
    );
    await _saveDownloaders();
    _notifySafely();

    await AnalyticsService.instance.track(
      'downloader_add_result',
      params: <String, Object>{
        'result': 'success',
        'type': downloader.type.name,
        'use_https': downloader.useHttps,
      },
    );
    await _syncDownloaderUserProperties();
  } else {
    final category = result is ConnectionFailure
        ? _failureCategoryName(result.category)
        : 'unknown';
    await AnalyticsService.instance.track(
      'downloader_add_result',
      params: <String, Object>{
        'result': 'failed',
        'type': downloader.type.name,
        'failure_category': category,
        'use_https': downloader.useHttps,
      },
    );
  }
  return result;
}

String _failureCategoryName(ConnectionFailureCategory c) {
  switch (c) {
    case ConnectionFailureCategory.versionUnsupported: return 'version_unsupported';
    case ConnectionFailureCategory.authFailed: return 'auth';
    case ConnectionFailureCategory.networkError: return 'network';
    case ConnectionFailureCategory.unknown: return 'unknown';
  }
}
```

- [ ] **Step 2: 在 updateDownloader 内补埋 downloader_update_result**

同 `addDownloader` 模式，在成功/失败分支分别上报。

- [ ] **Step 3: 在 removeDownloader 内补埋 downloader_remove**

```dart
Future<void> removeDownloader(String id) async {
  final downloader = getDownloader(id);
  final type = downloader?.type.name ?? 'unknown';

  _downloaders.removeWhere((d) => d.id == id);
  _statusFailureCount.remove(id);
  await _saveDownloaders();
  _notifySafely();

  await AnalyticsService.instance.track(
    'downloader_remove',
    params: <String, Object>{'type': type},
  );
  await _syncDownloaderUserProperties();
}
```

- [ ] **Step 4: 在 refreshStatus 内补埋 downloader_status_changed（仅翻转）**

```dart
// 在 refreshStatus 内，状态从其他→online 或 online→off 翻转时：
final previousStatus = downloader.status;
// ... 获取新状态后
if (newStatus != previousStatus) {
  final transition = newStatus == DownloaderStatus.online
      ? 'offline_to_online'
      : 'online_to_offline';
  await AnalyticsService.instance.track(
    'downloader_status_changed',
    params: <String, Object>{
      'type': downloader.type.name,
      'transition': transition,
      'consecutive_failures': _statusFailureCount[id] ?? 0,
    },
  );
}
```

- [ ] **Step 5: 新增 _syncDownloaderUserProperties 方法**

```dart
Future<void> _syncDownloaderUserProperties() async {
  final count = _downloaders.length;
  final types = _downloaders.map((d) => d.type.name).toSet();
  final typeLabel = count == 0
      ? 'none'
      : types.length == 1
          ? types.first
          : 'multiple';
  final hasOnline = _downloaders.any((d) => d.status == DownloaderStatus.online);

  await AnalyticsService.instance.setUserProperty('downloader_count', count.toString());
  await AnalyticsService.instance.setUserProperty('downloader_types', typeLabel);
  await AnalyticsService.instance.setUserProperty('has_online_downloader', hasOnline.toString());
}
```

- [ ] **Step 6: 在 init() 末尾调用一次 _syncDownloaderUserProperties**

```dart
void init() {
  _loadDownloaders();
  Future.delayed(const Duration(milliseconds: 500), () {
    refreshAllStatus();
    refreshGlobalStats();
    _startPeriodicRefresh();
    _syncDownloaderUserProperties();  // 新增
  });
}
```

- [ ] **Step 7: 验证编译 + 测试**

Run: `flutter analyze lib/features/downloaders/presentation/controllers/downloader_controller.dart && flutter test test/unit/downloader_controller_gate_test.dart`
Expected: 无错误，PASS

- [ ] **Step 8: 提交**

```bash
git add lib/features/downloaders/presentation/controllers/downloader_controller.dart
git commit -m "feat(analytics): downloader add/update/remove/status events"
```

---

## Task 10: 任务模块埋点（controller 层）

**Files:**
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`

- [ ] **Step 1: 在 addTask 内补埋 task_add_result**

```dart
Future<bool> addTask(
  AddTaskRequest request,
  DownloaderController downloaderController,
) async {
  final downloader = downloaderController.getDownloader(request.downloaderId);
  if (downloader == null) return false;

  final service = _createService(downloader);
  final source = request.hasTorrentSource
      ? 'torrent'
      : request.hasUrlSource
          ? 'url'
          : 'unknown';

  try {
    final result = await service.addTask(request);
    if (result.isEmpty) {
      await AnalyticsService.instance.track(
        'task_add_result',
        params: <String, Object>{
          'result': 'failed',
          'source': source,
          'downloader_type': downloader.type.name,
          'has_save_path': request.savePath != null,
        },
      );
      return false;
    }

    await loadTasksForDownloader(request.downloaderId, downloaderController,
        force: true);

    await AnalyticsService.instance.track(
      'task_add_result',
      params: <String, Object>{
        'result': 'success',
        'source': source,
        'downloader_type': downloader.type.name,
        'has_save_path': request.savePath != null,
      },
    );
    return true;
  } catch (e) {
    _setError(e);
    await AnalyticsService.instance.track(
      'task_add_result',
      params: <String, Object>{
        'result': 'failed',
        'source': source,
        'downloader_type': downloader.type.name,
        'has_save_path': request.savePath != null,
        'error_type': e.runtimeType.toString(),
      },
    );
    return false;
  }
}
```

- [ ] **Step 2: 在 pause/resume/removeTaskForDownloader 内补埋 task_action_result**

以 `pauseTaskForDownloader` 为例：

```dart
Future<void> pauseTaskForDownloader(
  String taskId,
  String downloaderId,
  DownloaderController downloaderController,
) async {
  final downloader = downloaderController.getDownloader(downloaderId);
  if (downloader == null) return;

  final service = _createService(downloader);

  try {
    await service.pauseTask(taskId);
    await loadTasksForDownloader(downloaderId, downloaderController, force: true);
    await AnalyticsService.instance.track(
      'task_action_result',
      params: <String, Object>{
        'action': 'pause',
        'result': 'success',
        'downloader_type': downloader.type.name,
      },
    );
  } catch (e) {
    _setError(e);
    await AnalyticsService.instance.track(
      'task_action_result',
      params: <String, Object>{
        'action': 'pause',
        'result': 'failed',
        'downloader_type': downloader.type.name,
        'error_type': e.runtimeType.toString(),
      },
    );
  }
}
```

`resumeTaskForDownloader` 同理（action: 'resume'）。

`removeTaskForDownloader` 增补 `delete_files`：

```dart
await AnalyticsService.instance.track(
  'task_action_result',
  params: <String, Object>{
    'action': 'remove',
    'result': 'success',
    'downloader_type': downloader.type.name,
    'delete_files': deleteFiles,
  },
);
```

- [ ] **Step 3: 在 refreshGlobalStats 末尾同步 has_active_task user_property**

在 `DownloaderController.refreshGlobalStats` 末尾（或 TaskController 适当位置）补：

```dart
// 在 refreshGlobalStats 末尾
final hasActive = downloading > 0 || waiting > 0;
await AnalyticsService.instance.setUserProperty('has_active_task', hasActive.toString());
```

注意：`refreshGlobalStats` 在 `DownloaderController` 内，`downloading`/`waiting` 是局部变量。直接在该方法末尾加上述代码。

- [ ] **Step 4: 验证编译 + 测试**

Run: `flutter analyze lib/features/tasks/ lib/features/downloaders/ && flutter test`
Expected: 无错误，PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/tasks/presentation/controllers/task_controller.dart lib/features/downloaders/presentation/controllers/downloader_controller.dart
git commit -m "feat(analytics): task add/action events + has_active_task property"
```

---

## Task 11: 任务页面浏览埋点

**Files:**
- Modify: `lib/features/tasks/presentation/pages/tasks_page.dart`
- Modify: `lib/features/tasks/presentation/pages/task_detail_page.dart`

- [ ] **Step 1: 在 TasksPage.initState postFrame 内补埋 task_list_viewed**

```dart
// _TasksPageState.initState
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadTasks();
    _trackTaskListViewed();
    final downloaderController = context.read<DownloaderController>();
    context.read<TaskController>().startAutoRefresh(downloaderController);
  });
}

Future<void> _trackTaskListViewed() async {
  final id = widget.downloaderId;
  if (id == null || id.isEmpty) return;
  final controller = context.read<TaskController>();
  final downloaderController = context.read<DownloaderController>();
  final downloader = downloaderController.getDownloader(id);
  if (downloader == null) return;

  final tasks = controller.tasksForDownloader(id);
  final activeCount = tasks.where((t) =>
    t.status == TaskStatus.downloading || t.status == TaskStatus.waiting).length;

  await AnalyticsService.instance.track(
    'task_list_viewed',
    params: <String, Object>{
      'downloader_type': downloader.type.name,
      'task_count': tasks.length,
      'active_count': activeCount,
    },
  );
}
```

- [ ] **Step 2: 在 TaskDetailPage.initState postFrame 内补埋 task_detail_viewed**

```dart
// _TaskDetailPageState.initState
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadDetail();
    _trackTaskDetailViewed();
  });
  _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadDetail());
}

Future<void> _trackTaskDetailViewed() async {
  final downloader = context.read<DownloaderController>().getDownloader(widget.downloaderId);
  if (downloader == null) return;

  final task = context.read<TaskController>().currentTask;
  final status = (task != null && task.id == widget.taskId)
      ? task.status.name
      : 'unknown';

  await AnalyticsService.instance.track(
    'task_detail_viewed',
    params: <String, Object>{
      'downloader_type': downloader.type.name,
      'task_status': status,
    },
  );
}
```

- [ ] **Step 3: 验证编译 + widget 测试**

Run: `flutter analyze lib/features/tasks/presentation/pages/ && flutter test test/widget/`
Expected: 无错误，PASS

- [ ] **Step 4: 提交**

```bash
git add lib/features/tasks/presentation/pages/tasks_page.dart lib/features/tasks/presentation/pages/task_detail_page.dart
git commit -m "feat(analytics): task list/detail viewed events"
```

---

## Task 12: 更新模块埋点

**Files:**
- Modify: `lib/features/update/presentation/controllers/update_controller.dart`

- [ ] **Step 1: 在 runSilentCheck 内补埋 update_check_result**

```dart
Future<void> runSilentCheck({DateTime? now}) async {
  _isChecking = true;
  notifyListeners();
  _lastResult = await _service.checkForUpdate();
  _isChecking = false;
  _recomputeDecision(now: now);

  await AnalyticsService.instance.track(
    'update_check_result',
    params: <String, Object>{
      'result': _lastResult.status.name,
      'source': 'silent',
      if (_lastResult.availableVersionCode != null)
        'available_version_code': _lastResult.availableVersionCode!,
    },
  );
}
```

- [ ] **Step 2: 在 checkForUpdatesManually 内补埋（source: manual）**

```dart
Future<void> checkForUpdatesManually() async {
  _lastResult = await _service.checkForUpdate();
  _recomputeDecision();

  await AnalyticsService.instance.track(
    'update_check_result',
    params: <String, Object>{
      'result': _lastResult.status.name,
      'source': 'manual',
      if (_lastResult.availableVersionCode != null)
        'available_version_code': _lastResult.availableVersionCode!,
    },
  );
}
```

- [ ] **Step 3: 在 openStorePage 内补埋 update_prompt_response(accepted)**

```dart
Future<void> openStorePage() async {
  await _service.openStorePage();
  _recordPromptAccepted(DateTime.now());

  await AnalyticsService.instance.track(
    'update_prompt_response',
    params: <String, Object>{
      'response': 'accepted',
      if (_lastResult.availableVersionCode != null)
        'available_version_code': _lastResult.availableVersionCode!,
    },
  );
}
```

- [ ] **Step 4: 在 dismissCurrentVersion 内补埋 update_prompt_response(dismissed)**

```dart
void dismissCurrentVersion({DateTime? now}) {
  final versionCode = _lastResult.availableVersionCode;
  if (versionCode != null) {
    _storage.write(_dismissedVersionCodeKey, versionCode);
  }
  _recordPromptShown(now ?? DateTime.now());
  _dialogConsumedInSession = true;
  _recomputeDecision(now: now);

  AnalyticsService.instance.track(
    'update_prompt_response',
    params: <String, Object>{
      'response': 'dismissed',
      if (versionCode != null) 'available_version_code': versionCode,
    },
  );
}
```

- [ ] **Step 5: 验证编译 + 测试**

Run: `flutter analyze lib/features/update/ && flutter test test/unit/features/update/`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/features/update/presentation/controllers/update_controller.dart
git commit -m "feat(analytics): update check result + prompt response events"
```

---

## Task 13: 评价模块埋点

**Files:**
- Modify: `lib/core/utils/review_manager.dart`

- [ ] **Step 1: 在 _maybeRequestReview 通过冷却检查后补埋 review_prompt_shown**

`_maybeRequestReview` 改为接受 `trigger` 参数：

```dart
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
```

- [ ] **Step 2: 在 requestReview 内补埋 review_prompt_result**

```dart
Future<void> requestReview({required String trigger}) async {
  try {
    await _requestReview();
    await _storage.write(_lastReviewKey, _now().millisecondsSinceEpoch);
    Log.i('In-App Review 请求已发起');

    await AnalyticsService.instance.track(
      'review_prompt_result',
      params: <String, Object>{
        'result': 'completed',
        'trigger': trigger,
      },
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
```

- [ ] **Step 3: 更新四个触发方法传入 trigger**

```dart
// recordFirstDownloaderAddedAndMaybeRequestReview
await _maybeRequestReview(trigger: 'first_downloader');

// recordSuccessfulTaskAddAndMaybeRequestReview
final requested = await _maybeRequestReview(trigger: 'successful_task_add');

// recordCompletedTaskSeenAndMaybeRequestReview
await _maybeRequestReview(trigger: 'completed_task');

// recordHealthyUsageDayAndMaybeRequestReview
await _maybeRequestReview(trigger: 'healthy_usage');
```

- [ ] **Step 4: 验证编译 + 测试**

Run: `flutter analyze lib/core/utils/review_manager.dart && flutter test test/unit/review_manager_test.dart`
Expected: PASS（`requestReview` 签名变化，测试需相应更新 mock）

- [ ] **Step 5: 更新 review_manager_test.dart 适配新签名**

如果测试直接调用 `requestReview()`，改为 `requestReview(trigger: 'test')`。

- [ ] **Step 6: 提交**

```bash
git add lib/core/utils/review_manager.dart test/unit/review_manager_test.dart
git commit -m "feat(analytics): review prompt shown + result events"
```

---

## Task 14: 设置模块埋点

**Files:**
- Modify: `lib/features/settings/presentation/controllers/settings_controller.dart`

- [ ] **Step 1: 在 setAppThemeMode 内补埋 settings_theme_mode_changed**

```dart
void setAppThemeMode(AppThemeMode value) {
  final from = _appThemeMode;
  _appThemeMode = value;
  _storage.write('appThemeMode', value.code);
  unawaited(NativeThemeModeSync.sync(value.code));
  notifyListeners();

  if (from != value) {
    AnalyticsService.instance.track(
      'settings_theme_mode_changed',
      params: <String, Object>{'from': from.code, 'to': value.code},
    );
    AnalyticsService.instance.setUserProperty('theme_mode', value.code);
  }
}
```

- [ ] **Step 2: 在 setAppLocale 内补埋 settings_language_changed**

```dart
void setAppLocale(AppLocale value) {
  final from = _appLocale;
  _appLocale = value;
  _storage.write('appLocale', value.code);
  notifyListeners();

  if (from != value) {
    AnalyticsService.instance.track(
      'settings_language_changed',
      params: <String, Object>{'from': from.code, 'to': value.code},
    );
    AnalyticsService.instance.setUserProperty('app_locale', value.code);
  }
}
```

- [ ] **Step 3: 在 _loadSettings 末尾初始化 user_property**

```dart
void _loadSettings() {
  _appLocale = AppLocale.fromCode(_storage.read('appLocale'));
  _appThemeMode = AppThemeMode.fromCode(_storage.read('appThemeMode'));
  unawaited(NativeThemeModeSync.sync(_appThemeMode.code));
  notifyListeners();

  // 初始化 user_property（App 启动时同步当前状态）
  AnalyticsService.instance.setUserProperty('theme_mode', _appThemeMode.code);
  AnalyticsService.instance.setUserProperty('app_locale', _appLocale.code);
}
```

- [ ] **Step 4: 验证编译 + 测试**

Run: `flutter analyze lib/features/settings/ && flutter test test/widget/settings_page_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/settings/presentation/controllers/settings_controller.dart
git commit -m "feat(analytics): settings theme/language change events"
```

---

## Task 15: 全量验证 + 文档更新

- [ ] **Step 1: 全量 analyze**

Run: `flutter analyze`
Expected: 无错误

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: 全部 PASS

- [ ] **Step 3: 验证隐私护栏无敏感字段泄漏**

在 `analytics_service_test.dart` 中确保已有「host/url/port 等被截断」的测试用例覆盖。如 Task 3 已包含，跳过。

- [ ] **Step 4: 更新 AGENTS.md（可选）**

在 `AGENTS.md` 的 WHERE TO LOOK 表中增加一行：

```
| 埋点 | `lib/services/analytics_service.dart` | 统一入口，隐私护栏 |
```

- [ ] **Step 5: 最终提交**

```bash
git add AGENTS.md
git commit -m "docs: add analytics service to AGENTS.md"
```

---

## 自审检查

**Spec 覆盖核对：**

| Spec 章节 | 对应 Task | 覆盖 |
|-----------|----------|------|
| §3 架构 + 隐私护栏 + env params | Task 1, 2, 3 | ✓ |
| §3.2 重构 AuthTelemetryService | Task 4 | ✓ |
| §4 启动埋点（3 事件） | Task 5 | ✓ |
| §5 认证（session_state, sign_out, user_property） | Task 6 | ✓ |
| §6 下载器（4 事件 + user_property） | Task 9 | ✓ |
| §7.1 任务模块前置清理 | Task 7, 8 | ✓ |
| §7.2 任务埋点（4 事件 + user_property） | Task 10, 11 | ✓ |
| §8 更新（2 事件） | Task 12 | ✓ |
| §9 评价（2 事件） | Task 13 | ✓ |
| §10 设置（2 事件 + user_property） | Task 14 | ✓ |
| §11 user_property 全表 | Task 3, 6, 9, 10, 14 | ✓ |
| §13 测试策略 | 各 Task 内嵌 | ✓ |

**全部 20 个自定义事件 + 9 个 user_property 均有对应 Task。无 spec 遗漏。**
