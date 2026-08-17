# Transmission 双协议支持 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 app 在保持单一 `Transmission` 下载器入口的前提下，自动识别并同时支持 `Transmission 4.1.0+` 与 `4.1.0` 以下旧协议版本。

**Architecture:** 保留对外唯一的 `TransmissionService` facade，把协议识别、请求构造、响应解析拆到 `TransmissionProtocolDetector` 与 modern / legacy 两个 `TransmissionRpcAdapter`。controller 和 UI 层继续只依赖统一的 `DownloaderService` / `DownloadTask` / `DownloaderSpeedConfig` 语义，不感知协议分叉。

**Tech Stack:** Flutter 3.24、Dart 3、Provider、http、flutter_test、http/testing、GetStorage

---

## 文件结构

### 新建文件

- `lib/services/transmission/transmission_protocol_info.dart`
  - 定义 `TransmissionProtocol`、`TransmissionProtocolInfo`、`TransmissionDetectionResult` 等协议探测结果对象。
- `lib/services/transmission/transmission_protocol_detector.dart`
  - 负责 modern 优先、legacy 回退的自动识别与首轮握手。
- `lib/services/transmission/transmission_rpc_adapter.dart`
  - 定义 `TransmissionRpcAdapter` 统一接口。
- `lib/services/transmission/transmission_modern_rpc_adapter.dart`
  - 实现 JSON-RPC 2.0 + snake_case 读写能力。
- `lib/services/transmission/transmission_legacy_rpc_adapter.dart`
  - 实现 legacy RPC + 旧方法名 / 字段名读写能力。
- `test/unit/transmission_protocol_detector_test.dart`
  - 覆盖协议识别、409 session、401 认证失败、modern->legacy 回退。
- `test/unit/transmission_rpc_adapter_test.dart`
  - 覆盖 modern / legacy adapter 的任务、添加、限速、全局统计映射。
- `test/unit/transmission_service_facade_test.dart`
  - 覆盖 facade 的缓存、重探测、session 续期与能力门禁。

### 修改文件

- `lib/services/transmission_service.dart`
  - 从单体协议实现重构为 facade，缓存 `protocolInfo + adapter + sessionId`。
- `lib/services/base_downloader_service.dart`
  - 仅在注释层更新 Transmission 兼容描述；方法签名无需变化。
- `test/unit/downloader_services_test_connection_test.dart`
  - 改掉“4.0.x 必须拒绝”的旧假设，转为 modern / legacy 双路径成功与“能力不足旧版”失败。
- `test/unit/downloader_services_add_task_test.dart`
  - 保留 modern 断言，并追加 legacy `torrent-add` 请求 / 响应映射用例。
- `test/unit/downloader_controller_gate_test.dart`
  - 增加“legacy 成功也允许保存”的回归用例。

### 不改动文件

- `lib/features/downloaders/presentation/controllers/downloader_controller.dart`
  - 业务流不分叉，只消费 `ConnectionResult`。
- `lib/models/downloader.dart`
  - 已有 `version` 字段可复用，无需新增模型字段。
- UI 页面与路由
  - 本次不新增协议选择 UI。

---

### Task 1: 建立协议探测结果对象与 detector

**Files:**
- Create: `lib/services/transmission/transmission_protocol_info.dart`
- Create: `lib/services/transmission/transmission_protocol_detector.dart`
- Create: `test/unit/transmission_protocol_detector_test.dart`

- [ ] **Step 1: 先写 detector 的失败测试**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/transmission/transmission_protocol_detector.dart';
import 'package:windwalker/services/transmission/transmission_protocol_info.dart';
import 'package:windwalker/core/constants/app_constants.dart';

