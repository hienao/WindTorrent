# 下载器 API 版本检查（添加时硬门禁）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在添加 / 编辑下载器时对 Aria2、qBittorrent、Transmission 执行服务端版本硬门禁，并把获取到的版本号记录到模型、显示在管理页卡片上。

**Architecture:** 新增 `ConnectionResult`（Dart 3 sealed）让 `testConnection()` 由 `bool` 升级为"成功 / 失败 + 类别 + 原因"；三个 service 各自在 `testConnection()` 内自治完成版本校验并回传 `serverVersion`；`DownloaderController.addDownloader/updateDownloader` 据此实现硬门禁（失败不保存）并写入 `Downloader.version`；编辑页据结果决定是否 `pop` 并 SnackBar 反馈；管理页卡片新增版本 pill 徽章。

**Tech Stack:** Flutter、Dart 3（sealed class）、Provider + ChangeNotifier、http + `http/testing.dart`（MockClient）、GetStorage、go_router。

参考设计：`docs/superpowers/specs/2026-06-13-downloader-api-version-check-design.md`

---

## File Structure

| 文件 | 职责 | 改动类型 |
|---|---|---|
| `lib/services/connection_result.dart` | `ConnectionResult` sealed 值对象（`ConnectionSuccess` / `ConnectionFailure`） | 新增 |
| `lib/models/downloader.dart` | 下载器模型，新增 `version` 字段 | 修改 |
| `lib/services/base_downloader_service.dart` | 抽象基类，`testConnection()` 返回类型改 `ConnectionResult` | 修改 |
| `lib/services/aria2_service.dart` | Aria2 testConnection：解析 `getVersion.version` 校验 ≥1.36 | 修改 |
| `lib/services/qbit_service.dart` | qBit testConnection：改用 `app/version` 判 ≥5.0，不再 throw | 修改 |
| `lib/services/transmission_service.dart` | Trans testConnection：读 `rpc-version-semver` 判 ≥6.0.0 | 修改 |
| `lib/services/downloader_connection_exception.dart` | qBit 不再 throw 后已无引用 | 删除 |
| `lib/features/downloaders/presentation/controllers/downloader_controller.dart` | 适配 `ConnectionResult`、实现硬门禁、写入 version | 修改 |
| `lib/features/downloaders/presentation/pages/downloader_editor_page.dart` | `_save` 据结果 `pop` + SnackBar | 修改 |
| `lib/features/home/presentation/pages/management_tab.dart` | 卡片新增 `_VersionBadge` | 修改 |
| `test/unit/connection_result_test.dart` | ConnectionResult 单测 | 新增 |
| `test/unit/downloader_services_test_connection_test.dart` | 三 service testConnection 版本检查单测 | 新增 |
| `test/unit/downloader_controller_gate_test.dart` | controller 门禁单测 | 新增 |
| `test/widget/downloader_editor_gate_test.dart` | 编辑页门禁 widget 测试 | 新增 |
| `test/widget/management_tab_version_badge_test.dart` | 管理页版本徽章 widget 测试 | 新增 |
| `test/unit/models_test.dart` / `test/widget/test_helpers.dart` | 既有测试适配新签名 | 修改 |

> **关于 breaking change 的 TDD 说明：** `testConnection()` 签名由 `bool` 改为 `ConnectionResult` 是编译期 breaking change——Dart 整包编译，调用方（controller / editor / fake）未同步修改时整包无法编译，孤立的单测也跑不起来。因此 **Task 3 内的"写测试"步骤此时会因编译失败而红，属正常**；需把 Task 3 内所有实现步骤改完，才能在末尾一次性跑绿。Task 1、2、4 相互独立、可严格 TDD。

---

## Task 1: ConnectionResult 值对象

**Files:**
- Create: `lib/services/connection_result.dart`
- Test: `test/unit/connection_result_test.dart`

- [ ] **Step 1: 写失败测试**

Create `test/unit/connection_result_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/services/connection_result.dart';

void main() {
  group('ConnectionSuccess', () {
    test('isSuccess 为 true，携带 serverVersion', () {
      const result = ConnectionSuccess(serverVersion: '1.36.0');
      expect(result.isSuccess, isTrue);
      expect(result.serverVersion, '1.36.0');
    });

    test('serverVersion 可为 null', () {
      const result = ConnectionSuccess();
      expect(result.isSuccess, isTrue);
      expect(result.serverVersion, isNull);
    });
  });

  group('ConnectionFailure', () {
    test('versionUnsupported 携带实际与最低版本', () {
      const result = ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        '版本过低',
        actualVersion: '1.35.0',
        minVersion: '1.36',
      );
      expect(result.isSuccess, isFalse);
      expect(result.category, ConnectionFailureCategory.versionUnsupported);
      expect(result.isVersionUnsupported, isTrue);
      expect(result.actualVersion, '1.35.0');
      expect(result.minVersion, '1.36');
    });

    test('非版本失败时 isVersionUnsupported 为 false', () {
      const result = ConnectionFailure(
        ConnectionFailureCategory.authFailed,
        '认证失败',
      );
      expect(result.isVersionUnsupported, isFalse);
      expect(result.actualVersion, isNull);
      expect(result.minVersion, isNull);
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/connection_result_test.dart`
Expected: FAIL — `connection_result.dart` 不存在 / 找不到 `ConnectionResult` 等符号。

