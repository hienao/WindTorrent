# qBittorrent Dual-Version Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add automatic, transparent support for qBittorrent `4.1-v4.6.x` and `5.0+` in WindWalker without exposing version choices to the user.

**Architecture:** Keep `QBitService` as the public entry point, but turn it into a facade over a `QBitSession`, a `QBitVersionDetector`, and versioned adapters. Shared qBittorrent behavior lives in a base adapter, while version-specific endpoint differences stay isolated in `QBitV4Adapter` and `QBitV5Adapter`.

**Tech Stack:** Flutter, Dart, `http`, `flutter_test`, `MockClient`, Provider-based controllers, existing `ConnectionResult` and `DownloaderServiceException`

---

## File Structure

### Production files

- Create: `lib/services/qbit/qbit_api_generation.dart`
  - Enum for `v4Legacy` vs `v5Modern`
- Create: `lib/services/qbit/qbit_server_profile.dart`
  - Immutable server detection result
- Create: `lib/services/qbit/qbit_session.dart`
  - Shared login, headers, request sending, and one-time re-login
- Create: `lib/services/qbit/qbit_version_detector.dart`
  - Detects `app/version` and `app/webapiVersion`
- Create: `lib/services/qbit/qbit_api_adapter.dart`
  - Adapter contract for qBittorrent operations used by WindWalker
- Create: `lib/services/qbit/qbit_base_api_adapter.dart`
  - Shared implementation for endpoints common to `4.x` and `5.x`
- Create: `lib/services/qbit/qbit_v4_adapter.dart`
  - qBittorrent `4.1-v4.6.x` endpoint overrides
- Create: `lib/services/qbit/qbit_v5_adapter.dart`
  - qBittorrent `5.0+` endpoint overrides
- Modify: `lib/services/qbit_service.dart`
  - Convert current monolith into public facade that caches a detected adapter

### Test files

- Create: `test/unit/services/qbit/qbit_version_detector_test.dart`
  - Unit tests for version detection and unsupported-version failures
- Create: `test/unit/services/qbit/qbit_torrent_adapter_test.dart`
  - Contract tests for pause/resume endpoint differences
- Create: `test/unit/services/qbit/qbit_service_facade_test.dart`
  - Tests for detection caching and `403` re-login behavior
- Modify: `test/unit/downloader_services_test_connection_test.dart`
  - Change qBittorrent expectations from "4.x rejected" to "4.x and 5.x both accepted"
- Modify: `test/unit/downloader_services_add_task_test.dart`
  - Keep add-task regression coverage using the public `QBitService` facade

### Files that should stay unchanged

- `lib/features/downloaders/presentation/controllers/downloader_controller.dart`
- `lib/features/tasks/presentation/controllers/task_controller.dart`

The public `QBitService` type should remain stable so callers do not need migration churn.

## Task 1: Add Server Profile And Version Detector

**Files:**
- Create: `lib/services/qbit/qbit_api_generation.dart`
- Create: `lib/services/qbit/qbit_server_profile.dart`
- Create: `lib/services/qbit/qbit_version_detector.dart`
- Test: `test/unit/services/qbit/qbit_version_detector_test.dart`

- [ ] **Step 1: Write the failing detector tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/qbit/qbit_api_generation.dart';
import 'package:windwalker/services/qbit/qbit_server_profile.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';
import 'package:windwalker/services/qbit/qbit_version_detector.dart';