void main() {
  Downloader trans() => Downloader(
        id: 't',
        name: 'Transmission',
        type: DownloaderType.transmission,
        host: 'localhost',
        port: 9091,
        username: 'u',
        password: 'p',
      );

  test('modern session_get response should be detected as modern', () async {
    String phase = 'first';
    final client = MockClient((request) async {
      if (phase == 'first') {
        phase = 'done';
        return http.Response('', 409, headers: {
          'x-transmission-session-id': 'sid-1',
        });
      }
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'result': {
            'rpc_version_semver': '6.0.1',
            'version': '4.1.1 (rev)',
          },
          'id': 1,
        }),
        200,
      );
    });

    final result =
        await TransmissionProtocolDetector(trans(), client: client).detect();

    expect(result.protocol, TransmissionProtocol.modern);
    expect(result.info.appVersion, '4.1.1');
    expect(result.info.rpcSemver, '6.0.1');
    expect(result.info.sessionId, 'sid-1');
  });

  test('legacy response should be detected after modern fallback', () async {
    final responses = <http.Response>[
      http.Response('', 409, headers: {'x-transmission-session-id': 'sid-2'}),
      http.Response('', 500),
      http.Response(
        jsonEncode({
          'result': 'success',
          'arguments': {
            'rpc-version-semver': '5.3.0',
            'version': '4.0.3 (rev)',
          },
          'tag': 1,
        }),
        200,
      ),
    ];

    final client = MockClient((_) async => responses.removeAt(0));

    final result =
        await TransmissionProtocolDetector(trans(), client: client).detect();

    expect(result.protocol, TransmissionProtocol.legacy);
    expect(result.info.appVersion, '4.0.3');
    expect(result.info.rpcSemver, '5.3.0');
  });

  test('401 should surface authFailed detection result', () async {
    final client = MockClient((_) async => http.Response('', 401));

    final result =
        await TransmissionProtocolDetector(trans(), client: client).detect();

    expect(result.failureCategory, TransmissionDetectionFailure.authFailed);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/transmission_protocol_detector_test.dart`
Expected: FAIL，提示缺少 `transmission_protocol_detector.dart` / `transmission_protocol_info.dart`

- [ ] **Step 3: 写最小协议结果对象**

```dart
enum TransmissionProtocol { modern, legacy }

enum TransmissionDetectionFailure { authFailed, networkError, unknown }

class TransmissionProtocolInfo {
  const TransmissionProtocolInfo({
    required this.protocol,
    required this.appVersion,
    this.rpcSemver,
    this.rpcVersion,
    this.sessionId,
  });

  final TransmissionProtocol protocol;
  final String appVersion;
  final String? rpcSemver;
  final int? rpcVersion;
  final String? sessionId;
}

class TransmissionDetectionResult {
  const TransmissionDetectionResult.success(this.info)
      : failureCategory = null;

  const TransmissionDetectionResult.failure(this.failureCategory)
      : info = null;

  final TransmissionProtocolInfo? info;
  final TransmissionDetectionFailure? failureCategory;

  bool get isSuccess => info != null;
  TransmissionProtocol get protocol => info!.protocol;
}
```

- [ ] **Step 4: 写最小 detector 实现**

```dart
class TransmissionProtocolDetector {
  TransmissionProtocolDetector(this.downloader, {http.Client? client})
      : _client = client ?? http.Client();

  final Downloader downloader;
  final http.Client _client;

  String get _rpcUrl => downloader.rpcUrl;

  Future<TransmissionDetectionResult> detect() async {
    try {
      final modern = await _detectModern();
      if (modern.isSuccess) return modern;

      if (modern.failureCategory == TransmissionDetectionFailure.authFailed) {
        return modern;
      }

      final legacy = await _detectLegacy(
        sessionId: modern.info?.sessionId,
      );
      return legacy;
    } catch (_) {
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.networkError,
      );
    }
  }

  Future<TransmissionDetectionResult> _detectModern() async {
    http.Response response = await _client.post(
      Uri.parse(_rpcUrl),
      headers: _headers(),
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'session_get',
        'id': 1,
      }),
    );

    String? sessionId;
    if (response.statusCode == 409) {
      sessionId = response.headers['x-transmission-session-id'];
      response = await _client.post(
        Uri.parse(_rpcUrl),
        headers: _headers(sessionId: sessionId),
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'session_get',
          'id': 1,
        }),
      );
    }

    if (response.statusCode == 401) {
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.authFailed,
      );
    }

    if (response.statusCode != 200) {
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.networkError,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final result = body['result'];
    if (body['jsonrpc'] == '2.0' && result is Map<String, dynamic>) {
      return TransmissionDetectionResult.success(
        TransmissionProtocolInfo(
          protocol: TransmissionProtocol.modern,
          appVersion: _normalizeAppVersion(result['version']?.toString()),
          rpcSemver: result['rpc_version_semver']?.toString(),
          sessionId: sessionId,
        ),
      );
    }

    return const TransmissionDetectionResult.failure(
      TransmissionDetectionFailure.unknown,
    );
  }

  Future<TransmissionDetectionResult> _detectLegacy({
    String? sessionId,
  }) async {
    final response = await _client.post(
      Uri.parse(_rpcUrl),
      headers: _headers(sessionId: sessionId),
      body: jsonEncode({
        'method': 'session-get',
        'tag': 1,
      }),
    );

    if (response.statusCode == 401) {
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.authFailed,
      );
    }

    if (response.statusCode != 200) {
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.networkError,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final arguments = body['arguments'];
    if (body['result'] == 'success' && arguments is Map<String, dynamic>) {
      return TransmissionDetectionResult.success(
        TransmissionProtocolInfo(
          protocol: TransmissionProtocol.legacy,
          appVersion: _normalizeAppVersion(arguments['version']?.toString()),
          rpcSemver: arguments['rpc-version-semver']?.toString(),
          sessionId: sessionId,
        ),
      );
    }

    return const TransmissionDetectionResult.failure(
      TransmissionDetectionFailure.unknown,
    );
  }

  Map<String, String> _headers({String? sessionId}) => {
        'Content-Type': 'application/json',
        if (sessionId != null) 'X-Transmission-Session-Id': sessionId,
        if (downloader.username != null && downloader.password != null)
          'Authorization': _basicAuth(),
      };

  String _basicAuth() {
    final raw = '${downloader.username}:${downloader.password}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  String _normalizeAppVersion(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw.split(RegExp(r'\\s+')).first.trim();
  }
}
```

- [ ] **Step 5: 重新运行 detector 测试**

Run: `flutter test test/unit/transmission_protocol_detector_test.dart`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add lib/services/transmission/transmission_protocol_info.dart lib/services/transmission/transmission_protocol_detector.dart test/unit/transmission_protocol_detector_test.dart
git commit -m "feat: add Transmission protocol detector"
```