- [ ] **Step 3: 实现 ConnectionResult**

Create `lib/services/connection_result.dart`:

```dart
/// 下载器连接 / 版本校验结果。
///
/// 让 `testConnection()` 从 `bool` 升级为"成功 / 失败 + 类别 + 原因"，
/// 使"版本不符"能与"认证失败 / 无法连接"区分开。
sealed class ConnectionResult {
  const ConnectionResult();

  /// 是否连接成功（含版本达标）。
  bool get isSuccess => false;
}

/// 连接成功且版本达标。
///
/// [serverVersion] 为服务端实际版本字符串，供 controller 写入
/// `Downloader.version`。
class ConnectionSuccess extends ConnectionResult {
  const ConnectionSuccess({this.serverVersion});

  final String? serverVersion;

  @override
  bool get isSuccess => true;
}

/// 连接失败的类别。
enum ConnectionFailureCategory {
  /// 服务端版本低于最低要求。
  versionUnsupported,

  /// 认证失败（用户名 / 密码 / RPC secret 错误）。
  authFailed,

  /// 网络 / 超时 / 不可达。
  networkError,

  /// 其他未分类错误。
  unknown,
}

/// 连接失败，携带类别与人类可读原因。
class ConnectionFailure extends ConnectionResult {
  final ConnectionFailureCategory category;
  final String reason;

  /// 服务端实际版本（仅 [ConnectionFailureCategory.versionUnsupported]）。
  final String? actualVersion;

  /// 要求的最低版本（仅 [ConnectionFailureCategory.versionUnsupported]）。
  final String? minVersion;

  const ConnectionFailure(
    this.category,
    this.reason, {
    this.actualVersion,
    this.minVersion,
  });

  /// 是否为版本不符。
  bool get isVersionUnsupported =>
      category == ConnectionFailureCategory.versionUnsupported;
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/connection_result_test.dart`
Expected: PASS（全部 4 个测试）。

- [ ] **Step 5: Commit**

```bash
git add lib/services/connection_result.dart test/unit/connection_result_test.dart
git commit -m "feat: 新增 ConnectionResult 连接结果对象"
```

---

## Task 2: Downloader.version 字段

**Files:**
- Modify: `lib/models/downloader.dart`
- Test: `test/unit/downloader_version_test.dart`

- [ ] **Step 1: 写失败测试**

Create `test/unit/downloader_version_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';

void main() {
  group('Downloader.version', () {
    test('默认为 null', () {
      final d = Downloader(
        id: 'x', name: 'n', type: DownloaderType.aria2,
        host: 'h', port: 6800,
      );
      expect(d.version, isNull);
    });

    test('toJson / fromJson 往返保留 version', () {
      final d = Downloader(
        id: 'x', name: 'n', type: DownloaderType.aria2,
        host: 'h', port: 6800, version: '1.36.0',
      );
      final restored = Downloader.fromJson(d.toJson());
      expect(restored.version, '1.36.0');
    });

    test('旧 JSON 无 version 字段时反序列化为 null', () {
      final legacy = <String, dynamic>{
        'id': 'x', 'name': 'n', 'type': 'aria2', 'host': 'h', 'port': 6800,
      };
      expect(Downloader.fromJson(legacy).version, isNull);
    });

    test('copyWith 更新 version', () {
      final d = Downloader(
        id: 'x', name: 'n', type: DownloaderType.aria2,
        host: 'h', port: 6800,
      );
      expect(d.copyWith(version: '5.0.0').version, '5.0.0');
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/downloader_version_test.dart`
Expected: FAIL — `version` 字段不存在。

- [ ] **Step 3: 实现 version 字段**

Modify `lib/models/downloader.dart`。

在 `taskStats` 字段后新增（约第 18 行后）:

```dart
  final String? version; // 服务端版本号（添加/编辑时获取）
```

在构造函数参数末尾（`this.taskStats = const {},` 之后）新增:

```dart
    this.version,
```

在 `fromJson` 的 `return Downloader(` 块内末尾（`useHttps: json['useHttps'] ?? false,` 之后）新增:

```dart
      version: json['version'] as String?,
```

在 `toJson` 的 map 内末尾（`'useHttps': useHttps,` 之后）新增:

```dart
        'version': version,
```

在 `copyWith` 参数列表末尾（`Map<String, int>? taskStats,` 之后）新增 `String? version,`；在 `copyWith` 的 `return Downloader(` 块内末尾（`taskStats: taskStats ?? this.taskStats,` 之后）新增:

```dart
      version: version ?? this.version,
```

> 注意：`copyWith` 使用 `version ?? this.version` 语义——传 `null` 表示"不改"。若需显式清空 version，因当前无此需求，保持该惯用法。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/downloader_version_test.dart`
Expected: PASS（全部 4 个测试）。

- [ ] **Step 5: 跑全量测试确认未破坏既有**

Run: `flutter test`
Expected: PASS（Task 2 是纯新增字段，向后兼容）。

- [ ] **Step 6: Commit**

```bash
git add lib/models/downloader.dart test/unit/downloader_version_test.dart
git commit -m "feat: Downloader 模型新增 version 字段"
```

---

## Task 3: 全链路签名适配 + 版本检查 + 硬门禁 + UI 反馈

> 这是 breaking change 的核心任务。完成本任务内**所有实现步骤**后，整包才能编译；测试在 Step 13 一次性跑绿。先写测试（此时编译失败属正常），再依次实现。

**Files:**
- Modify: `lib/services/base_downloader_service.dart`
- Modify: `lib/services/aria2_service.dart`
- Modify: `lib/services/qbit_service.dart`
- Modify: `lib/services/transmission_service.dart`
- Delete: `lib/services/downloader_connection_exception.dart`
- Modify: `lib/features/downloaders/presentation/controllers/downloader_controller.dart`
- Modify: `lib/features/downloaders/presentation/pages/downloader_editor_page.dart`
- Modify: `test/widget/test_helpers.dart`
- Test: `test/unit/downloader_services_test_connection_test.dart`
- Test: `test/unit/downloader_controller_gate_test.dart`
- Test: `test/widget/downloader_editor_gate_test.dart`

- [ ] **Step 1: 写 service 版本检查测试**

Create `test/unit/downloader_services_test_connection_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/qbit_service.dart';
import 'package:windwalker/services/transmission_service.dart';

void main() {
  group('Aria2Service.testConnection 版本检查', () {
    Downloader aria2() => Downloader(
      id: 'a', name: 'a', type: DownloaderType.aria2,
      host: 'h', port: 6800, secret: 's',
    );

    test('版本达标返回 success 且携带 serverVersion', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({
          'id': 1, 'jsonrpc': '2.0',
          'result': {'version': '1.36.0', 'enabledFeatures': []},
        }), 200,
      ));
      final result = await Aria2Service(aria2(), client: client).testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '1.36.0');
    });

    test('版本过低返回 versionUnsupported', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({
          'id': 1, 'jsonrpc': '2.0',
          'result': {'version': '1.35.0', 'enabledFeatures': []},
        }), 200,
      ));
      final result = await Aria2Service(aria2(), client: client).testConnection();
      expect(result, isA<ConnectionFailure>());
      final f = result as ConnectionFailure;
      expect(f.isVersionUnsupported, isTrue);
      expect(f.actualVersion, '1.35.0');
      expect(f.minVersion, '1.36');
    });

    test('secret 错误(200 + error)返回 authFailed', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({
          'id': 1, 'jsonrpc': '2.0',
          'error': {'code': 1, 'message': 'Unauthorized'},
        }), 200,
      ));
      final result = await Aria2Service(aria2(), client: client).testConnection();
      expect((result as ConnectionFailure).category,
          ConnectionFailureCategory.authFailed);
    });
  });

  group('QBitService.testConnection 版本检查', () {
    Downloader qbit() => Downloader(
      id: 'q', name: 'q', type: DownloaderType.qbittorrent,
      host: 'h', port: 8080, username: 'u', password: 'p',
    );

    // 登录成功 + 给定 app/version 响应的 MockClient
    http.Client qbitClient({required String appVersionBody}) {
      return MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/api/v2/auth/login')) {
          return http.Response('Ok.', 200,
              headers: {'set-cookie': 'SID=abc; Path=/'});
        }
        if (path.endsWith('/api/v2/app/version')) {
          return http.Response(appVersionBody, 200);
        }
        return http.Response('', 404);
      });
    }

    test('5.0+ 达标返回 success 携带 serverVersion', () async {
      final result = await QBitService(qbit(),
          client: qbitClient(appVersionBody: 'v5.0.0')).testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '5.0.0');
    });

    test('4.x 旧版返回 versionUnsupported', () async {
      final result = await QBitService(qbit(),
          client: qbitClient(appVersionBody: 'v4.5.0')).testConnection();
      final f = result as ConnectionFailure;
      expect(f.isVersionUnsupported, isTrue);
      expect(f.actualVersion, '4.5.0');
      expect(f.minVersion, '5.0');
    });

    test('登录失败返回 authFailed', () async {
      final client = MockClient((_) async => http.Response('Fails.', 200));
      final result = await QBitService(qbit(), client: client).testConnection();
      expect((result as ConnectionFailure).category,
          ConnectionFailureCategory.authFailed);
    });
  });

  group('TransmissionService.testConnection 版本检查', () {
    Downloader trans() => Downloader(
      id: 't', name: 't', type: DownloaderType.transmission,
      host: 'h', port: 9091, username: 'u', password: 'p',
    );

    // 首次 409 取 session id，第二次返回带 rpc-version-semver 的 session-get
    http.Client transClient({required String semver}) {
      String? needSession = 'first';
      return MockClient((request) async {
        if (needSession == 'first') {
          needSession = 'done';
          return http.Response('', 409,
              headers: {'x-transmission-session-id': 'sid-1'});
        }
        return http.Response(jsonEncode({
          'result': 'success',
          'arguments': {'rpc-version-semver': semver},
        }), 200);
      });
    }

    test('6.0.0+ 达标返回 success 携带 serverVersion', () async {
      final result = await TransmissionService(trans(),
          client: transClient(semver: '6.0.0')).testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '6.0.0');
    });

    test('5.x 旧版返回 versionUnsupported', () async {
      final result = await TransmissionService(trans(),
          client: transClient(semver: '5.3.0')).testConnection();
      final f = result as ConnectionFailure;
      expect(f.isVersionUnsupported, isTrue);
      expect(f.actualVersion, '5.3.0');
      expect(f.minVersion, '6.0.0');
    });
  });
}
```

- [ ] **Step 2: 写 controller 门禁测试**

Create `test/unit/downloader_controller_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/connection_result.dart';