void main() {
  Downloader qbit() => Downloader(
    id: 'q',
    name: 'q',
    type: DownloaderType.qbittorrent,
    host: 'localhost',
    port: 8080,
    username: 'admin',
    password: 'admin',
  );

  test('detects qBittorrent 4.x as v4Legacy', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200, headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('v4.5.2', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.8.3', 200);
      }
      return http.Response('', 404);
    });

    final session = QBitSession(qbit(), client: client);
    final profile = await QBitVersionDetector(session).detect();

    expect(profile.apiGeneration, QBitApiGeneration.v4Legacy);
    expect(profile.appVersion, '4.5.2');
    expect(profile.webApiVersion, '2.8.3');
  });

  test('detects qBittorrent 5.x as v5Modern', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200, headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('v5.0.0', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.11.3', 200);
      }
      return http.Response('', 404);
    });

    final session = QBitSession(qbit(), client: client);
    final profile = await QBitVersionDetector(session).detect();

    expect(profile.apiGeneration, QBitApiGeneration.v5Modern);
    expect(profile.appVersion, '5.0.0');
    expect(profile.webApiVersion, '2.11.3');
  });

  test('throws on malformed version payload', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200, headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('qbittorrent-latest', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.11.3', 200);
      }
      return http.Response('', 404);
    });

    final session = QBitSession(qbit(), client: client);

    expect(
      () => QBitVersionDetector(session).detect(),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects qBittorrent below 4.1', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200, headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('v4.0.3', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.7.0', 200);
      }
      return http.Response('', 404);
    });

    final session = QBitSession(qbit(), client: client);

    expect(
      () => QBitVersionDetector(session).detect(),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
```

- [ ] **Step 2: Run the detector test to verify it fails**

Run: `flutter test test/unit/services/qbit/qbit_version_detector_test.dart`

Expected: FAIL with missing imports such as `lib/services/qbit/qbit_version_detector.dart` and `lib/services/qbit/qbit_session.dart`.

- [ ] **Step 3: Write the minimal production code**

`lib/services/qbit/qbit_api_generation.dart`

```dart
enum QBitApiGeneration {
  v4Legacy,
  v5Modern,
}
```

`lib/services/qbit/qbit_server_profile.dart`

```dart
import 'package:windwalker/services/qbit/qbit_api_generation.dart';

class QBitServerProfile {
  final String appVersion;
  final String webApiVersion;
  final QBitApiGeneration apiGeneration;
  final String rawAppVersion;
  final String rawWebApiVersion;

  const QBitServerProfile({
    required this.appVersion,
    required this.webApiVersion,
    required this.apiGeneration,
    required this.rawAppVersion,
    required this.rawWebApiVersion,
  });
}
```

`lib/services/qbit/qbit_version_detector.dart`

```dart
import 'package:windwalker/services/qbit/qbit_api_generation.dart';
import 'package:windwalker/services/qbit/qbit_server_profile.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';

class QBitVersionDetector {
  final QBitSession session;

  QBitVersionDetector(this.session);

  Future<QBitServerProfile> detect() async {
    await session.login();
    final rawAppVersion = await session.getText('/api/v2/app/version');
    final rawWebApiVersion = await session.getText('/api/v2/app/webapiVersion');

    final appVersion = _stripVersion(rawAppVersion);
    final webApiVersion = rawWebApiVersion.trim();
    final parts = appVersion.split('.');
    final major = int.tryParse(parts.first);
    if (major == null) {
      throw FormatException('Invalid qBittorrent app version: $rawAppVersion');
    }
    final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    if (major < 4 || (major == 4 && minor < 1)) {
      throw UnsupportedError('Unsupported qBittorrent version: $appVersion');
    }

    return QBitServerProfile(
      appVersion: appVersion,
      webApiVersion: webApiVersion,
      apiGeneration: major >= 5
          ? QBitApiGeneration.v5Modern
          : QBitApiGeneration.v4Legacy,
      rawAppVersion: rawAppVersion,
      rawWebApiVersion: rawWebApiVersion,
    );
  }

  String _stripVersion(String raw) {
    final normalized = raw.trim().replaceFirst(RegExp(r'^[^0-9]+'), '');
    if (normalized.isEmpty) {
      throw FormatException('Empty qBittorrent version: $raw');
    }
    return normalized;
  }
}
```

- [ ] **Step 4: Run the detector tests to verify they pass**

Run: `flutter test test/unit/services/qbit/qbit_version_detector_test.dart`

Expected: PASS with 4 tests green.

- [ ] **Step 5: Commit**

```bash
git add \
  lib/services/qbit/qbit_api_generation.dart \
  lib/services/qbit/qbit_server_profile.dart \
  lib/services/qbit/qbit_version_detector.dart \
  test/unit/services/qbit/qbit_version_detector_test.dart
git commit -m "feat: add qBittorrent version detector"
```

## Task 2: Add Session And Versioned Pause/Resume Adapters

**Files:**
- Create: `lib/services/qbit/qbit_session.dart`
- Create: `lib/services/qbit/qbit_api_adapter.dart`
- Create: `lib/services/qbit/qbit_base_api_adapter.dart`
- Create: `lib/services/qbit/qbit_v4_adapter.dart`
- Create: `lib/services/qbit/qbit_v5_adapter.dart`
- Test: `test/unit/services/qbit/qbit_torrent_adapter_test.dart`

- [ ] **Step 1: Write the failing adapter contract tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';
import 'package:windwalker/services/qbit/qbit_v4_adapter.dart';
import 'package:windwalker/services/qbit/qbit_v5_adapter.dart';

void main() {
  Downloader qbit() => Downloader(
    id: 'q',
    name: 'q',
    type: DownloaderType.qbittorrent,
    host: 'localhost',
    port: 8080,
    username: 'admin',
    password: 'admin',
  );

  test('v4 pause/resume use pause and resume endpoints', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200, headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      return http.Response('', 200);
    });

    final session = QBitSession(qbit(), client: client);
    final adapter = QBitV4Adapter(session);

    await adapter.pauseTask('hash-1');
    await adapter.resumeTask('hash-1');

    expect(paths, contains('/api/v2/torrents/pause'));
    expect(paths, contains('/api/v2/torrents/resume'));
  });

  test('v5 pause/resume use stop and start endpoints', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200, headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      return http.Response('', 200);
    });

    final session = QBitSession(qbit(), client: client);
    final adapter = QBitV5Adapter(session);

    await adapter.pauseTask('hash-1');
    await adapter.resumeTask('hash-1');

    expect(paths, contains('/api/v2/torrents/stop'));
    expect(paths, contains('/api/v2/torrents/start'));
  });
}
```

- [ ] **Step 2: Run the adapter test to verify it fails**

Run: `flutter test test/unit/services/qbit/qbit_torrent_adapter_test.dart`

Expected: FAIL because adapter and session files are missing.

- [ ] **Step 3: Write the minimal session and adapter code**

`lib/services/qbit/qbit_session.dart`

```dart
import 'package:http/http.dart' as http;
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

class QBitSession {
  final Downloader downloader;
  final http.Client _client;
  String? _sid;

  QBitSession(this.downloader, {http.Client? client})
      : _client = client ?? http.Client();

  String get baseUrl => downloader.rpcUrl;

  Map<String, String> get headers => {
        'Referer': baseUrl,
        if (_sid != null) 'Cookie': _sid!,
      };

  Future<void> login() async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v2/auth/login'),
      headers: {'Referer': baseUrl},
      body: {
        'username': downloader.username,
        'password': downloader.password,
      },
    );

    if (response.body.trim() != 'Ok.') {
      throw DownloaderServiceException(
        'qBittorrent 用户名/密码错误',
        category: DownloaderServiceErrorCategory.auth,
      );
    }

    final cookie = response.headers['set-cookie'];
    if (cookie == null) {
      throw DownloaderServiceException(
        'qBittorrent SID 缺失',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    _sid = cookie.split(';').first;
  }

  Future<String> getText(String path) async {
    if (_sid == null) {
      await login();
    }
    final response = await _client.get(Uri.parse('$baseUrl$path'), headers: headers);
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent GET $path 失败: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    return response.body;
  }

  Future<http.Response> postForm(String path, Map<String, String> body) async {
    if (_sid == null) {
      await login();
    }
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        ...headers,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );
  }
}
```

`lib/services/qbit/qbit_api_adapter.dart`

```dart
abstract class QBitApiAdapter {
  Future<void> pauseTask(String taskId);
  Future<void> resumeTask(String taskId);
}
```

`lib/services/qbit/qbit_base_api_adapter.dart`

```dart
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit/qbit_api_adapter.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';

abstract class QBitBaseApiAdapter implements QBitApiAdapter {
  final QBitSession session;

  QBitBaseApiAdapter(this.session);

  Future<void> postTaskAction(String path, String taskId) async {
    final response = await session.postForm(path, {'hashes': taskId});
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent task action 失败: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
  }
}
```

`lib/services/qbit/qbit_v4_adapter.dart`

```dart
import 'package:windwalker/services/qbit/qbit_base_api_adapter.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';

class QBitV4Adapter extends QBitBaseApiAdapter {
  QBitV4Adapter(QBitSession session) : super(session);

  @override
  Future<void> pauseTask(String taskId) => postTaskAction('/api/v2/torrents/pause', taskId);

  @override
  Future<void> resumeTask(String taskId) => postTaskAction('/api/v2/torrents/resume', taskId);
}
```

`lib/services/qbit/qbit_v5_adapter.dart`

```dart
import 'package:windwalker/services/qbit/qbit_base_api_adapter.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';

class QBitV5Adapter extends QBitBaseApiAdapter {
  QBitV5Adapter(QBitSession session) : super(session);

  @override
  Future<void> pauseTask(String taskId) => postTaskAction('/api/v2/torrents/stop', taskId);

  @override
  Future<void> resumeTask(String taskId) => postTaskAction('/api/v2/torrents/start', taskId);
}
```

- [ ] **Step 4: Run the adapter tests to verify they pass**

Run: `flutter test test/unit/services/qbit/qbit_torrent_adapter_test.dart`

Expected: PASS with both adapter endpoint tests green.

- [ ] **Step 5: Commit**

```bash
git add \
  lib/services/qbit/qbit_session.dart \
  lib/services/qbit/qbit_api_adapter.dart \
  lib/services/qbit/qbit_base_api_adapter.dart \
  lib/services/qbit/qbit_v4_adapter.dart \
  lib/services/qbit/qbit_v5_adapter.dart \
  test/unit/services/qbit/qbit_torrent_adapter_test.dart
git commit -m "feat: add qBittorrent versioned adapters"
```

## Task 3: Convert QBitService Into A Facade

**Files:**
- Modify: `lib/services/qbit_service.dart`
- Modify: `test/unit/downloader_services_test_connection_test.dart`
- Test: `test/unit/services/qbit/qbit_service_facade_test.dart`

- [ ] **Step 1: Write the failing public-facade tests**

`test/unit/downloader_services_test_connection_test.dart`

```dart
test('4.x 版本返回 success 携带 serverVersion', () async {
  final result = await QBitService(
    qbit(),
    client: qbitClient(
      appVersionBody: 'v4.5.0',
      webApiVersionBody: '2.8.3',
    ),
  ).testConnection();

  expect(result, isA<ConnectionSuccess>());
  expect((result as ConnectionSuccess).serverVersion, '4.5.0');
});

test('5.0+ 版本返回 success 携带 serverVersion', () async {
  final result = await QBitService(
    qbit(),
    client: qbitClient(
      appVersionBody: 'v5.0.0',
      webApiVersionBody: '2.11.3',
    ),
  ).testConnection();

  expect(result, isA<ConnectionSuccess>());
  expect((result as ConnectionSuccess).serverVersion, '5.0.0');
});

test('4.0.x 返回 versionUnsupported', () async {
  final result = await QBitService(
    qbit(),
    client: qbitClient(
      appVersionBody: 'v4.0.3',
      webApiVersionBody: '2.7.0',
    ),
  ).testConnection();

  final failure = result as ConnectionFailure;
  expect(failure.category, ConnectionFailureCategory.versionUnsupported);
  expect(failure.actualVersion, '4.0.3');
  expect(failure.minVersion, '4.1');
});
```

`test/unit/services/qbit/qbit_service_facade_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/qbit_service.dart';

void main() {
  Downloader qbit() => Downloader(
    id: 'q',
    name: 'q',
    type: DownloaderType.qbittorrent,
    host: 'localhost',
    port: 8080,
    username: 'admin',
    password: 'admin',
  );

  test('service detects once and reuses adapter for multiple operations', () async {
    var versionReads = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200, headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        versionReads++;
        return http.Response('v4.5.0', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.8.3', 200);
      }
      return http.Response('', 200);
    });

    final service = QBitService(qbit(), client: client);
    await service.testConnection();
    await service.pauseTask('hash-1');
    await service.resumeTask('hash-1');

    expect(versionReads, 1);
  });
}
```

- [ ] **Step 2: Run the facade tests to verify they fail**

Run: `flutter test test/unit/downloader_services_test_connection_test.dart test/unit/services/qbit/qbit_service_facade_test.dart`

Expected: FAIL because `QBitService` still rejects `4.x` and does not cache a detected adapter.

- [ ] **Step 3: Rewrite `QBitService` as a facade with cached adapter resolution**

```dart
import 'package:http/http.dart' as http;
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/services/base_downloader_service.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit/qbit_api_adapter.dart';
import 'package:windwalker/services/qbit/qbit_api_generation.dart';
import 'package:windwalker/services/qbit/qbit_server_profile.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';
import 'package:windwalker/services/qbit/qbit_v4_adapter.dart';
import 'package:windwalker/services/qbit/qbit_v5_adapter.dart';
import 'package:windwalker/services/qbit/qbit_version_detector.dart';

class QBitService extends DownloaderService {
  final http.Client? _client;
  QBitSession? _session;
  QBitServerProfile? _profile;
  QBitApiAdapter? _adapter;

  QBitService(super.downloader, {http.Client? client}) : _client = client;

  QBitSession get _resolvedSession =>
      _session ??= QBitSession(downloader, client: _client);

  Future<QBitApiAdapter> _resolveAdapter() async {
    if (_adapter != null) {
      return _adapter!;
    }
    final profile = _profile ??=
        await QBitVersionDetector(_resolvedSession).detect();
    _adapter = switch (profile.apiGeneration) {
      QBitApiGeneration.v4Legacy => QBitV4Adapter(_resolvedSession),
      QBitApiGeneration.v5Modern => QBitV5Adapter(_resolvedSession),
    };
    return _adapter!;
  }

  @override
  Future<ConnectionResult> testConnection() async {
    try {
      final profile = _profile ??=
          await QBitVersionDetector(_resolvedSession).detect();
      return ConnectionSuccess(serverVersion: profile.appVersion);
    } on UnsupportedError {
      final rawVersion = await _resolvedSession.getText('/api/v2/app/version');
      final cleanVersion =
          rawVersion.trim().replaceFirst(RegExp(r'^[^0-9]+'), '');
      return ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        'qBittorrent 版本过低，需 4.1+',
        actualVersion: cleanVersion,
        minVersion: '4.1',
      );
    } on DownloaderServiceException catch (e) {
      final category = switch (e.category) {
        DownloaderServiceErrorCategory.auth =>
          ConnectionFailureCategory.authFailed,
        DownloaderServiceErrorCategory.network =>
          ConnectionFailureCategory.networkError,
        _ => ConnectionFailureCategory.unknown,
      };
      return ConnectionFailure(category, e.message);
    } on FormatException catch (e) {
      return ConnectionFailure(ConnectionFailureCategory.unknown, e.message);
    }
  }

  @override
  Future<void> pauseTask(String taskId) async {
    final adapter = await _resolveAdapter();
    await adapter.pauseTask(taskId);
  }

  @override
  Future<void> resumeTask(String taskId) async {
    final adapter = await _resolveAdapter();
    await adapter.resumeTask(taskId);
  }

  // In this task, leave the existing method bodies for add/get/delete/speed/detail
  // in place. Task 4 replaces those specific methods with adapter delegation.
}
```

- [ ] **Step 4: Run the public qBittorrent tests to verify they pass**

Run: `flutter test test/unit/downloader_services_test_connection_test.dart test/unit/services/qbit/qbit_service_facade_test.dart`

Expected: PASS with qBittorrent `4.x` and `5.x` both treated as successful connections.

- [ ] **Step 5: Commit**

```bash
git add \
  lib/services/qbit_service.dart \
  test/unit/downloader_services_test_connection_test.dart \
  test/unit/services/qbit/qbit_service_facade_test.dart
git commit -m "refactor: turn qBittorrent service into facade"
```

## Task 4: Migrate Shared qBittorrent Operations Into The Base Adapter

**Files:**
- Modify: `lib/services/qbit/qbit_api_adapter.dart`
- Modify: `lib/services/qbit/qbit_base_api_adapter.dart`
- Modify: `lib/services/qbit/qbit_v4_adapter.dart`
- Modify: `lib/services/qbit/qbit_v5_adapter.dart`
- Modify: `lib/services/qbit_service.dart`
- Modify: `test/unit/downloader_services_add_task_test.dart`
- Create: `test/unit/services/qbit/qbit_common_operations_test.dart`

- [ ] **Step 1: Write the failing regression tests for shared operations**

```dart
test('addTask uploads torrent through facade', () async {
  http.BaseRequest? capturedBase;

  final client = MockClient.streaming((request, bodyStream) async {
    capturedBase = request;
    await bodyStream.toBytes();
    if (request.url.path.endsWith('/api/v2/auth/login')) {
      return http.StreamedResponse(
        http.ByteStream.fromBytes('Ok.'.codeUnits),
        200,
        headers: {'set-cookie': 'SID=abc; Path=/'},
      );
    }
    if (request.url.path.endsWith('/api/v2/app/version')) {
      return http.StreamedResponse(
        http.ByteStream.fromBytes('v4.5.0'.codeUnits),
        200,
      );
    }
    if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
      return http.StreamedResponse(
        http.ByteStream.fromBytes('2.8.3'.codeUnits),
        200,
      );
    }
    return http.StreamedResponse(
      http.ByteStream.fromBytes('Ok.'.codeUnits),
      200,
    );
  });

  final service = QBitService(qbit(), client: client);
  await service.addTask(torrentRequest());

  expect(capturedBase, isA<http.MultipartRequest>());
});

test('getSpeedConfig reads shared preferences endpoint', () async {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/api/v2/auth/login')) {
      return http.Response('Ok.', 200, headers: {'set-cookie': 'SID=abc; Path=/'});
    }
    if (request.url.path.endsWith('/api/v2/app/version')) {
      return http.Response('v5.0.0', 200);
    }
    if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
      return http.Response('2.11.3', 200);
    }
    if (request.url.path.endsWith('/api/v2/transfer/speedLimitsMode')) {
      return http.Response('1', 200);
    }
    if (request.url.path.endsWith('/api/v2/app/preferences')) {
      return http.Response('{"dl_limit":10,"up_limit":20,"alt_dl_limit":30,"alt_up_limit":40}', 200);
    }
    return http.Response('', 404);
  });

  final service = QBitService(qbit(), client: client);
  final config = await service.getSpeedConfig();

  expect(config.speedLimitModeEnabled, isTrue);
  expect(config.downloadLimitKB, 10);
  expect(config.uploadLimitKB, 20);
});
```

- [ ] **Step 2: Run the shared-operation tests to verify they fail**

Run: `flutter test test/unit/downloader_services_add_task_test.dart test/unit/services/qbit/qbit_common_operations_test.dart`

Expected: FAIL because `QBitService` still owns legacy logic instead of routing all shared operations through the adapter layer.

- [ ] **Step 3: Move common qBittorrent operations into `QBitBaseApiAdapter`**

`lib/services/qbit/qbit_api_adapter.dart`

```dart
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader_speed_config.dart';

abstract class QBitApiAdapter {
  Future<List<DownloadTask>> getTasks();
  Future<Map<String, dynamic>> getGlobalStat();
  Future<String> addTask(AddTaskRequest request);
  Future<String> addDownload(String url, {String? savePath});
  Future<void> pauseTask(String taskId);
  Future<void> resumeTask(String taskId);
  Future<void> removeTask(String taskId, {bool deleteFiles = false});
  Future<DownloaderSpeedConfig> getSpeedConfig();
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config);
  Future<DownloadTask?> getTaskDetail(String taskId);
}
```

`lib/services/qbit/qbit_base_api_adapter.dart`

```dart
@override
Future<String> addDownload(String url, {String? savePath}) async {
  final response = await session.postForm(
    '/api/v2/torrents/add',
    {'urls': url, if (savePath != null) 'savepath': savePath},
  );
  if (response.statusCode != 200) {
    throw DownloaderServiceException(
      'qBittorrent addDownload: HTTP ${response.statusCode}',
      category: DownloaderServiceErrorCategory.protocol,
    );
  }
  return 'ok';
}

@override
Future<DownloaderSpeedConfig> getSpeedConfig() async {
  final modeBody = await session.getText('/api/v2/transfer/speedLimitsMode');
  final prefsBody = await session.getText('/api/v2/app/preferences');
  final prefs = jsonDecode(prefsBody) as Map<String, dynamic>;
  return DownloaderSpeedConfig(
    speedLimitModeEnabled: modeBody.trim() == '1',
    downloadLimitKB: prefs['dl_limit'] as int? ?? 0,
    uploadLimitKB: prefs['up_limit'] as int? ?? 0,
    altDownloadLimitKB: prefs['alt_dl_limit'] as int? ?? 0,
    altUploadLimitKB: prefs['alt_up_limit'] as int? ?? 0,
  );
}
```

`lib/services/qbit_service.dart`

```dart
@override
Future<String> addTask(AddTaskRequest request) async {
  final adapter = await _resolveAdapter();
  return adapter.addTask(request);
}

@override
Future<String> addDownload(String url, {String? savePath}) async {
  final adapter = await _resolveAdapter();
  return adapter.addDownload(url, savePath: savePath);
}

@override
Future<DownloaderSpeedConfig> getSpeedConfig() async {
  final adapter = await _resolveAdapter();
  return adapter.getSpeedConfig();
}
```

- [ ] **Step 4: Run the shared-operation tests to verify they pass**

Run: `flutter test test/unit/downloader_services_add_task_test.dart test/unit/services/qbit/qbit_common_operations_test.dart`

Expected: PASS with qBittorrent add-task and speed-config regressions green through the public facade.

- [ ] **Step 5: Commit**

```bash
git add \
  lib/services/qbit/qbit_api_adapter.dart \
  lib/services/qbit/qbit_base_api_adapter.dart \
  lib/services/qbit/qbit_v4_adapter.dart \
  lib/services/qbit/qbit_v5_adapter.dart \
  lib/services/qbit_service.dart \
  test/unit/downloader_services_add_task_test.dart \
  test/unit/services/qbit/qbit_common_operations_test.dart
git commit -m "feat: route shared qBittorrent operations through adapters"
```

## Task 5: Finish Facade Coverage And Regression Verification

**Files:**
- Modify: `lib/services/qbit_service.dart`
- Modify: `test/unit/services/qbit/qbit_service_facade_test.dart`
- Modify: `test/unit/downloader_services_test_connection_test.dart`
- Modify: `test/unit/downloader_services_add_task_test.dart`

- [ ] **Step 1: Write the failing tests for re-login and final facade coverage**

```dart
test('403 on pause triggers one re-login and retry', () async {
  var pauseCalls = 0;
  var loginCalls = 0;
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/api/v2/auth/login')) {
      loginCalls++;
      return http.Response('Ok.', 200, headers: {'set-cookie': 'SID=abc; Path=/'});
    }
    if (request.url.path.endsWith('/api/v2/app/version')) {
      return http.Response('v5.0.0', 200);
    }
    if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
      return http.Response('2.11.3', 200);
    }
    if (request.url.path.endsWith('/api/v2/torrents/stop')) {
      pauseCalls++;
      return pauseCalls == 1 ? http.Response('', 403) : http.Response('', 200);
    }
    return http.Response('', 200);
  });

  final service = QBitService(qbit(), client: client);
  await service.pauseTask('hash-1');

  expect(loginCalls, 2);
  expect(pauseCalls, 2);
});
```

- [ ] **Step 2: Run the focused facade regression tests to verify they fail**

Run: `flutter test test/unit/services/qbit/qbit_service_facade_test.dart`

Expected: FAIL because `QBitSession` does not yet perform a one-time re-login retry on `403`.

- [ ] **Step 3: Implement the one-time re-login retry and delegate the last facade methods**

`lib/services/qbit/qbit_session.dart`

```dart
Future<http.Response> postForm(String path, Map<String, String> body) async {
  if (_sid == null) {
    await login();
  }

  var response = await _client.post(
    Uri.parse('$baseUrl$path'),
    headers: {
      ...headers,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: body,
  );

  if (response.statusCode == 403) {
    _sid = null;
    await login();
    response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        ...headers,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );
  }

  return response;
}
```

`lib/services/qbit_service.dart`

```dart
@override
Future<List<DownloadTask>> getTasks() async => (await _resolveAdapter()).getTasks();

@override
Future<Map<String, dynamic>> getGlobalStat() async =>
    (await _resolveAdapter()).getGlobalStat();

@override
Future<void> removeTask(String taskId, {bool deleteFiles = false}) async =>
    (await _resolveAdapter()).removeTask(taskId, deleteFiles: deleteFiles);

@override
Future<bool> setSpeedConfig(DownloaderSpeedConfig config) async =>
    (await _resolveAdapter()).setSpeedConfig(config);

@override
Future<DownloadTask?> getTaskDetail(String taskId) async =>
    (await _resolveAdapter()).getTaskDetail(taskId);
```

- [ ] **Step 4: Run the full qBittorrent test slice**

Run: `flutter test test/unit/services/qbit`

Expected: PASS for detector tests, adapter tests, facade tests, and shared-operation tests.

Run: `flutter test test/unit/downloader_services_test_connection_test.dart test/unit/downloader_services_add_task_test.dart`

Expected: PASS for the existing downloader-service regression suites with qBittorrent now accepting both `4.x` and `5.x`.

- [ ] **Step 5: Commit**

```bash
git add \
  lib/services/qbit_service.dart \
  lib/services/qbit/qbit_session.dart \
  test/unit/services/qbit/qbit_service_facade_test.dart \
  test/unit/downloader_services_test_connection_test.dart \
  test/unit/downloader_services_add_task_test.dart
git commit -m "fix: complete qBittorrent dual-version facade flow"
```

## Spec Coverage Check

- Automatic version detection: covered by Task 1 and Task 3
- Adapter-based architecture: covered by Task 2 and Task 4
- No user-facing version selection: preserved by keeping `QBitService` public API stable in Task 3
- Fail-fast on malformed or unsupported detection: covered by Task 1 and Task 3
- Shared operation migration: covered by Task 4 and Task 5
- One-time re-login on `403`: covered by Task 5
- Controller/UI isolation: preserved because caller files stay unchanged

## Notes For Execution

- Keep `QBitService` class name stable so existing controller imports do not change.
- When replacing the body of `lib/services/qbit_service.dart`, preserve current task parsing and speed-config mapping logic by moving it into `QBitBaseApiAdapter` instead of re-inventing it.
- If `flutter test test/unit/services/qbit` requires creating the directory first, add the files before running the command.
- Do not add persisted `apiGeneration` to `Downloader` in the first pass.
- If a future qBittorrent major version appears during implementation, treat it as unsupported unless the detector and adapters are intentionally extended in the same change.