---

### Task 2: 建立 adapter 接口并先打通只读能力映射

**Files:**
- Create: `lib/services/transmission/transmission_rpc_adapter.dart`
- Create: `lib/services/transmission/transmission_modern_rpc_adapter.dart`
- Create: `lib/services/transmission/transmission_legacy_rpc_adapter.dart`
- Create: `test/unit/transmission_rpc_adapter_test.dart`

- [ ] **Step 1: 先写 adapter 的只读映射失败测试**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/transmission/transmission_legacy_rpc_adapter.dart';
import 'package:windwalker/services/transmission/transmission_modern_rpc_adapter.dart';
import 'package:windwalker/services/transmission/transmission_protocol_info.dart';

void main() {
  Downloader trans() => Downloader(
        id: 't',
        name: 'Transmission',
        type: DownloaderType.transmission,
        host: 'localhost',
        port: 9091,
      );

  test('modern adapter should map snake_case torrent fields', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'result': {
              'torrents': [
                {
                  'id': 7,
                  'hash_string': 'abc',
                  'name': 'demo.iso',
                  'total_size': 100,
                  'percent_done': 0.5,
                  'rate_download': 10,
                  'rate_upload': 2,
                  'status': 4,
                  'eta': 60,
                  'peers_sending_to_us': 3,
                  'peers_getting_from_us': 5,
                  'added_date': 1710000000,
                  'done_date': 0,
                  'download_dir': '/downloads',
                }
              ]
            },
            'id': 1,
          }),
          200,
        ));

    final adapter = TransmissionModernRpcAdapter(
      downloader: trans(),
      client: client,
      protocolInfo: const TransmissionProtocolInfo(
        protocol: TransmissionProtocol.modern,
        appVersion: '4.1.1',
        rpcSemver: '6.0.1',
      ),
    );

    final tasks = await adapter.getTasks();

    expect(tasks.single.gid, 'abc');
    expect(tasks.single.totalSize, 100);
    expect(tasks.single.savePath, '/downloads');
  });

  test('legacy adapter should map legacy torrent fields', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'result': 'success',
            'arguments': {
              'torrents': [
                {
                  'id': 8,
                  'hashString': 'def',
                  'name': 'legacy.iso',
                  'totalSize': 200,
                  'percentDone': 0.25,
                  'rateDownload': 20,
                  'rateUpload': 4,
                  'status': 4,
                  'eta': 120,
                  'peersSendingToUs': 1,
                  'peersGettingFromUs': 2,
                  'addedDate': 1710000010,
                  'doneDate': 0,
                  'downloadDir': '/legacy',
                }
              ]
            },
            'tag': 1,
          }),
          200,
        ));

    final adapter = TransmissionLegacyRpcAdapter(
      downloader: trans(),
      client: client,
      protocolInfo: const TransmissionProtocolInfo(
        protocol: TransmissionProtocol.legacy,
        appVersion: '4.0.3',
        rpcSemver: '5.3.0',
      ),
    );

    final tasks = await adapter.getTasks();

    expect(tasks.single.gid, 'def');
    expect(tasks.single.totalSize, 200);
    expect(tasks.single.savePath, '/legacy');
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/transmission_rpc_adapter_test.dart`
Expected: FAIL，提示 adapter 文件或构造器不存在

- [ ] **Step 3: 定义统一 adapter 接口**

```dart
abstract class TransmissionRpcAdapter {
  Future<ConnectionResult> testConnection();
  Future<List<DownloadTask>> getTasks();
  Future<DownloadTask?> getTaskDetail(String taskId);
  Future<Map<String, dynamic>> getGlobalStat();
  Future<String> addTask(AddTaskRequest request);
  Future<void> pauseTask(String taskId);
  Future<void> resumeTask(String taskId);
  Future<void> removeTask(String taskId, {bool deleteFiles = false});
  Future<DownloaderSpeedConfig> getSpeedConfig();
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config);
}
```

- [ ] **Step 4: 先为 modern / legacy adapter 写最小只读实现**

```dart
class TransmissionModernRpcAdapter implements TransmissionRpcAdapter {
  TransmissionModernRpcAdapter({
    required this.downloader,
    required this.protocolInfo,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Downloader downloader;
  final TransmissionProtocolInfo protocolInfo;
  final http.Client _client;

  @override
  Future<List<DownloadTask>> getTasks() async {
    final data = await _call('torrent_get', {
      'fields': [
        'id',
        'hash_string',
        'name',
        'total_size',
        'percent_done',
        'rate_download',
        'rate_upload',
        'status',
        'eta',
        'peers_sending_to_us',
        'peers_getting_from_us',
        'added_date',
        'done_date',
        'download_dir',
      ],
    });

    final torrents = (data['torrents'] as List).cast<Map<String, dynamic>>();
    return torrents.map(_parseTask).toList();
  }

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final response = await _client.post(
      Uri.parse(downloader.rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': method,
        if (params != null) 'params': params,
        'id': 1,
      }),
    );
    return (jsonDecode(response.body) as Map<String, dynamic>)['result']
        as Map<String, dynamic>;
  }