/// 可注入 testConnection 结果的测试用 controller。
class TestableDownloaderController extends DownloaderController {
  ConnectionResult _result;
  TestableDownloaderController(this._result) : super();

  void setTestResult(ConnectionResult result) => _result = result;

  @override
  Future<ConnectionResult> testConnection(Downloader downloader) async => _result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await GetStorage.init();
    await GetStorage().remove('downloaders');
  });

  Downloader sample() => Downloader(
    id: 'd1', name: 'D1', type: DownloaderType.aria2,
    host: 'h', port: 6800,
  );

  test('版本不符时不保存且返回 versionUnsupported', () async {
    final c = TestableDownloaderController(const ConnectionFailure(
      ConnectionFailureCategory.versionUnsupported, '版本过低',
      actualVersion: '1.35.0', minVersion: '1.36',
    ));
    final result = await c.addDownloader(sample());
    expect(result, isA<ConnectionFailure>());
    expect((result as ConnectionFailure).isVersionUnsupported, isTrue);
    expect(c.downloaders, isEmpty); // 未保存
  });

  test('成功时保存、写入 version、状态 online', () async {
    final c = TestableDownloaderController(
        const ConnectionSuccess(serverVersion: '1.36.0'));
    final result = await c.addDownloader(sample());
    expect(result.isSuccess, isTrue);
    expect(c.downloaders.length, 1);
    expect(c.downloaders.first.version, '1.36.0');
    expect(c.downloaders.first.status, DownloaderStatus.online);
  });

  test('认证失败时不保存', () async {
    final c = TestableDownloaderController(const ConnectionFailure(
      ConnectionFailureCategory.authFailed, '认证失败',
    ));
    await c.addDownloader(sample());
    expect(c.downloaders, isEmpty);
  });
}
```

- [ ] **Step 3: 写编辑页门禁 widget 测试**

Create `test/widget/downloader_editor_gate_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_editor_page.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/connection_result.dart';

class GateMockController extends DownloaderController {
  ConnectionResult result;
  GateMockController(this.result) : super();

  @override
  Future<ConnectionResult> addDownloader(Downloader downloader) async => result;

  @override
  Future<ConnectionResult> updateDownloader(Downloader downloader) async =>
      result;
}

Widget harness(DownloaderController c) => ChangeNotifierProvider<
        DownloaderController>.value(
    value: c,
    child: MaterialApp(home: DownloaderEditorPage()),
  );