  DownloadTask _parseTask(Map<String, dynamic> json) => DownloadTask(
        id: '${json['id']}',
        gid: json['hash_string']?.toString() ?? '${json['id']}',
        name: json['name']?.toString() ?? 'Unknown',
        totalSize: json['total_size'] as int? ?? 0,
        downloaded: ((json['total_size'] as int? ?? 0) *
                (json['percent_done'] as num? ?? 0).toDouble())
            .toInt(),
        progress: (json['percent_done'] as num? ?? 0).toDouble(),
        downloadSpeed: json['rate_download'] as int? ?? 0,
        uploadSpeed: json['rate_upload'] as int? ?? 0,
        status: TaskStatus.downloading,
        savePath: json['download_dir']?.toString() ?? '',
        downloaderId: downloader.id,
      );
}
```

```dart
class TransmissionLegacyRpcAdapter implements TransmissionRpcAdapter {
  TransmissionLegacyRpcAdapter({
    required this.downloader,
    required this.protocolInfo,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Downloader downloader;
  final TransmissionProtocolInfo protocolInfo;
  final http.Client _client;

  @override
  Future<List<DownloadTask>> getTasks() async {
    final data = await _call('torrent-get', {
      'fields': [
        'id',
        'hashString',
        'name',
        'totalSize',
        'percentDone',
        'rateDownload',
        'rateUpload',
        'status',
        'eta',
        'peersSendingToUs',
        'peersGettingFromUs',
        'addedDate',
        'doneDate',
        'downloadDir',
      ],
    });

    final torrents = (data['torrents'] as List).cast<Map<String, dynamic>>();
    return torrents.map(_parseTask).toList();
  }

  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final response = await _client.post(
      Uri.parse(downloader.rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'method': method,
        if (arguments != null) 'arguments': arguments,
        'tag': 1,
      }),
    );
    return (jsonDecode(response.body) as Map<String, dynamic>)['arguments']
        as Map<String, dynamic>;
  }

  DownloadTask _parseTask(Map<String, dynamic> json) => DownloadTask(
        id: '${json['id']}',
        gid: json['hashString']?.toString() ?? '${json['id']}',
        name: json['name']?.toString() ?? 'Unknown',
        totalSize: json['totalSize'] as int? ?? 0,
        downloaded: ((json['totalSize'] as int? ?? 0) *
                (json['percentDone'] as num? ?? 0).toDouble())
            .toInt(),
        progress: (json['percentDone'] as num? ?? 0).toDouble(),
        downloadSpeed: json['rateDownload'] as int? ?? 0,
        uploadSpeed: json['rateUpload'] as int? ?? 0,
        status: TaskStatus.downloading,
        savePath: json['downloadDir']?.toString() ?? '',
        downloaderId: downloader.id,
      );
}
```

- [ ] **Step 5: 跑 adapter 单测验证通过**

Run: `flutter test test/unit/transmission_rpc_adapter_test.dart`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add lib/services/transmission/transmission_rpc_adapter.dart lib/services/transmission/transmission_modern_rpc_adapter.dart lib/services/transmission/transmission_legacy_rpc_adapter.dart test/unit/transmission_rpc_adapter_test.dart
git commit -m "feat: add Transmission RPC adapters"
```

---

### Task 3: 补齐写操作、限速与全局统计的双协议映射

**Files:**
- Modify: `lib/services/transmission/transmission_modern_rpc_adapter.dart`
- Modify: `lib/services/transmission/transmission_legacy_rpc_adapter.dart`
- Modify: `test/unit/transmission_rpc_adapter_test.dart`
- Modify: `test/unit/downloader_services_add_task_test.dart`

- [ ] **Step 1: 先给 modern / legacy 写添加任务与限速失败测试**

```dart
test('legacy adapter should send torrent-add with download-dir', () async {
  late Map<String, dynamic> payload;
  final client = MockClient((request) async {
    payload = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({
        'result': 'success',
        'arguments': {
          'torrent-added': {'id': 42}
        },
        'tag': 1,
      }),
      200,
    );
  });

  final adapter = TransmissionLegacyRpcAdapter(
    downloader: trans(),
    client: client,
    protocolInfo: const TransmissionProtocolInfo(
      protocol: TransmissionProtocol.legacy,
      appVersion: '4.0.3',
    ),
  );

  final result = await adapter.addTask(
    AddTaskRequest(
      downloaderId: 't',
      torrentFileName: 'demo.torrent',
      torrentFileBytes: Uint8List.fromList([1, 2, 3]),
      savePath: '/legacy',
    ),
  );

  expect(result, '42');
  expect(payload['method'], 'torrent-add');
  expect((payload['arguments'] as Map<String, dynamic>)['download-dir'],
      '/legacy');
});

test('legacy adapter should map alt-speed fields into DownloaderSpeedConfig',
    () async {
  final client = MockClient((_) async => http.Response(
        jsonEncode({
          'result': 'success',
          'arguments': {
            'alt-speed-enabled': true,
            'speed-limit-down': 100,
            'speed-limit-up': 50,
            'alt-speed-down': 20,
            'alt-speed-up': 10,
          },
          'tag': 1,
        }),
        200,
      ));

  final adapter = TransmissionLegacyRpcAdapter(
    downloader: trans(),
    client: client,
    protocolInfo: const TransmissionProtocolInfo(
      protocol: TransmissionProtocol.legacy,
      appVersion: '4.0.3',
    ),
  );

  final config = await adapter.getSpeedConfig();
  expect(config.speedLimitModeEnabled, isTrue);
  expect(config.downloadLimitKB, 100);
  expect(config.altUploadLimitKB, 10);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/transmission_rpc_adapter_test.dart test/unit/downloader_services_add_task_test.dart`