void main() {
  testWidgets('版本不符时不 pop 且显示 SnackBar 提示版本', (tester) async {
    final c = GateMockController(const ConnectionFailure(
      ConnectionFailureCategory.versionUnsupported, '版本过低',
      actualVersion: '1.35.0', minVersion: '1.36',
    ));
    await tester.pumpWidget(harness(c));

    await tester.enterText(find.byType(TextFormField).at(0), 'D1');
    await tester.enterText(find.byType(TextFormField).at(1), '127.0.0.1');
    await tester.enterText(find.byType(TextFormField).at(2), '6800');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret');

    await tester.tap(find.text('保存配置'));
    await tester.pumpAndSettle();

    // 仍在编辑页（未 pop），且出现版本提示 SnackBar
    expect(find.text('添加下载器'), findsOneWidget);
    expect(find.textContaining('版本过低'), findsOneWidget);
  });

  testWidgets('成功时 pop 离开页面', (tester) async {
    final c = GateMockController(const ConnectionSuccess(serverVersion: '1.36.0'));
    await tester.pumpWidget(harness(c));

    await tester.enterText(find.byType(TextFormField).at(0), 'D1');
    await tester.enterText(find.byType(TextFormField).at(1), '127.0.0.1');
    await tester.enterText(find.byType(TextFormField).at(2), '6800');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret');

    await tester.tap(find.text('保存配置'));
    await tester.pumpAndSettle();

    // 成功 → pop → 不再有标题
    expect(find.text('添加下载器'), findsNothing);
  });
}
```

- [ ] **Step 4: 改基类签名**

Modify `lib/services/base_downloader_service.dart`。

在文件顶部新增 import:

```dart
import 'package:windwalker/services/connection_result.dart';
```

把抽象方法声明:

```dart
  /// 测试连接
  Future<bool> testConnection();
```

改为:

```dart
  /// 测试连接（含版本校验），返回带原因的结果。
  Future<ConnectionResult> testConnection();