Expected: FAIL，提示 `addTask` / `getSpeedConfig` / legacy 响应解析尚未实现

- [ ] **Step 3: 在两个 adapter 中实现写操作与统计映射**

```dart
@override
Future<String> addTask(AddTaskRequest request) async {
  if (request.hasUrlSource) {
    return addDownload(request.url!, savePath: request.savePath);
  }

  final result = await _call('torrent-add', {
    'metainfo': base64Encode(request.torrentFileBytes!),
    if (request.savePath != null) 'download-dir': request.savePath,
  });

  return result['torrent-added']?['id']?.toString() ??
      result['torrent-duplicate']?['id']?.toString() ??
      '';
}

@override
Future<DownloaderSpeedConfig> getSpeedConfig() async {
  final result = await _call('session-get');
  return DownloaderSpeedConfig(
    speedLimitModeEnabled: result['alt-speed-enabled'] as bool? ?? false,
    downloadLimitKB: result['speed-limit-down'] as int? ?? 0,
    uploadLimitKB: result['speed-limit-up'] as int? ?? 0,
    altDownloadLimitKB: result['alt-speed-down'] as int? ?? 0,
    altUploadLimitKB: result['alt-speed-up'] as int? ?? 0,
  );
}

@override
Future<Map<String, dynamic>> getGlobalStat() async {
  final result = await _call('session-stats');
  return {
    'downloadSpeed': result['downloadSpeed'] ?? result['download-speed'] ?? 0,
    'uploadSpeed': result['uploadSpeed'] ?? result['upload-speed'] ?? 0,
    'torrentCount': result['torrentCount'] ??
        result['torrent-count'] ??
        result['activeTorrentCount'] ??
        0,
  };
}
```

- [ ] **Step 4: 用现有 addTask 测试文件补 legacy 回归**

```dart
test('TransmissionService legacy addTask should parse torrent-added', () async {
  final responses = <http.Response>[
    http.Response(
      jsonEncode({
        'result': 'success',
        'arguments': {
          'rpc-version-semver': '5.3.0',
          'version': '4.0.3 (rev)',
        },
        'tag': 1,
      }),
      200,
    ),
    http.Response(
      jsonEncode({
        'result': 'success',
        'arguments': {
          'torrent-added': {'id': 99}
        },
        'tag': 2,
      }),
      200,
    ),
  ];

  final service = TransmissionService(
    Downloader(
      id: 'tx-test',
      name: 'Legacy Transmission',
      type: DownloaderType.transmission,
      host: 'localhost',
      port: 9091,
      username: 'admin',
      password: 'admin',
    ),
    client: MockClient((_) async => responses.removeAt(0)),
  );

  final result = await service.addTask(
    AddTaskRequest(
      downloaderId: 'tx-test',
      torrentFileName: 'demo.torrent',
      torrentFileBytes: Uint8List.fromList([1, 2, 3]),
    ),
  );

  expect(result, '99');
});
```

- [ ] **Step 5: 重新运行适配器与添加任务测试**

Run: `flutter test test/unit/transmission_rpc_adapter_test.dart test/unit/downloader_services_add_task_test.dart`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add lib/services/transmission/transmission_modern_rpc_adapter.dart lib/services/transmission/transmission_legacy_rpc_adapter.dart test/unit/transmission_rpc_adapter_test.dart test/unit/downloader_services_add_task_test.dart
git commit -m "feat: support Transmission legacy write operations"
```

---

### Task 4: 把 TransmissionService 重构为 facade

**Files:**
- Modify: `lib/services/transmission_service.dart`
- Create: `test/unit/transmission_service_facade_test.dart`
- Modify: `test/unit/downloader_services_test_connection_test.dart`

- [ ] **Step 1: 先写 facade 缓存与门禁失败测试**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/transmission_service.dart';

void main() {
  Downloader trans() => Downloader(
        id: 't',
        name: 'Transmission',
        type: DownloaderType.transmission,
        host: 'localhost',
        port: 9091,
        username: 'u',
        password: 'p',
      );

  test('legacy server should pass testConnection when capability check passes',
      () async {
    final responses = <http.Response>[
      http.Response(
        jsonEncode({
          'result': 'success',
          'arguments': {
            'rpc-version-semver': '5.3.0',
            'version': '4.0.3 (rev)',
          },
          'tag': 1,
        }),
        200,
      ),
      http.Response(
        jsonEncode({
          'result': 'success',
          'arguments': {
            'torrents': [],
          },
          'tag': 2,
        }),
        200,
      ),
    ];

    final service = TransmissionService(
      trans(),
      client: MockClient((_) async => responses.removeAt(0)),
    );

    final result = await service.testConnection();
    expect(result, isA<ConnectionSuccess>());
    expect((result as ConnectionSuccess).serverVersion, '4.0.3');
  });

  test('capability-insufficient legacy server should return versionUnsupported',
      () async {
    final responses = <http.Response>[
      http.Response(
        jsonEncode({
          'result': 'success',
          'arguments': {
            'rpc-version-semver': '4.0.0',
            'version': '3.00 (rev)',
          },
          'tag': 1,
        }),
        200,
      ),
      http.Response(
        jsonEncode({
          'result': 'success',
          'arguments': {},
          'tag': 2,
        }),
        200,
      ),
    ];

    final service = TransmissionService(
      trans(),
      client: MockClient((_) async => responses.removeAt(0)),
    );

    final result = await service.testConnection();
    expect(result, isA<ConnectionFailure>());
    expect((result as ConnectionFailure).isVersionUnsupported, isTrue);
  });
}
```

- [ ] **Step 2: 运行 facade 相关测试确认失败**

Run: `flutter test test/unit/transmission_service_facade_test.dart test/unit/downloader_services_test_connection_test.dart`
Expected: FAIL，当前 `TransmissionService.testConnection()` 仍把 `4.0.x` 判为不支持

- [ ] **Step 3: 重构 `TransmissionService` 为 facade**

```dart
class TransmissionService extends DownloaderService {
  TransmissionService(super.downloader, {http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  TransmissionProtocolInfo? _protocolInfo;
  TransmissionRpcAdapter? _adapter;
  bool _didRetryDetection = false;

  Future<TransmissionRpcAdapter> _getAdapter() async {
    if (_adapter != null) return _adapter!;

    final detection =
        await TransmissionProtocolDetector(downloader, client: _client).detect();

    if (!detection.isSuccess) {
      throw DownloaderServiceException(
        'Transmission 协议识别失败',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }

    _protocolInfo = detection.info;
    _adapter = switch (detection.protocol) {
      TransmissionProtocol.modern => TransmissionModernRpcAdapter(
          downloader: downloader,
          client: _client,
          protocolInfo: detection.info!,
        ),
      TransmissionProtocol.legacy => TransmissionLegacyRpcAdapter(
          downloader: downloader,
          client: _client,
          protocolInfo: detection.info!,
        ),
    };
    return _adapter!;
  }

  @override
  Future<ConnectionResult> testConnection() async {
    final adapter = await _getAdapter();
    final result = await adapter.testConnection();
    if (result is ConnectionFailure && _shouldRetryDetection(result)) {
      _adapter = null;
      _protocolInfo = null;
      _didRetryDetection = true;
      final retried = await _getAdapter();
      return retried.testConnection();
    }
    return result;
  }

  bool _shouldRetryDetection(ConnectionResult result) =>
      !_didRetryDetection &&
      result is ConnectionFailure &&
      result.category == ConnectionFailureCategory.unknown;
}
```