```

- [ ] **Step 5: 改 Aria2Service.testConnection**

Modify `lib/services/aria2_service.dart`。

顶部新增 import:

```dart
import 'package:windwalker/services/connection_result.dart';
```

把整个 `testConnection()`（约第 21–41 行）替换为:

```dart
  static const String _minVersion = '1.36';

  @override
  Future<ConnectionResult> testConnection() async {
    try {
      final response = await _client
          .post(
            Uri.parse(_rpcUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'aria2.getVersion',
              'params': ['token:$_secret'],
              'id': 1,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const ConnectionFailure(
          ConnectionFailureCategory.networkError, '无法连接 Aria2');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;

      // 200 + error（如 secret 错误 Unauthorized）→ 认证失败
      if (data['error'] != null) {
        return const ConnectionFailure(
          ConnectionFailureCategory.authFailed, 'Aria2 RPC secret 错误');
      }

      final result = data['result'];
      if (result is! Map) {
        return const ConnectionFailure(
          ConnectionFailureCategory.unknown, 'Aria2 响应异常');
      }

      final version = result['version']?.toString() ?? '';
      if (_meetsMinVersion(version, _minVersion)) {
        return ConnectionSuccess(serverVersion: version);
      }
      return ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        'Aria2 版本过低',
        actualVersion: version,
        minVersion: _minVersion,
      );
    } catch (e) {
      Log.e('Aria2 testConnection error', error: e);
      return const ConnectionFailure(
        ConnectionFailureCategory.networkError, '无法连接 Aria2');
    }
  }

  /// 比较 major.minor 是否 ≥ [min]（min 形如 "1.36"）。
  bool _meetsMinVersion(String version, String min) {
    int toInt(List<String> parts, int i) =>
        i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0;
    final v = version.split('.');
    final m = min.split('.');
    for (var i = 0; i < 2; i++) {
      if (toInt(v, i) != toInt(m, i)) return toInt(v, i) > toInt(m, i);
    }
    return true; // major.minor 相等即达标
  }
```

- [ ] **Step 6: 改 QBitService.testConnection**

Modify `lib/services/qbit_service.dart`。

把顶部 import 中的:

```dart
import 'package:windwalker/services/downloader_connection_exception.dart';
```

替换为:

```dart
import 'package:windwalker/services/connection_result.dart';
```

把整个 `testConnection()`（约第 62–101 行）替换为:

```dart
  static const String _minVersion = '5.0';

  @override
  Future<ConnectionResult> testConnection() async {
    final loginSuccess = await _login();
    if (!loginSuccess) {
      return const ConnectionFailure(
        ConnectionFailureCategory.authFailed, 'qBittorrent 用户名/密码错误');
    }

    try {
      final versionResponse = await _client
          .get(Uri.parse('$_baseUrl/api/v2/app/version'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (versionResponse.statusCode != 200) {
        return const ConnectionFailure(
          ConnectionFailureCategory.unknown, 'qBittorrent 版本信息不可用');
      }

      // app/version 形如 "v5.0.0"，去掉前导非数字字符后取 major
      final raw = versionResponse.body.trim();
      final digits = raw.replaceFirst(RegExp(r'^[^0-9]+'), '');
      final major = int.tryParse(digits.split('.').first) ?? 0;
      final cleanVersion = digits.isEmpty ? raw : digits;

      if (major >= 5) {
        return ConnectionSuccess(serverVersion: cleanVersion);
      }
      return ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        'qBittorrent 版本过低，需 5.0+',
        actualVersion: cleanVersion,
        minVersion: _minVersion,
      );
    } catch (e) {
      Log.e('QBitService testConnection error', error: e);
      return const ConnectionFailure(
        ConnectionFailureCategory.networkError, '无法连接 qBittorrent');
    }
  }
```

- [ ] **Step 7: 改 TransmissionService.testConnection**

Modify `lib/services/transmission_service.dart`。

顶部新增 import:

```dart
import 'package:windwalker/services/connection_result.dart';
```

把整个 `testConnection()`（约第 56–110 行）替换为:

```dart
  static const String _minSemver = '6.0.0';

  @override
  Future<ConnectionResult> testConnection() async {
    Log.d('Transmission testConnection: $_rpcUrl');
    try {
      var response = await _client
          .post(
            Uri.parse(_rpcUrl),
            headers: _headersWithoutSession,
            body: jsonEncode(_buildRequest('session_get')),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 409) {
        _sessionId = response.headers['x-transmission-session-id'];
        response = await _client
            .post(
              Uri.parse(_rpcUrl),
              headers: _headers,
              body: jsonEncode(_buildRequest('session_get')),
            )
            .timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 401) {
        return const ConnectionFailure(
          ConnectionFailureCategory.authFailed, 'Transmission 用户名/密码错误');
      }

      if (response.statusCode != 200) {
        return const ConnectionFailure(
          ConnectionFailureCategory.networkError, '无法连接 Transmission');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['error'] != null) {
        return const ConnectionFailure(
          ConnectionFailureCategory.unknown, 'Transmission 响应异常');
      }

      final args = data['arguments'];
      final semver = (args is Map ? args['rpc-version-semver'] : null)
          ?.toString() ??
          '';
      if (semver.isEmpty) {
        return const ConnectionFailure(
          ConnectionFailureCategory.versionUnsupported, 'Transmission 版本信息缺失',
          actualVersion: '', minVersion: _minSemver);
      }

      if (_meetsSemver(semver, _minSemver)) {
        return ConnectionSuccess(serverVersion: semver);
      }
      return ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        'Transmission 版本过低，需 4.1+',
        actualVersion: semver,
        minVersion: _minSemver,
      );
    } catch (e) {
      Log.e('Transmission testConnection error', error: e);
      return const ConnectionFailure(
        ConnectionFailureCategory.networkError, '无法连接 Transmission');
    }
  }

  /// 语义化版本比较：[version] 的 major.minor.patch 是否 ≥ [min]。
  bool _meetsSemver(String version, String min) {
    int toInt(List<String> p, int i) =>
        i < p.length ? (int.tryParse(p[i]) ?? 0) : 0;
    final v = version.split('.');
    final m = min.split('.');
    for (var i = 0; i < 3; i++) {
      if (toInt(v, i) != toInt(m, i)) return toInt(v, i) > toInt(m, i);
    }
    return true;
  }
```

- [ ] **Step 8: 删除 downloader_connection_exception.dart**

Run:

```bash
git rm lib/services/downloader_connection_exception.dart
```

> 此时 `qbit_service.dart` 的 import 已在 Step 6 替换，无其他引用（已 grep 确认）。

- [ ] **Step 9: 改 DownloaderController**

Modify `lib/features/downloaders/presentation/controllers/downloader_controller.dart`。

顶部新增 import:

```dart
import 'package:windwalker/services/connection_result.dart';
```

把 `refreshStatus` 内（约第 144–157 行）的:

```dart
    if (service != null) {
      try {
        final connected = await service.testConnection();
        if (!connected) {
```

替换为:

```dart
    if (service != null) {
      try {
        final result = await service.testConnection();
        if (result is! ConnectionSuccess) {
```

把 `testConnection(Downloader)`（约第 185–189 行）替换为:

```dart
  /// 测试连接
  Future<ConnectionResult> testConnection(Downloader downloader) async {
    final service = _createService(downloader);
    if (service == null) {
      return const ConnectionFailure(
          ConnectionFailureCategory.unknown, '未知下载器类型');
    }
    return await service.testConnection();
  }
```

把 `addDownloader`（约第 254–262 行）替换为:

```dart
  /// 添加下载器（硬门禁：连接失败或版本不符均不保存）
  Future<ConnectionResult> addDownloader(Downloader downloader) async {
    final result = await testConnection(downloader);
    if (result is ConnectionSuccess) {
      _downloaders.add(downloader.copyWith(
        status: DownloaderStatus.online,
        version: result.serverVersion,
      ));
      await _saveDownloaders();
      _notifySafely();
    }
    return result;
  }
```

把 `updateDownloader`（约第 265–276 行）替换为:

```dart
  /// 更新下载器（硬门禁：连接失败或版本不符不更新）
  Future<ConnectionResult> updateDownloader(Downloader downloader) async {
    final result = await testConnection(downloader);
    if (result is ConnectionSuccess) {
      final updated = downloader.copyWith(
        status: DownloaderStatus.online,
        version: result.serverVersion,
      );
      final index = _downloaders.indexWhere((d) => d.id == downloader.id);
      if (index != -1) {
        _downloaders[index] = updated;
        await _saveDownloaders();
        _notifySafely();
      }
    }
    return result;
  }
```

- [ ] **Step 10: 改 DownloaderEditorPage._save**

Modify `lib/features/downloaders/presentation/pages/downloader_editor_page.dart`。

顶部新增 import:

```dart
import 'package:windwalker/services/connection_result.dart';
```

把 `_save` 方法体（约第 210–243 行）替换为:

```dart
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final controller = context.read<DownloaderController>();
      final port = int.parse(_portController.text.trim());

      final downloader = Downloader(
        id: _existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        type: _type,
        host: _hostController.text.trim(),
        port: port,
        secret: _type == DownloaderType.aria2
            ? _secretController.text.trim().ifEmptyToNull
            : null,
        username: _type != DownloaderType.aria2
            ? _usernameController.text.trim().ifEmptyToNull
            : null,
        password: _type != DownloaderType.aria2
            ? _passwordController.text.trim().ifEmptyToNull
            : null,
        useHttps: _https,
      );

      final result = _isEdit
          ? await controller.updateDownloader(downloader)
          : await controller.addDownloader(downloader);

      if (!mounted) return;

      switch (result) {
        case ConnectionSuccess():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('连接成功')),
          );
          Navigator.of(context).pop();
        case ConnectionFailure(
            :final category,
            :final reason,
            :final actualVersion,
            :final minVersion):
          final message = switch (category) {
            ConnectionFailureCategory.versionUnsupported =>
              (actualVersion != null && minVersion != null)
                  ? '版本过低：当前 $actualVersion，需 ≥$minVersion'
                  : reason,
            ConnectionFailureCategory.authFailed => '认证失败：请检查用户名/密码',
            ConnectionFailureCategory.networkError => '无法连接：请检查地址/端口/网络',
            ConnectionFailureCategory.unknown => reason,
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
```

- [ ] **Step 11: 改 test_helpers.dart 的 fake 签名**

Modify `test/widget/test_helpers.dart`。

顶部新增 import:

```dart
import 'package:windwalker/services/connection_result.dart';
```

把（约第 72–73 行）:

```dart
  @override
  Future<bool> testConnection(Downloader downloader) async => true;
```

替换为:

```dart
  @override
  Future<ConnectionResult> testConnection(Downloader downloader) async =>
      const ConnectionSuccess();
```

把（约第 114–115 行）:

```dart
  @override
  Future<void> updateDownloader(Downloader downloader) async {}
```

替换为:

```dart
  @override
  Future<ConnectionResult> updateDownloader(Downloader downloader) async =>
      const ConnectionSuccess();
```

- [ ] **Step 12: 跑全量测试**

Run: `flutter test`
Expected: 全部 PASS。若出现编译错误，定位到未同步签名的调用点修复（典型遗漏：`base_downloader_service.dart` import、`qbit_service.dart` 仍 import 已删除的 exception）。

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "feat: 下载器 API 版本硬门禁 + ConnectionResult 接入全链路"
```

---

## Task 4: 管理页卡片版本徽章

**Files:**
- Modify: `lib/features/home/presentation/pages/management_tab.dart`
- Test: `test/widget/management_tab_version_badge_test.dart`

- [ ] **Step 1: 写失败测试**

Create `test/widget/management_tab_version_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/home/presentation/pages/management_tab.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';

class StubController extends DownloaderController {
  final List<Downloader> items;
  StubController(this.items) : super();

  @override
  List<Downloader> get downloaders => List.unmodifiable(items);

  @override
  void init() {}

  @override
  Future<void> loadDownloaders() async {}
}

Widget harness(DownloaderController c) => ChangeNotifierProvider<
        DownloaderController>.value(
    value: c,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
      locale: const Locale('zh'),
      home: const ManagementTab(),
    ));

void main() {
  testWidgets('有 version 时显示版本徽章', (tester) async {
    await tester.pumpWidget(harness(StubController([
      Downloader(
        id: 'd1', name: 'D1', type: DownloaderType.aria2,
        host: 'h', port: 6800, status: DownloaderStatus.online, version: '1.36.0',
      ),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('1.36.0'), findsOneWidget);
  });

  testWidgets('version 为 null 时显示占位 —', (tester) async {
    await tester.pumpWidget(harness(StubController([
      Downloader(
        id: 'd1', name: 'D1', type: DownloaderType.aria2,
        host: 'h', port: 6800, status: DownloaderStatus.offline,
      ),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
  });
}
```

> 上述测试通过 `ChangeNotifierProvider` 注入 stub controller，绕过 `Consumer` 对 `loadDownloaders` 的依赖。`ManagementTab` 的 `initState` 会调 `loadDownloaders`（stub 内为 no-op）。

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/widget/management_tab_version_badge_test.dart`
Expected: FAIL — 找不到版本文本（`_VersionBadge` 尚未实现）。

- [ ] **Step 3: 实现 _VersionBadge 并接入卡片**

Modify `lib/features/home/presentation/pages/management_tab.dart`。

在 `_StatusBadge(...)` 所在的 Column（约第 205 行），把它替换为一个 `Row`，把状态徽章与版本徽章并排:

```dart
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _StatusBadge(label: statusLabel, color: statusColor),
                              _VersionBadge(version: downloader.version),
                            ],
                          ),
```

> 用 `Wrap` 替代 `Row` 以在窄屏自动换行，避免版本号过长溢出。

在文件末尾（`_StatusBadge` 类之后）新增 `_VersionBadge`:

```dart
class _VersionBadge extends StatelessWidget {
  final String? version;
  const _VersionBadge({required this.version});

  @override
  Widget build(BuildContext context) {
    final label = (version == null || version!.isEmpty) ? '—' : version!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textSecondaryLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondaryLight,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/widget/management_tab_version_badge_test.dart`
Expected: PASS（2 个测试）。

- [ ] **Step 5: 跑全量测试**

Run: `flutter test`
Expected: 全部 PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/presentation/pages/management_tab.dart test/widget/management_tab_version_badge_test.dart
git commit -m "feat: 下载器管理页卡片显示版本号徽章"
```

---

## Self-Review

**1. Spec 覆盖：**
- ConnectionResult 结果对象 → Task 1 ✓
- `Downloader.version` 持久化（含 fromJson 兼容）→ Task 2 ✓
- 基类签名 `bool` → `ConnectionResult` → Task 3 Step 4 ✓
- Aria2 版本校验 ≥1.36 → Task 3 Step 5 ✓
- qBit 修复（app/version ≥5.0、不再 throw）→ Task 3 Step 6 + Step 8 ✓
- Trans `rpc-version-semver` ≥6.0.0 → Task 3 Step 7 ✓
- 删除 `DownloaderConnectionException` → Task 3 Step 8 ✓
- controller 硬门禁 + 写入 version + refreshStatus 用 isSuccess → Task 3 Step 9 ✓
- 编辑页 pop / SnackBar → Task 3 Step 10 ✓
- 管理页版本 pill 徽章 → Task 4 ✓
- 后台不更新 version → Task 3 Step 9（addDownloader/updateDownloader 写 version，refreshStatus 不写）✓

**2. 占位符扫描：** 无 TBD/TODO；每个代码步骤含完整代码；无"类似 Task N"。✓

**3. 类型一致性：**
- `ConnectionResult` / `ConnectionSuccess(serverVersion:)` / `ConnectionFailure(category, reason, {actualVersion, minVersion})` 在 Task 1 定义，Task 3 各处使用一致 ✓
- `Downloader.version` 在 Task 2 定义，Task 3 controller/editor 使用 ✓
- `addDownloader`/`updateDownloader` 返回 `Future<ConnectionResult>`（Task 3 Step 9 定义），Task 3 Step 10 editor、Step 2/3 测试、test_helpers 使用一致 ✓
- `_minVersion`/`_meetsMinVersion`（Aria2）、`_minVersion`（qBit）、`_minSemver`/`_meetsSemver`（Trans）各 service 内私有，无跨 service 依赖 ✓

**4. 已知执行注意：**
- Task 3 Step 12 若编译失败，最常见原因是 `qbit_service.dart` 仍残留 `downloader_connection_exception.dart` import，或某处仍按 `bool` 使用 `testConnection()`——按编译错误定位修复即可。
- Aria2 `_meetsMinVersion` 与 Trans `_meetsSemver` 是 service 私有方法，若 lint 报"未使用"需确认已被 `testConnection` 调用。