- [ ] **Step 4: 更新现有连接测试的断言**

```dart
test('legacy server with complete capability should return success', () async {
  String? needSession = 'first';
  final client = MockClient((request) async {
    if (needSession == 'first') {
      needSession = 'done';
      return http.Response('', 409,
          headers: {'x-transmission-session-id': 'sid-1'});
    }
    return http.Response(jsonEncode({
      'result': 'success',
      'arguments': {
        'rpc-version-semver': '5.3.0',
        'version': '4.0.3 (abc12345)',
        'torrents': [],
      },
    }), 200);
  });

  final result =
      await TransmissionService(trans(), client: client).testConnection();

  expect(result, isA<ConnectionSuccess>());
  expect((result as ConnectionSuccess).serverVersion, '4.0.3');
});
```

- [ ] **Step 5: 运行 facade 与连接测试**

Run: `flutter test test/unit/transmission_service_facade_test.dart test/unit/downloader_services_test_connection_test.dart`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add lib/services/transmission_service.dart test/unit/transmission_service_facade_test.dart test/unit/downloader_services_test_connection_test.dart
git commit -m "refactor: turn Transmission service into protocol facade"
```

---

### Task 5: 回归 controller 合约并跑完整 Transmission 测试集

**Files:**
- Modify: `test/unit/downloader_controller_gate_test.dart`
- Verify: `test/unit/transmission_protocol_detector_test.dart`
- Verify: `test/unit/transmission_rpc_adapter_test.dart`
- Verify: `test/unit/transmission_service_facade_test.dart`
- Verify: `test/unit/downloader_services_test_connection_test.dart`
- Verify: `test/unit/downloader_services_add_task_test.dart`

- [ ] **Step 1: 给 controller 门禁补 legacy 成功回归**

```dart
test('legacy Transmission success should still save downloader', () async {
  final c = TestableDownloaderController(
    const ConnectionSuccess(serverVersion: '4.0.3'),
  );

  final result = await c.addDownloader(
    Downloader(
      id: 'tx',
      name: 'Legacy Transmission',
      type: DownloaderType.transmission,
      host: 'localhost',
      port: 9091,
      username: 'u',
      password: 'p',
    ),
  );

  expect(result.isSuccess, isTrue);
  expect(c.downloaders.single.version, '4.0.3');
});
```

- [ ] **Step 2: 运行 controller 回归测试**

Run: `flutter test test/unit/downloader_controller_gate_test.dart`
Expected: PASS

- [ ] **Step 3: 运行完整 Transmission 单测集**

Run: `flutter test test/unit/transmission_protocol_detector_test.dart test/unit/transmission_rpc_adapter_test.dart test/unit/transmission_service_facade_test.dart test/unit/downloader_services_test_connection_test.dart test/unit/downloader_services_add_task_test.dart test/unit/downloader_controller_gate_test.dart`
Expected: PASS，所有 modern / legacy 路径通过

- [ ] **Step 4: 跑一次更广的服务层回归**

Run: `flutter test test/unit/services_test.dart test/unit/connection_result_test.dart`
Expected: PASS，其他下载器与通用连接结果不受影响

- [ ] **Step 5: 提交最终实现**

```bash
git add test/unit/downloader_controller_gate_test.dart
git commit -m "test: cover Transmission legacy compatibility flow"
```

---

## 自检清单

- Spec coverage:
  - 自动识别与回退：Task 1、Task 4
  - modern / legacy 双 adapter：Task 2、Task 3
  - 主要功能链路：Task 2、Task 3
  - facade 缓存与重探测：Task 4
  - 过旧旧版能力门禁：Task 4
  - controller 对 legacy 成功透明：Task 5
- Placeholder scan:
  - 无 `TBD` / `TODO`
  - 每个代码步骤都给了明确类、方法或测试内容
  - 每个验证步骤都给了精确 `flutter test` 命令
- Type consistency:
  - 统一使用 `TransmissionProtocolInfo`、`TransmissionDetectionResult`、`TransmissionRpcAdapter`
  - `ConnectionResult` 保持现有签名，不引入额外 controller 分支
