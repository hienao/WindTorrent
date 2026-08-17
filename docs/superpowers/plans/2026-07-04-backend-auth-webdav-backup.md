# Backend Auth and WebDAV Backup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Google/Firebase Auth and hidden Google Drive backup with backend email/password auth, email-code registration, and user-configured WebDAV backup with restore, automatic retention, and manual deletion.

**Architecture:** Use the approved layered refactor from `docs/superpowers/specs/2026-07-04-backend-auth-webdav-backup-design.md`. Auth gets API, token store, repository, controller, and UI boundaries; backup gets WebDAV config, storage API, repository, controller, and settings UI boundaries. Existing downloader backup bundle and rollback behavior remain the local data contract.

**Tech Stack:** Flutter 3.24.5, Provider `ChangeNotifier`, go_router, GetStorage, package:http, Firebase Analytics retained, Flutter l10n ARB files.

---

## Scope Check

The spec covers two user-facing subsystems: backend auth and WebDAV backup. They are implemented in one plan because WebDAV backup is gated by the new backend login state and both require removing Google auth assumptions from shared app wiring. The tasks are ordered so auth compiles and works first, then WebDAV config/storage, then backup UI and cleanup.

## File Structure

### Auth Files

- Create `lib/features/auth/data/app_backend_auth_api.dart`
  - HTTP client for the backend OpenAPI auth endpoints.
- Create `lib/features/auth/data/auth_api_models.dart`
  - Request/response DTOs for auth JSON.
- Create `lib/features/auth/data/auth_token_store.dart`
  - GetStorage-backed token and cached user persistence.
- Create `lib/features/auth/data/backend_auth_repository.dart`
  - Coordinates API + store, including refresh-on-401.
- Create `lib/core/config/backend_auth_config.dart`
  - Holds backend base URL, app ID, and app key constants.
- Create `lib/features/auth/data/auth_exceptions.dart`
  - Typed auth exception and reason enum.
- Modify `lib/features/auth/presentation/controllers/auth_controller.dart`
  - Depend on `BackendAuthRepository`, expose login/register/send-code state.
- Modify `lib/features/auth/presentation/pages/login_page.dart`
  - Replace Google button with login/register forms.
- Modify `lib/models/auth_user.dart`
  - Remove Firebase import and `fromFirebase`.
- Modify `lib/models/app_user.dart`
  - Keep as UI model; ensure backend `id` maps to `uid`.
- Modify `lib/core/config/auth_provider_factory.dart`
  - Replace with `BackendAuthRepository` factory or remove if unused.
- Modify `lib/services/auth_telemetry_service.dart`
  - Rename events to backend-neutral auth events.

### Backup Files

- Create `lib/features/backup/data/backup_storage_api.dart`
  - Storage abstraction for list/upload/download/delete.
- Create `lib/features/backup/data/backup_exceptions.dart`
  - Typed backup/WebDAV exception and reason enum.
- Create `lib/features/backup/data/webdav_config.dart`
  - WebDAV configuration value object.
- Create `lib/features/backup/data/webdav_config_store.dart`
  - GetStorage-backed WebDAV config persistence.
- Create `lib/features/backup/data/webdav_backup_storage_api.dart`
  - WebDAV implementation of `BackupStorageApi`.
- Create `lib/features/backup/data/downloader_backup_repository.dart`
  - Business orchestration for export/restore/delete/retention.
- Modify `lib/features/settings/presentation/controllers/settings_backup_controller.dart`
  - Depend on backup repository and config store; add delete/test states.
- Modify `lib/features/settings/presentation/pages/settings_page.dart`
  - Restore backup section and link WebDAV configuration.
- Create `lib/features/settings/presentation/pages/webdav_config_page.dart`
  - WebDAV URL, directory, username, password/token, test, save.
- Modify `lib/core/router/app_router.dart`
  - Add `/settings/webdav`.
- Modify `lib/app.dart`
  - Wire backend auth repository and WebDAV backup repository into providers.
- Keep `lib/models/downloader_backup_bundle.dart`
  - Reuse schema, backend user ID stored in `user.uid`.
- Keep `lib/models/downloader_backup_version.dart`
  - Reuse for WebDAV versions; `fileId` stores encoded remote path or href.

### Cleanup Files

- Delete `lib/services/firebase_auth_provider.dart`.
- Delete `lib/services/google_drive_backup_api.dart`.
- Delete `lib/services/drive_auth_exception.dart`.
- Modify `lib/main.dart`
  - Remove Firebase Auth import and `FirebaseAuth.instance.setLanguageCode`.
- Modify `pubspec.yaml`
  - Remove `firebase_auth` and `google_sign_in`.
- Modify `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_ja.arb`
  - Replace Google/Drive strings and add auth/WebDAV strings.

### Test Files

- Create `test/unit/features/auth/app_backend_auth_api_test.dart`.
- Create `test/unit/features/auth/auth_token_store_test.dart`.
- Create `test/unit/features/auth/backend_auth_repository_test.dart`.
- Modify `test/unit/auth_controller_test.dart`.
- Modify `test/widget/login_page_test.dart`.
- Create `test/unit/features/backup/webdav_config_store_test.dart`.
- Create `test/unit/features/backup/webdav_backup_storage_api_test.dart`.
- Create `test/unit/features/backup/downloader_backup_repository_test.dart`.
- Modify `test/unit/features/settings/settings_backup_controller_test.dart`.
- Modify or replace `test/unit/services/google_drive_backup_api_test.dart`.
- Modify or replace `test/unit/services/downloader_backup_service_test.dart`.

---

## Task 1: Auth DTOs, Exceptions, API Client, and Token Store

**Files:**
- Create: `lib/features/auth/data/auth_exceptions.dart`
- Create: `lib/features/auth/data/auth_api_models.dart`
- Create: `lib/features/auth/data/app_backend_auth_api.dart`
- Create: `lib/features/auth/data/auth_token_store.dart`
- Modify: `lib/models/auth_user.dart`
- Test: `test/unit/features/auth/app_backend_auth_api_test.dart`
- Test: `test/unit/features/auth/auth_token_store_test.dart`

- [ ] **Step 1: Write failing API client tests**

Create `test/unit/features/auth/app_backend_auth_api_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/features/auth/data/app_backend_auth_api.dart';
import 'package:windwalker/features/auth/data/auth_exceptions.dart';

void main() {
  group('AppBackendAuthApi', () {
    test('loginWithPassword posts app headers and parses tokens', () async {
      final api = AppBackendAuthApi(
        baseUrl: Uri.parse('https://appapi.51cloud.de'),
        appId: 'windwalker',
        appKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/login/password');
          expect(request.headers['X-App-Id'], 'windwalker');
          expect(request.headers['X-App-Key'], 'test-key');
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'email': 'user@example.com',
            'password': 'P@ssw0rd123',
          });
          return http.Response(
            jsonEncode({
              'accessToken': 'access-1',
              'refreshToken': 'refresh-1',
              'sessionId': 'session-1',
              'name': 'Alice',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final response = await api.loginWithPassword(
        email: 'user@example.com',
        password: 'P@ssw0rd123',
      );

      expect(response.accessToken, 'access-1');
      expect(response.refreshToken, 'refresh-1');
      expect(response.sessionId, 'session-1');
      expect(response.name, 'Alice');
    });

    test('sendRegisterCode maps 429 to rateLimited', () async {
      final api = AppBackendAuthApi(
        baseUrl: Uri.parse('https://appapi.51cloud.de'),
        appId: 'windwalker',
        appKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/auth/email/send-code');
          expect(jsonDecode(request.body), {
            'email': 'user@example.com',
            'scene': 'REGISTER',
          });
          return http.Response(
            jsonEncode({'code': 'RATE_LIMITED', 'message': 'too frequent'}),
            429,
          );
        }),
      );

      expect(
        () => api.sendRegisterCode(email: 'user@example.com'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.rateLimited,
          ),
        ),
      );
    });

    test('register maps 409 to emailAlreadyRegistered', () async {
      final api = AppBackendAuthApi(
        baseUrl: Uri.parse('https://appapi.51cloud.de'),
        appId: 'windwalker',
        appKey: 'test-key',
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'code': 'EMAIL_ALREADY_REGISTERED',
              'message': 'email already registered',
            }),
            409,
          );
        }),
      );

      expect(
        () => api.register(
          email: 'user@example.com',
          code: '123456',
          password: 'P@ssw0rd123',
          name: 'Alice',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.reason,
            'reason',
            AuthFailureReason.emailAlreadyRegistered,
          ),
        ),
      );
    });

    test('me sends bearer token and parses current user', () async {
      final api = AppBackendAuthApi(
        baseUrl: Uri.parse('https://appapi.51cloud.de'),
        appId: 'windwalker',
        appKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/auth/me');
          expect(request.headers['Authorization'], 'Bearer access-1');
          return http.Response(
            jsonEncode({
              'id': 42,
              'appId': 'windwalker',
              'email': 'user@example.com',
              'name': 'Alice',
              'emailVerified': true,
              'createdAt': '2026-07-04T12:00:00Z',
            }),
            200,
          );
        }),
      );

      final user = await api.me(accessToken: 'access-1');

      expect(user.id, 42);
      expect(user.email, 'user@example.com');
      expect(user.name, 'Alice');
    });
  });
}
```

- [ ] **Step 2: Run API tests and verify they fail**

Run:

```bash
flutter test test/unit/features/auth/app_backend_auth_api_test.dart
```

Expected: fails because `AppBackendAuthApi`, `AuthException`, and DTOs do not exist.

- [ ] **Step 3: Write failing token store tests**

Create `test/unit/features/auth/auth_token_store_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/features/auth/data/auth_api_models.dart';
import 'package:windwalker/features/auth/data/auth_token_store.dart';

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
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return '/tmp/test_windwalker';
        }
        return null;
      },
    );
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
  });

  test('saveSession and readSession round trip tokens and user', () async {
    final store = AuthTokenStore(storage: GetStorage());

    await store.saveSession(
      tokens: const AuthTokenResponse(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        sessionId: 'session-1',
        name: 'Alice',
      ),
      user: const UserInfoResponse(
        id: 42,
        appId: 'windwalker',
        email: 'user@example.com',
        name: 'Alice',
        emailVerified: true,
        createdAt: null,
      ),
    );

    final session = store.readSession();

    expect(session?.accessToken, 'access-1');
    expect(session?.refreshToken, 'refresh-1');
    expect(session?.sessionId, 'session-1');
    expect(session?.user.id, 42);
    expect(session?.user.email, 'user@example.com');
  });

  test('clear removes all auth keys', () async {
    final store = AuthTokenStore(storage: GetStorage());
    await store.saveSession(
      tokens: const AuthTokenResponse(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        sessionId: 'session-1',
        name: 'Alice',
      ),
      user: const UserInfoResponse(
        id: 42,
        appId: 'windwalker',
        email: 'user@example.com',
        name: 'Alice',
        emailVerified: true,
        createdAt: null,
      ),
    );

    await store.clear();

    expect(store.readSession(), isNull);
  });
}
```

- [ ] **Step 4: Run token store tests and verify they fail**

Run:

```bash
flutter test test/unit/features/auth/auth_token_store_test.dart
```

Expected: fails because `AuthTokenStore` and DTOs do not exist.

- [ ] **Step 5: Implement auth exceptions**

Create `lib/features/auth/data/auth_exceptions.dart`:

```dart
enum AuthFailureReason {
  invalidCredentials,
  invalidCode,
  emailAlreadyRegistered,
  rateLimited,
  sessionExpired,
  network,
  server,
  unknown,
}

class AuthException implements Exception {
  const AuthException({
    required this.reason,
    this.statusCode,
    this.code,
    this.message,
  });

  final AuthFailureReason reason;
  final int? statusCode;
  final String? code;
  final String? message;

  @override
  String toString() {
    final codeText = code == null ? '' : ', code=$code';
    final statusText = statusCode == null ? '' : ', status=$statusCode';
    final messageText = message == null ? '' : ', message=$message';
    return 'AuthException(reason=$reason$statusText$codeText$messageText)';
  }
}
```

- [ ] **Step 6: Implement auth API models**

Create `lib/features/auth/data/auth_api_models.dart`:

```dart
class AuthTokenResponse {
  const AuthTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    this.name,
  });

  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final String? name;

  factory AuthTokenResponse.fromJson(Map<String, dynamic> json) {
    return AuthTokenResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      sessionId: json['sessionId'] as String,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'sessionId': sessionId,
        'name': name,
      };
}

class UserInfoResponse {
  const UserInfoResponse({
    required this.id,
    required this.appId,
    required this.email,
    this.name,
    required this.emailVerified,
    required this.createdAt,
  });

  final int id;
  final String appId;
  final String email;
  final String? name;
  final bool emailVerified;
  final DateTime? createdAt;

  factory UserInfoResponse.fromJson(Map<String, dynamic> json) {
    return UserInfoResponse(
      id: json['id'] as int,
      appId: json['appId'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'appId': appId,
        'email': email,
        'name': name,
        'emailVerified': emailVerified,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final UserInfoResponse user;
}
```

- [ ] **Step 7: Implement backend auth API**

Create `lib/features/auth/data/app_backend_auth_api.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:windwalker/features/auth/data/auth_api_models.dart';
import 'package:windwalker/features/auth/data/auth_exceptions.dart';

abstract class AuthApiClient {
  Future<void> sendRegisterCode({required String email});

  Future<AuthTokenResponse> register({
    required String email,
    required String code,
    required String password,
    String? name,
  });

  Future<AuthTokenResponse> loginWithPassword({
    required String email,
    required String password,
  });

  Future<AuthTokenResponse> refreshToken({required String refreshToken});

  Future<UserInfoResponse> me({required String accessToken});

  Future<void> logout({required String accessToken});
}

class AppBackendAuthApi implements AuthApiClient {
  AppBackendAuthApi({
    required Uri baseUrl,
    required String appId,
    required String appKey,
    required http.Client httpClient,
  })  : _baseUrl = baseUrl,
        _appId = appId,
        _appKey = appKey,
        _httpClient = httpClient;

  final Uri _baseUrl;
  final String _appId;
  final String _appKey;
  final http.Client _httpClient;

  Future<void> sendRegisterCode({required String email}) async {
    final response = await _post(
      '/api/auth/email/send-code',
      headers: _appHeaders(),
      body: {'email': email, 'scene': 'REGISTER'},
    );
    if (response.statusCode == 204) return;
    throw _exceptionFromResponse(response);
  }

  Future<AuthTokenResponse> register({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    final body = <String, Object>{
      'email': email,
      'code': code,
      'password': password,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    };
    final response = await _post(
      '/api/auth/register',
      headers: _appHeaders(),
      body: body,
    );
    if (response.statusCode == 200) {
      return AuthTokenResponse.fromJson(_decodeObject(response.body));
    }
    throw _exceptionFromResponse(response);
  }

  Future<AuthTokenResponse> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/api/auth/login/password',
      headers: _appHeaders(),
      body: {'email': email, 'password': password},
    );
    if (response.statusCode == 200) {
      return AuthTokenResponse.fromJson(_decodeObject(response.body));
    }
    throw _exceptionFromResponse(response);
  }

  Future<AuthTokenResponse> refreshToken({required String refreshToken}) async {
    final response = await _post(
      '/api/auth/token/refresh',
      headers: {
        'X-App-Id': _appId,
        'Content-Type': 'application/json',
      },
      body: {'refresh_token': refreshToken},
    );
    if (response.statusCode == 200) {
      return AuthTokenResponse.fromJson(_decodeObject(response.body));
    }
    throw _exceptionFromResponse(response);
  }

  Future<UserInfoResponse> me({required String accessToken}) async {
    final response = await _send(
      () => _httpClient.get(
        _resolve('/api/auth/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    if (response.statusCode == 200) {
      return UserInfoResponse.fromJson(_decodeObject(response.body));
    }
    throw _exceptionFromResponse(response);
  }

  Future<void> logout({required String accessToken}) async {
    final response = await _send(
      () => _httpClient.post(
        _resolve('/api/auth/logout'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    if (response.statusCode == 204) return;
    throw _exceptionFromResponse(response);
  }

  Map<String, String> _appHeaders() => {
        'X-App-Id': _appId,
        'X-App-Key': _appKey,
        'Content-Type': 'application/json',
      };

  Future<http.Response> _post(
    String path, {
    required Map<String, String> headers,
    required Map<String, Object> body,
  }) {
    return _send(
      () => _httpClient.post(
        _resolve(path),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on SocketException catch (e) {
      throw AuthException(
        reason: AuthFailureReason.network,
        message: e.message,
      );
    } on http.ClientException catch (e) {
      throw AuthException(
        reason: AuthFailureReason.network,
        message: e.message,
      );
    }
  }

  Uri _resolve(String path) => _baseUrl.replace(path: path);

  Map<String, dynamic> _decodeObject(String body) {
    return jsonDecode(body) as Map<String, dynamic>;
  }

  AuthException _exceptionFromResponse(http.Response response) {
    String? code;
    String? message;
    if (response.body.isNotEmpty) {
      try {
        final json = _decodeObject(response.body);
        code = json['code'] as String?;
        message = json['message'] as String?;
      } on FormatException {
        message = response.body;
      }
    }

    return AuthException(
      reason: _reasonFor(response.statusCode, code),
      statusCode: response.statusCode,
      code: code,
      message: message,
    );
  }

  AuthFailureReason _reasonFor(int statusCode, String? code) {
    if (statusCode == 429) return AuthFailureReason.rateLimited;
    if (statusCode >= 500) return AuthFailureReason.server;
    if (statusCode == 409 || code == 'EMAIL_ALREADY_REGISTERED') {
      return AuthFailureReason.emailAlreadyRegistered;
    }
    if (statusCode == 401) {
      if (code == 'INVALID_CODE' || code == 'CODE_EXPIRED') {
        return AuthFailureReason.invalidCode;
      }
      return AuthFailureReason.invalidCredentials;
    }
    if (statusCode == 400) return AuthFailureReason.unknown;
    return AuthFailureReason.unknown;
  }
}
```

- [ ] **Step 8: Implement token store**

Create `lib/features/auth/data/auth_token_store.dart`:

```dart
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/features/auth/data/auth_api_models.dart';

class AuthTokenStore {
  AuthTokenStore({GetStorage? storage}) : _storage = storage ?? GetStorage();

  static const _accessTokenKey = 'backend_auth_access_token';
  static const _refreshTokenKey = 'backend_auth_refresh_token';
  static const _sessionIdKey = 'backend_auth_session_id';
  static const _userKey = 'backend_auth_user';

  final GetStorage _storage;

  AuthSession? readSession() {
    final accessToken = _storage.read<String>(_accessTokenKey);
    final refreshToken = _storage.read<String>(_refreshTokenKey);
    final sessionId = _storage.read<String>(_sessionIdKey);
    final userJson = _storage.read<Map>(_userKey);
    if (accessToken == null ||
        refreshToken == null ||
        sessionId == null ||
        userJson == null) {
      return null;
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      sessionId: sessionId,
      user: UserInfoResponse.fromJson(
        Map<String, dynamic>.from(userJson),
      ),
    );
  }

  Future<void> saveSession({
    required AuthTokenResponse tokens,
    required UserInfoResponse user,
  }) async {
    await _storage.write(_accessTokenKey, tokens.accessToken);
    await _storage.write(_refreshTokenKey, tokens.refreshToken);
    await _storage.write(_sessionIdKey, tokens.sessionId);
    await _storage.write(_userKey, user.toJson());
  }

  Future<void> clear() async {
    await _storage.remove(_accessTokenKey);
    await _storage.remove(_refreshTokenKey);
    await _storage.remove(_sessionIdKey);
    await _storage.remove(_userKey);
  }
}
```

- [ ] **Step 9: Detach `AuthUser` from Firebase**

Replace `lib/models/auth_user.dart` with:

```dart
/// Unified authenticated user model.
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
```

- [ ] **Step 10: Run Task 1 tests**

Run:

```bash
flutter test \
  test/unit/features/auth/app_backend_auth_api_test.dart \
  test/unit/features/auth/auth_token_store_test.dart
```

Expected: both test files pass.

- [ ] **Step 11: Commit Task 1**

Run:

```bash
git add \
  lib/features/auth/data/auth_exceptions.dart \
  lib/features/auth/data/auth_api_models.dart \
  lib/features/auth/data/app_backend_auth_api.dart \
  lib/features/auth/data/auth_token_store.dart \
  lib/models/auth_user.dart \
  test/unit/features/auth/app_backend_auth_api_test.dart \
  test/unit/features/auth/auth_token_store_test.dart
git commit -m "feat(auth): add backend auth api and token store"
```

---

## Task 2: Backend Auth Repository and Controller Refactor

**Files:**
- Create: `lib/features/auth/data/backend_auth_repository.dart`
- Create: `lib/core/config/backend_auth_config.dart`
- Modify: `lib/features/auth/presentation/controllers/auth_controller.dart`
- Modify: `lib/services/auth_telemetry_service.dart`
- Test: `test/unit/features/auth/backend_auth_repository_test.dart`
- Test: `test/unit/auth_controller_test.dart`

- [ ] **Step 1: Write failing repository tests**

Create `test/unit/features/auth/backend_auth_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/auth/data/app_backend_auth_api.dart';
import 'package:windwalker/features/auth/data/auth_api_models.dart';
import 'package:windwalker/features/auth/data/auth_exceptions.dart';
import 'package:windwalker/features/auth/data/auth_token_store.dart';
import 'package:windwalker/features/auth/data/backend_auth_repository.dart';

class FakeAuthApi implements AuthApiClient {
  AuthTokenResponse loginTokens = const AuthTokenResponse(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    sessionId: 'session-1',
    name: 'Alice',
  );
  AuthTokenResponse refreshTokens = const AuthTokenResponse(
    accessToken: 'access-2',
    refreshToken: 'refresh-2',
    sessionId: 'session-2',
    name: 'Alice',
  );
  UserInfoResponse user = const UserInfoResponse(
    id: 42,
    appId: 'windwalker',
    email: 'user@example.com',
    name: 'Alice',
    emailVerified: true,
    createdAt: null,
  );
  Object? meError;
  Object? refreshError;
  int meCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;

  @override
  Future<void> sendRegisterCode({required String email}) async {}

  @override
  Future<AuthTokenResponse> register({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    return loginTokens;
  }

  @override
  Future<AuthTokenResponse> loginWithPassword({
    required String email,
    required String password,
  }) async {
    return loginTokens;
  }

  @override
  Future<AuthTokenResponse> refreshToken({required String refreshToken}) async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    return refreshTokens;
  }

  @override
  Future<UserInfoResponse> me({required String accessToken}) async {
    meCalls++;
    final error = meError;
    if (error != null) {
      meError = null;
      throw error;
    }
    return user;
  }

  @override
  Future<void> logout({required String accessToken}) async {
    logoutCalls++;
  }
}

class MemoryAuthTokenStore implements AuthTokenStore {
  AuthSession? session;
  bool cleared = false;

  @override
  AuthSession? readSession() => session;

  @override
  Future<void> saveSession({
    required AuthTokenResponse tokens,
    required UserInfoResponse user,
  }) async {
    cleared = false;
    session = AuthSession(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      sessionId: tokens.sessionId,
      user: user,
    );
  }

  @override
  Future<void> clear() async {
    cleared = true;
    session = null;
  }
}

void main() {
  group('BackendAuthRepository', () {
    test('loginWithPassword saves tokens and user from me', () async {
      final api = FakeAuthApi();
      final store = MemoryAuthTokenStore();
      final repo = BackendAuthRepository(api: api, tokenStore: store);

      final user = await repo.loginWithPassword(
        email: 'user@example.com',
        password: 'P@ssw0rd123',
      );

      expect(user.uid, '42');
      expect(user.email, 'user@example.com');
      expect(store.session?.accessToken, 'access-1');
    });

    test('restoreSession refreshes once after sessionExpired me failure', () async {
      final api = FakeAuthApi()
        ..meError = const AuthException(
          reason: AuthFailureReason.sessionExpired,
          statusCode: 401,
        );
      final store = MemoryAuthTokenStore()
        ..session = AuthSession(
          accessToken: 'expired-access',
          refreshToken: 'refresh-1',
          sessionId: 'session-1',
          user: api.user,
        );
      final repo = BackendAuthRepository(api: api, tokenStore: store);

      final user = await repo.restoreSession();

      expect(user?.uid, '42');
      expect(api.refreshCalls, 1);
      expect(api.meCalls, 2);
      expect(store.session?.accessToken, 'access-2');
    });

    test('restoreSession clears session when refresh fails', () async {
      final api = FakeAuthApi()
        ..meError = const AuthException(
          reason: AuthFailureReason.sessionExpired,
          statusCode: 401,
        )
        ..refreshError = const AuthException(
          reason: AuthFailureReason.sessionExpired,
          statusCode: 401,
        );
      final store = MemoryAuthTokenStore()
        ..session = AuthSession(
          accessToken: 'expired-access',
          refreshToken: 'expired-refresh',
          sessionId: 'session-1',
          user: api.user,
        );
      final repo = BackendAuthRepository(api: api, tokenStore: store);

      final user = await repo.restoreSession();

      expect(user, isNull);
      expect(store.cleared, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run repository tests and verify they fail**

Run:

```bash
flutter test test/unit/features/auth/backend_auth_repository_test.dart
```

Expected: fails because `BackendAuthRepository` does not exist.

- [ ] **Step 3: Implement backend auth repository**

Create `lib/features/auth/data/backend_auth_repository.dart`:

```dart
import 'package:windwalker/features/auth/data/app_backend_auth_api.dart';
import 'package:windwalker/features/auth/data/auth_api_models.dart';
import 'package:windwalker/features/auth/data/auth_exceptions.dart';
import 'package:windwalker/features/auth/data/auth_token_store.dart';
import 'package:windwalker/models/app_user.dart';

class BackendAuthRepository {
  BackendAuthRepository({
    required AuthApiClient api,
    required AuthTokenStore tokenStore,
  })  : _api = api,
        _tokenStore = tokenStore;

  final AuthApiClient _api;
  final AuthTokenStore _tokenStore;

  AuthSession? get cachedSession => _tokenStore.readSession();

  Future<AppUser?> restoreSession() async {
    final session = _tokenStore.readSession();
    if (session == null) return null;

    try {
      final user = await _api.me(accessToken: session.accessToken);
      await _save(tokens: _tokensFromSession(session), user: user);
      return _toAppUser(user);
    } on AuthException catch (e) {
      if (e.reason != AuthFailureReason.sessionExpired &&
          e.statusCode != 401) {
        rethrow;
      }
      return _refreshAndLoadMe(session.refreshToken);
    }
  }

  Future<void> sendRegisterCode({required String email}) {
    return _api.sendRegisterCode(email: email);
  }

  Future<AppUser> register({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    final tokens = await _api.register(
      email: email,
      code: code,
      password: password,
      name: name,
    );
    final user = await _api.me(accessToken: tokens.accessToken);
    await _save(tokens: tokens, user: user);
    return _toAppUser(user);
  }

  Future<AppUser> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final tokens = await _api.loginWithPassword(
      email: email,
      password: password,
    );
    final user = await _api.me(accessToken: tokens.accessToken);
    await _save(tokens: tokens, user: user);
    return _toAppUser(user);
  }

  Future<void> logout() async {
    final session = _tokenStore.readSession();
    if (session == null) return;
    try {
      await _api.logout(accessToken: session.accessToken);
      await _tokenStore.clear();
    } on AuthException catch (e) {
      if (e.statusCode == 401 ||
          e.reason == AuthFailureReason.sessionExpired) {
        await _tokenStore.clear();
        return;
      }
      rethrow;
    }
  }

  Future<void> clearLocalSession() => _tokenStore.clear();

  Future<AppUser?> _refreshAndLoadMe(String refreshToken) async {
    try {
      final tokens = await _api.refreshToken(refreshToken: refreshToken);
      final user = await _api.me(accessToken: tokens.accessToken);
      await _save(tokens: tokens, user: user);
      return _toAppUser(user);
    } on AuthException {
      await _tokenStore.clear();
      return null;
    }
  }

  Future<void> _save({
    required AuthTokenResponse tokens,
    required UserInfoResponse user,
  }) {
    return _tokenStore.saveSession(tokens: tokens, user: user);
  }

  AuthTokenResponse _tokensFromSession(AuthSession session) {
    return AuthTokenResponse(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      sessionId: session.sessionId,
      name: session.user.name,
    );
  }

  AppUser _toAppUser(UserInfoResponse user) {
    return AppUser(
      uid: user.id.toString(),
      email: user.email,
      displayName: user.name,
      createdAt: user.createdAt,
    );
  }
}
- [ ] **Step 4: Run repository tests**

Run:

```bash
flutter test test/unit/features/auth/backend_auth_repository_test.dart
```

Expected: repository tests pass.

- [ ] **Step 5: Replace auth telemetry methods**

Replace `lib/services/auth_telemetry_service.dart` with:

```dart
import 'package:windwalker/features/auth/data/auth_exceptions.dart';
import 'package:windwalker/services/analytics_service.dart';

class AuthTelemetryService {
  AuthTelemetryService._();

  static Future<void> trackLoginSuccess() {
    return AnalyticsService.instance.track(
      'auth_login_result',
      params: <String, Object>{'result': 'success'},
    );
  }

  static Future<void> trackLoginFailure({
    required String errorType,
    AuthFailureReason? reason,
  }) {
    return AnalyticsService.instance.track(
      'auth_login_result',
      params: <String, Object>{
        'result': 'failed',
        'error_type': errorType,
        'reason': reason?.name ?? AuthFailureReason.unknown.name,
      },
    );
  }

  static Future<void> trackRegisterSuccess() {
    return AnalyticsService.instance.track(
      'auth_register_result',
      params: <String, Object>{'result': 'success'},
    );
  }

  static Future<void> trackRegisterFailure({
    required String errorType,
    AuthFailureReason? reason,
  }) {
    return AnalyticsService.instance.track(
      'auth_register_result',
      params: <String, Object>{
        'result': 'failed',
        'error_type': errorType,
        'reason': reason?.name ?? AuthFailureReason.unknown.name,
      },
    );
  }

  static Future<void> trackSendCodeResult({
    required bool success,
    AuthFailureReason? reason,
  }) {
    return AnalyticsService.instance.track(
      'auth_send_code_result',
      params: <String, Object>{
        'result': success ? 'success' : 'failed',
        'reason': reason?.name ?? AuthFailureReason.unknown.name,
      },
    );
  }
}
```

- [ ] **Step 6: Refactor AuthController around BackendAuthRepository**

Replace `lib/features/auth/presentation/controllers/auth_controller.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/auth/data/auth_exceptions.dart';
import 'package:windwalker/features/auth/data/backend_auth_repository.dart';
import 'package:windwalker/models/app_user.dart';
import 'package:windwalker/services/analytics_service.dart';
import 'package:windwalker/services/auth_telemetry_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({required BackendAuthRepository repository})
      : _repository = repository {
    _init();
  }

  final BackendAuthRepository _repository;

  AppUser? _user;
  bool _isLoading = false;
  bool _isSendingCode = false;
  String? _errorMessage;
  DateTime? _nextCodeSendAt;

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isSendingCode => _isSendingCode;
  String? get errorMessage => _errorMessage;
  DateTime? get nextCodeSendAt => _nextCodeSendAt;

  Future<void> _init() async {
    AnalyticsService.instance.setUserProperty('is_anonymous', 'true');
    final cached = _repository.cachedSession;
    if (cached != null) {
      _user = AppUser(
        uid: cached.user.id.toString(),
        email: cached.user.email,
        displayName: cached.user.name,
        createdAt: cached.user.createdAt,
      );
      notifyListeners();
    }

    try {
      final restored = await _repository.restoreSession();
      _user = restored;
      if (restored != null) {
        await _syncSignedInProperties(uid: restored.uid);
      } else {
        await _syncSignedOutProperties();
      }
      notifyListeners();
    } catch (e, st) {
      Log.e('AuthController.restoreSession failed', error: e, stackTrace: st);
      _errorMessage = _messageForUnknown();
      notifyListeners();
    }
  }

  Future<void> sendRegisterCode({required String email}) async {
    _isSendingCode = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.sendRegisterCode(email: email.trim());
      _nextCodeSendAt = DateTime.now().add(const Duration(seconds: 60));
      await AuthTelemetryService.trackSendCodeResult(success: true);
    } on AuthException catch (e) {
      _errorMessage = _messageFor(e);
      await AuthTelemetryService.trackSendCodeResult(
        success: false,
        reason: e.reason,
      );
    } catch (e, st) {
      _errorMessage = _messageForUnknown();
      Log.e('sendRegisterCode failed', error: e, stackTrace: st);
      await AuthTelemetryService.trackSendCodeResult(success: false);
    } finally {
      _isSendingCode = false;
      notifyListeners();
    }
  }

  Future<void> loginWithPassword({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.loginWithPassword(
        email: email.trim(),
        password: password,
      );
      _user = user;
      await _syncSignedInProperties(uid: user.uid);
      await AuthTelemetryService.trackLoginSuccess();
    } on AuthException catch (e) {
      _errorMessage = _messageFor(e);
      await AuthTelemetryService.trackLoginFailure(
        errorType: 'auth_exception',
        reason: e.reason,
      );
    } catch (e, st) {
      _errorMessage = _messageForUnknown();
      Log.e('loginWithPassword failed', error: e, stackTrace: st);
      await AuthTelemetryService.trackLoginFailure(errorType: 'unknown');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.register(
        email: email.trim(),
        code: code.trim(),
        password: password,
        name: name,
      );
      _user = user;
      await _syncSignedInProperties(uid: user.uid);
      await AuthTelemetryService.trackRegisterSuccess();
    } on AuthException catch (e) {
      _errorMessage = _messageFor(e);
      await AuthTelemetryService.trackRegisterFailure(
        errorType: 'auth_exception',
        reason: e.reason,
      );
    } catch (e, st) {
      _errorMessage = _messageForUnknown();
      Log.e('register failed', error: e, stackTrace: st);
      await AuthTelemetryService.trackRegisterFailure(errorType: 'unknown');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.logout();
      _user = null;
      await _syncSignedOutProperties();
      await AnalyticsService.instance.track(
        'auth_logout_result',
        params: <String, Object>{'result': 'success'},
      );
    } catch (e, st) {
      _errorMessage = '退出登录失败，请重试';
      Log.e('signOut failed', error: e, stackTrace: st);
      await AnalyticsService.instance.track(
        'auth_logout_result',
        params: <String, Object>{'result': 'failed'},
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _syncSignedInProperties({required String uid}) async {
    await AnalyticsService.instance.setUserId(uid);
    await AnalyticsService.instance.setUserProperty('is_anonymous', 'false');
  }

  Future<void> _syncSignedOutProperties() async {
    await AnalyticsService.instance.setUserId(null);
    await AnalyticsService.instance.setUserProperty('is_anonymous', 'true');
    await AnalyticsService.instance.resetUserProperties();
  }

  String _messageFor(AuthException e) {
    switch (e.reason) {
      case AuthFailureReason.invalidCredentials:
        return '邮箱或密码错误';
      case AuthFailureReason.invalidCode:
        return '验证码无效或已过期';
      case AuthFailureReason.emailAlreadyRegistered:
        return '该邮箱已注册，请直接登录';
      case AuthFailureReason.rateLimited:
        return '验证码发送过于频繁，请稍后再试';
      case AuthFailureReason.sessionExpired:
        return '登录已过期，请重新登录';
      case AuthFailureReason.network:
        return '网络连接失败，请检查网络后重试';
      case AuthFailureReason.server:
        return '服务器暂时不可用，请稍后再试';
      case AuthFailureReason.unknown:
        return _messageForUnknown();
    }
  }

  String _messageForUnknown() => '操作失败，请重试';
}
```

- [ ] **Step 7: Rewrite AuthController tests**

Replace `test/unit/auth_controller_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/auth/data/auth_exceptions.dart';
import 'package:windwalker/features/auth/data/backend_auth_repository.dart';
import 'package:windwalker/features/auth/presentation/controllers/auth_controller.dart';
import 'package:windwalker/models/app_user.dart';

class FakeBackendAuthRepository implements BackendAuthRepository {
  AppUser? cachedUser;
  AppUser? restoreResult;
  AppUser loginResult = const AppUser(uid: '42', email: 'user@example.com');
  AppUser registerResult = const AppUser(uid: '43', email: 'new@example.com');
  Object? loginError;
  Object? registerError;
  Object? sendCodeError;
  bool logoutCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  get cachedSession => null;

  @override
  Future<AppUser?> restoreSession() async => restoreResult;

  @override
  Future<void> sendRegisterCode({required String email}) async {
    if (sendCodeError != null) throw sendCodeError!;
  }

  @override
  Future<AppUser> loginWithPassword({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return loginResult;
  }

  @override
  Future<AppUser> register({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    if (registerError != null) throw registerError!;
    return registerResult;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

void main() {
  test('loginWithPassword saves authenticated user', () async {
    final repo = FakeBackendAuthRepository();
    final controller = AuthController(repository: repo);
    await Future<void>.delayed(Duration.zero);

    await controller.loginWithPassword(
      email: 'user@example.com',
      password: 'P@ssw0rd123',
    );

    expect(controller.isAuthenticated, isTrue);
    expect(controller.user?.uid, '42');
    expect(controller.errorMessage, isNull);
  });

  test('loginWithPassword maps invalid credentials to message', () async {
    final repo = FakeBackendAuthRepository()
      ..loginError = const AuthException(
        reason: AuthFailureReason.invalidCredentials,
      );
    final controller = AuthController(repository: repo);
    await Future<void>.delayed(Duration.zero);

    await controller.loginWithPassword(
      email: 'user@example.com',
      password: 'bad',
    );

    expect(controller.isAuthenticated, isFalse);
    expect(controller.errorMessage, contains('密码'));
  });

  test('sendRegisterCode sets resend timestamp', () async {
    final repo = FakeBackendAuthRepository();
    final controller = AuthController(repository: repo);
    await Future<void>.delayed(Duration.zero);

    await controller.sendRegisterCode(email: 'new@example.com');

    expect(controller.isSendingCode, isFalse);
    expect(controller.nextCodeSendAt, isNotNull);
  });

  test('register saves authenticated user', () async {
    final repo = FakeBackendAuthRepository();
    final controller = AuthController(repository: repo);
    await Future<void>.delayed(Duration.zero);

    await controller.register(
      email: 'new@example.com',
      code: '123456',
      password: 'P@ssw0rd123',
      name: 'Alice',
    );

    expect(controller.user?.uid, '43');
    expect(controller.user?.email, 'new@example.com');
  });

  test('signOut clears user', () async {
    final repo = FakeBackendAuthRepository();
    final controller = AuthController(repository: repo);
    await Future<void>.delayed(Duration.zero);
    await controller.loginWithPassword(
      email: 'user@example.com',
      password: 'P@ssw0rd123',
    );

    await controller.signOut();

    expect(controller.isAuthenticated, isFalse);
    expect(repo.logoutCalled, isTrue);
  });
}
```

- [ ] **Step 8: Run Task 2 tests**

Run:

```bash
flutter test \
  test/unit/features/auth/backend_auth_repository_test.dart \
  test/unit/auth_controller_test.dart
```

Expected: tests pass.

- [ ] **Step 9: Commit Task 2**

Run:

```bash
git add \
  lib/features/auth/data/app_backend_auth_api.dart \
  lib/features/auth/data/backend_auth_repository.dart \
  lib/features/auth/presentation/controllers/auth_controller.dart \
  lib/services/auth_telemetry_service.dart \
  test/unit/features/auth/backend_auth_repository_test.dart \
  test/unit/auth_controller_test.dart
git commit -m "feat(auth): add backend auth repository and controller"
```

---

## Task 3: Auth UI, Provider Wiring, and Google Auth Cleanup

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`
- Modify: `lib/core/config/auth_provider_factory.dart`
- Create: `lib/core/config/backend_auth_config.dart`
- Modify: `lib/features/auth/presentation/pages/login_page.dart`
- Modify: `lib/features/home/presentation/pages/profile_tab.dart`
- Delete: `lib/services/firebase_auth_provider.dart`
- Delete: `lib/services/auth_provider.dart`
- Modify: `pubspec.yaml`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_ja.arb`
- Test: `test/widget/login_page_test.dart`

- [ ] **Step 1: Write failing login page widget tests**

Replace `test/widget/login_page_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/features/auth/data/backend_auth_repository.dart';
import 'package:windwalker/features/auth/presentation/controllers/auth_controller.dart';
import 'package:windwalker/features/auth/presentation/pages/login_page.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/app_user.dart';

class FakeAuthRepository implements BackendAuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  get cachedSession => null;

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<void> sendRegisterCode({required String email}) async {}

  @override
  Future<AppUser> loginWithPassword({
    required String email,
    required String password,
  }) async {
    return AppUser(uid: '42', email: email);
  }

  @override
  Future<AppUser> register({
    required String email,
    required String code,
    required String password,
    String? name,
  }) async {
    return AppUser(uid: '43', email: email, displayName: name);
  }
}

void main() {
  testWidgets('Login page defaults to email password login', (tester) async {
    await tester.pumpWidget(_createLoginTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets('Login page switches to registration mode', (tester) async {
    await tester.pumpWidget(_createLoginTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    expect(find.text('Verification code'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });
}

Widget _createLoginTestApp() {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    ],
  );

  return ChangeNotifierProvider<AuthController>.value(
    value: AuthController(repository: FakeAuthRepository()),
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
      locale: const Locale('en'),
    ),
  );
}
```

- [ ] **Step 2: Run login page tests and verify they fail**

Run:

```bash
flutter test test/widget/login_page_test.dart
```

Expected: fails because the page still renders Google login.

- [ ] **Step 3: Add l10n keys**

Modify `lib/l10n/app_en.arb` by replacing Google auth strings and adding WebDAV-neutral auth strings near existing login keys:

```json
  "email": "Email",
  "password": "Password",
  "confirmPassword": "Confirm password",
  "verificationCode": "Verification code",
  "sendCode": "Send code",
  "register": "Register",
  "alreadyHaveAccount": "Already have an account?",
  "createAccount": "Create account",
  "nicknameOptional": "Nickname (optional)",
  "signIn": "Sign in",
  "passwordsDoNotMatch": "Passwords do not match",
```

Modify `lib/l10n/app_zh.arb` with:

```json
  "email": "邮箱",
  "password": "密码",
  "confirmPassword": "确认密码",
  "verificationCode": "验证码",
  "sendCode": "发送验证码",
  "register": "注册",
  "alreadyHaveAccount": "已有账号？",
  "createAccount": "创建账号",
  "nicknameOptional": "昵称（可选）",
  "signIn": "登录",
  "passwordsDoNotMatch": "两次输入的密码不一致",
```

Modify `lib/l10n/app_ja.arb` with:

```json
  "email": "メール",
  "password": "パスワード",
  "confirmPassword": "パスワード確認",
  "verificationCode": "確認コード",
  "sendCode": "コードを送信",
  "register": "登録",
  "alreadyHaveAccount": "すでにアカウントがありますか？",
  "createAccount": "アカウントを作成",
  "nicknameOptional": "ニックネーム（任意）",
  "signIn": "サインイン",
  "passwordsDoNotMatch": "パスワードが一致しません",
```

Then run:

```bash
flutter gen-l10n
```

Expected: generated `lib/l10n/app_localizations*.dart` files include the new getters.

- [ ] **Step 4: Replace LoginPage with email/password and register forms**

Replace `lib/features/auth/presentation/pages/login_page.dart` with a stateful page. The core submit methods must be:

```dart
Future<void> _submitLogin(AuthController auth) async {
  await auth.loginWithPassword(
    email: _emailController.text,
    password: _passwordController.text,
  );
}

Future<void> _sendCode(AuthController auth) async {
  await auth.sendRegisterCode(email: _emailController.text);
}

Future<void> _submitRegister(AuthController auth) async {
  if (_passwordController.text != _confirmPasswordController.text) {
    setState(() => _localError = AppLocalizations.of(context)!.passwordsDoNotMatch);
    return;
  }
  await auth.register(
    email: _emailController.text,
    code: _codeController.text,
    password: _passwordController.text,
    name: _nameController.text,
  );
}
```

The page structure should keep the existing `NeoPageHeader`, `NeoCard`, `NeoInputShell`, and `NeoButton` styling. Use a segmented `ToggleButtons` or two compact `NeoButton` controls for login/register mode. Use `TextField` widgets inside `NeoInputShell` with labels from l10n. Navigate home with the existing `context.go('/')` post-frame behavior when authenticated.

- [ ] **Step 5: Wire AuthController in app.dart**

Create `lib/core/config/backend_auth_config.dart`:

```dart
class BackendAuthConfig {
  BackendAuthConfig._();

  static const baseUrl = 'https://appapi.51cloud.de';
  static const appId = 'windwalker';
  static const appKey = 'windwalker-app-key';
}
```

In `lib/app.dart`, add imports:

```dart
import 'package:http/http.dart' as http;
import 'package:windwalker/core/config/backend_auth_config.dart';
import 'package:windwalker/features/auth/data/app_backend_auth_api.dart';
import 'package:windwalker/features/auth/data/auth_token_store.dart';
import 'package:windwalker/features/auth/data/backend_auth_repository.dart';
```

Replace the auth provider creation with:

```dart
ChangeNotifierProvider(
  create: (_) => AuthController(
    repository: BackendAuthRepository(
      api: AppBackendAuthApi(
        baseUrl: Uri.parse(BackendAuthConfig.baseUrl),
        appId: BackendAuthConfig.appId,
        appKey: BackendAuthConfig.appKey,
        httpClient: http.Client(),
      ),
      tokenStore: AuthTokenStore(),
    ),
  ),
),
```

Before execution against the production backend, confirm `BackendAuthConfig.appKey` equals the app key configured for the `windwalker` backend application.

- [ ] **Step 6: Remove Firebase Auth startup**

Modify `lib/main.dart`:

Remove:

```dart
import 'package:firebase_auth/firebase_auth.dart';
```

Remove:

```dart
await FirebaseAuth.instance.setLanguageCode('en');
```

Keep `Firebase.initializeApp()` because Firebase Analytics still uses Firebase Core.

- [ ] **Step 7: Remove Google auth files and dependencies**

Run:

```bash
rm lib/services/firebase_auth_provider.dart lib/services/auth_provider.dart
```

Modify `pubspec.yaml` to remove:

```yaml
  firebase_auth: ^6.5.3
  google_sign_in: ^7.2.0
```

Run:

```bash
flutter pub get
```

Expected: `pubspec.lock` updates and no code imports `firebase_auth` or `google_sign_in`.

- [ ] **Step 8: Verify no Google auth references remain**

Run:

```bash
rg -n "FirebaseAuthProvider|firebase_auth|google_sign_in|signInWithGoogle|authorizeScopes|authorizationHeaders|AuthProvider" lib test pubspec.yaml
```

Expected: no matches except deleted-file references in git history are not shown by `rg`.

- [ ] **Step 9: Run Task 3 tests**

Run:

```bash
flutter test test/widget/login_page_test.dart test/unit/auth_controller_test.dart
```

Expected: tests pass.

- [ ] **Step 10: Commit Task 3**

Run:

```bash
git add \
  lib/app.dart \
  lib/main.dart \
  lib/core/config/auth_provider_factory.dart \
  lib/core/config/backend_auth_config.dart \
  lib/features/auth/presentation/pages/login_page.dart \
  lib/features/home/presentation/pages/profile_tab.dart \
  lib/l10n \
  pubspec.yaml \
  pubspec.lock \
  test/widget/login_page_test.dart \
  test/unit/auth_controller_test.dart
git add -u lib/services/firebase_auth_provider.dart lib/services/auth_provider.dart
git commit -m "feat(auth): replace google sign-in with backend auth ui"
```

---

## Task 4: WebDAV Config Store and Storage API

**Files:**
- Create: `lib/features/backup/data/backup_exceptions.dart`
- Create: `lib/features/backup/data/backup_storage_api.dart`
- Create: `lib/features/backup/data/webdav_config.dart`
- Create: `lib/features/backup/data/webdav_config_store.dart`
- Create: `lib/features/backup/data/webdav_backup_storage_api.dart`
- Test: `test/unit/features/backup/webdav_config_store_test.dart`
- Test: `test/unit/features/backup/webdav_backup_storage_api_test.dart`

- [ ] **Step 1: Write failing WebDAV config store tests**

Create `test/unit/features/backup/webdav_config_store_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';
import 'package:windwalker/features/backup/data/webdav_config_store.dart';

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
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return '/tmp/test_windwalker';
        }
        return null;
      },
    );
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
  });

  test('save and read WebDAV config', () async {
    final store = WebDavConfigStore(storage: GetStorage());
    const config = WebDavConfig(
      baseUrl: 'https://example.com/dav/',
      remoteDirectory: 'WindWalker/Backups',
      username: 'alice',
      password: 'app-token',
    );

    await store.save(config);

    expect(store.read(), config);
  });

  test('clear removes config', () async {
    final store = WebDavConfigStore(storage: GetStorage());
    await store.save(
      const WebDavConfig(
        baseUrl: 'https://example.com/dav/',
        remoteDirectory: 'WindWalker/Backups',
        username: 'alice',
        password: 'app-token',
      ),
    );

    await store.clear();

    expect(store.read(), isNull);
  });
}
```

- [ ] **Step 2: Write failing WebDAV storage tests**

Create `test/unit/features/backup/webdav_backup_storage_api_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/backup/data/backup_exceptions.dart';
import 'package:windwalker/features/backup/data/webdav_backup_storage_api.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';

void main() {
  group('WebDavBackupStorageApi', () {
    test('listVersions parses PROPFIND and downloads matching JSON metadata', () async {
      final requests = <String>[];
      final api = WebDavBackupStorageApi(
        config: const WebDavConfig(
          baseUrl: 'https://example.com/dav/',
          remoteDirectory: 'WindWalker/Backups',
          username: 'alice',
          password: 'token',
        ),
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url}');
          expect(request.headers['Authorization'], startsWith('Basic '));
          if (request.method == 'PROPFIND') {
            return http.Response('''
<?xml version="1.0" encoding="utf-8" ?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/WindWalker/Backups/windwalker_downloaders_backup_2026-07-04T12-30-15Z.json</d:href>
    <d:propstat><d:prop><d:getlastmodified>Sat, 04 Jul 2026 12:30:15 GMT</d:getlastmodified></d:prop></d:propstat>
  </d:response>
</d:multistatus>
''', 207);
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'schemaVersion': 1,
                'backupId': 'backup-1',
                'createdAt': '2026-07-04T12:30:15Z',
                'appVersion': '1.1.1',
                'user': {'uid': '42'},
                'downloaders': [],
              }),
              200,
            );
          }
          return http.Response('unexpected', 500);
        }),
      );

      final versions = await api.listVersions();

      expect(versions, hasLength(1));
      expect(versions.first.backupId, 'backup-1');
      expect(versions.first.downloaderCount, 0);
      expect(requests.first, startsWith('PROPFIND'));
      expect(requests.last, startsWith('GET'));
    });

    test('uploadBackup sends PUT with bundle JSON', () async {
      final api = WebDavBackupStorageApi(
        config: const WebDavConfig(
          baseUrl: 'https://example.com/dav/',
          remoteDirectory: 'WindWalker/Backups',
          username: 'alice',
          password: 'token',
        ),
        httpClient: MockClient((request) async {
          if (request.method == 'PROPFIND') return http.Response('', 207);
          if (request.method == 'PUT') {
            expect(request.url.path, contains('windwalker_downloaders_backup_'));
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['backupId'], 'backup-1');
            return http.Response('', 201);
          }
          return http.Response('', 500);
        }),
      );

      await api.uploadBackup(
        DownloaderBackupBundle(
          schemaVersion: 1,
          backupId: 'backup-1',
          createdAt: DateTime.parse('2026-07-04T12:30:15Z'),
          appVersion: '1.1.1',
          userUid: '42',
          downloaders: [
            Downloader(
              id: 'd1',
              name: 'Local',
              type: DownloaderType.aria2,
              host: 'localhost',
              port: 6800,
            ),
          ],
        ),
      );
    });

    test('deleteBackup maps 401 to unauthorized', () async {
      final api = WebDavBackupStorageApi(
        config: const WebDavConfig(
          baseUrl: 'https://example.com/dav/',
          remoteDirectory: 'WindWalker/Backups',
          username: 'alice',
          password: 'token',
        ),
        httpClient: MockClient((request) async {
          return http.Response('unauthorized', 401);
        }),
      );

      expect(
        () => api.deleteBackup('https://example.com/dav/WindWalker/Backups/b.json'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.reason,
            'reason',
            BackupFailureReason.unauthorized,
          ),
        ),
      );
    });
  });
}
```

- [ ] **Step 3: Run WebDAV tests and verify they fail**

Run:

```bash
flutter test \
  test/unit/features/backup/webdav_config_store_test.dart \
  test/unit/features/backup/webdav_backup_storage_api_test.dart
```

Expected: fails because backup data files do not exist.

- [ ] **Step 4: Implement backup exceptions and storage interface**

Create `lib/features/backup/data/backup_exceptions.dart`:

```dart
enum BackupFailureReason {
  notConfigured,
  unauthorized,
  forbidden,
  notFound,
  directoryCreateFailed,
  uploadFailed,
  downloadFailed,
  deleteFailed,
  parseFailed,
  network,
  server,
}

class BackupException implements Exception {
  const BackupException({
    required this.reason,
    this.statusCode,
    this.message,
  });

  final BackupFailureReason reason;
  final int? statusCode;
  final String? message;

  @override
  String toString() {
    final statusText = statusCode == null ? '' : ', status=$statusCode';
    final messageText = message == null ? '' : ', message=$message';
    return 'BackupException(reason=$reason$statusText$messageText)';
  }
}

class BackupPartialSuccessException implements Exception {
  const BackupPartialSuccessException({
    required this.warning,
    required this.cause,
  });

  final String warning;
  final Object cause;
}
```

Create `lib/features/backup/data/backup_storage_api.dart`:

```dart
import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/models/downloader_backup_version.dart';

abstract class BackupStorageApi {
  Future<List<DownloaderBackupVersion>> listVersions();

  Future<void> uploadBackup(DownloaderBackupBundle bundle);

  Future<List<int>> downloadBackup(String versionId);

  Future<void> deleteBackup(String versionId);
}
```

- [ ] **Step 5: Implement WebDAV config and store**

Create `lib/features/backup/data/webdav_config.dart`:

```dart
class WebDavConfig {
  const WebDavConfig({
    required this.baseUrl,
    required this.remoteDirectory,
    required this.username,
    required this.password,
  });

  final String baseUrl;
  final String remoteDirectory;
  final String username;
  final String password;

  factory WebDavConfig.fromJson(Map<String, dynamic> json) {
    return WebDavConfig(
      baseUrl: json['baseUrl'] as String,
      remoteDirectory: json['remoteDirectory'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'remoteDirectory': remoteDirectory,
        'username': username,
        'password': password,
      };

  bool get isComplete =>
      baseUrl.trim().isNotEmpty &&
      remoteDirectory.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is WebDavConfig &&
        other.baseUrl == baseUrl &&
        other.remoteDirectory == remoteDirectory &&
        other.username == username &&
        other.password == password;
  }

  @override
  int get hashCode => Object.hash(baseUrl, remoteDirectory, username, password);
}
```

Create `lib/features/backup/data/webdav_config_store.dart`:

```dart
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';

class WebDavConfigStore {
  WebDavConfigStore({GetStorage? storage}) : _storage = storage ?? GetStorage();

  static const _key = 'webdav_backup_config';

  final GetStorage _storage;

  WebDavConfig? read() {
    final json = _storage.read<Map>(_key);
    if (json == null) return null;
    return WebDavConfig.fromJson(Map<String, dynamic>.from(json));
  }

  Future<void> save(WebDavConfig config) {
    return _storage.write(_key, config.toJson());
  }

  Future<void> clear() {
    return _storage.remove(_key);
  }
}
```

- [ ] **Step 6: Implement WebDAV storage API**

Create `lib/features/backup/data/webdav_backup_storage_api.dart` with methods matching the tests. Include these helpers exactly:

```dart
String buildBackupFileName(DateTime createdAtUtc) {
  final iso = createdAtUtc.toUtc().toIso8601String().replaceAll(':', '-');
  return 'windwalker_downloaders_backup_${iso.replaceAll('.000', '')}.json';
}

Map<String, String> _headers({String? contentType}) {
  final credentials = base64Encode(
    utf8.encode('${_config.username}:${_config.password}'),
  );
  return {
    'Authorization': 'Basic $credentials',
    if (contentType != null) 'Content-Type': contentType,
  };
}
```

The public class shape must be:

```dart
class WebDavBackupStorageApi implements BackupStorageApi {
  WebDavBackupStorageApi({
    required WebDavConfig config,
    required http.Client httpClient,
  })  : _config = config,
        _httpClient = httpClient;

  final WebDavConfig _config;
  final http.Client _httpClient;

  Future<void> testConnection() async {
    await _ensureDirectory();
  }

  @override
  Future<List<DownloaderBackupVersion>> listVersions() async {
    await _ensureDirectory();
    final hrefs = await _propfindBackupHrefs();
    final versions = <DownloaderBackupVersion>[];
    for (final href in hrefs) {
      final bytes = await downloadBackup(href);
      final bundle = DownloaderBackupBundle.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
      versions.add(
        DownloaderBackupVersion(
          fileId: href,
          fileName: Uri.parse(href).pathSegments.last,
          backupId: bundle.backupId,
          createdAt: bundle.createdAt,
          appVersion: bundle.appVersion,
          downloaderCount: bundle.downloaders.length,
          isLatest: false,
        ),
      );
    }
    versions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (versions.isEmpty) return versions;
    return [
      DownloaderBackupVersion(
        fileId: versions.first.fileId,
        fileName: versions.first.fileName,
        backupId: versions.first.backupId,
        createdAt: versions.first.createdAt,
        appVersion: versions.first.appVersion,
        downloaderCount: versions.first.downloaderCount,
        isLatest: true,
      ),
      for (final version in versions.skip(1)) version,
    ];
  }

  @override
  Future<void> uploadBackup(DownloaderBackupBundle bundle) async {
    await _ensureDirectory();
    final uri = _fileUri(buildBackupFileName(bundle.createdAt));
    final response = await _send(
      () => _httpClient.put(
        uri,
        headers: _headers(contentType: 'application/json'),
        body: jsonEncode(bundle.toJson()),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionFor(response, BackupFailureReason.uploadFailed);
    }
  }

  @override
  Future<List<int>> downloadBackup(String versionId) async {
    final response = await _send(
      () => _httpClient.get(Uri.parse(versionId), headers: _headers()),
    );
    if (response.statusCode != 200) {
      throw _exceptionFor(response, BackupFailureReason.downloadFailed);
    }
    return response.bodyBytes;
  }

  @override
  Future<void> deleteBackup(String versionId) async {
    final response = await _send(
      () => _httpClient.delete(Uri.parse(versionId), headers: _headers()),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionFor(response, BackupFailureReason.deleteFailed);
    }
  }
}
```

Implementation requirements:

- Use `http.Request('PROPFIND', uri)` with header `Depth: 1`.
- Treat status `207` as successful PROPFIND.
- Treat `200`, `201`, `204`, and `207` as successful directory checks when appropriate.
- Use `http.Request('MKCOL', uri)` for missing directory segments.
- Parse `<d:href>` values with `RegExp(r'<[^:>]*:?href>([^<]+)</[^>]+>')`.
- Filter hrefs containing `windwalker_downloaders_backup_` and ending in `.json`.
- Download each matching href with `GET`, parse `DownloaderBackupBundle.fromJson`, and create `DownloaderBackupVersion`.
- Map 401 to `unauthorized`, 403 to `forbidden`, 404 to `notFound`, 5xx to `server`.

- [ ] **Step 7: Run Task 4 tests**

Run:

```bash
flutter test \
  test/unit/features/backup/webdav_config_store_test.dart \
  test/unit/features/backup/webdav_backup_storage_api_test.dart
```

Expected: tests pass.

- [ ] **Step 8: Commit Task 4**

Run:

```bash
git add \
  lib/features/backup/data/backup_exceptions.dart \
  lib/features/backup/data/backup_storage_api.dart \
  lib/features/backup/data/webdav_config.dart \
  lib/features/backup/data/webdav_config_store.dart \
  lib/features/backup/data/webdav_backup_storage_api.dart \
  test/unit/features/backup/webdav_config_store_test.dart \
  test/unit/features/backup/webdav_backup_storage_api_test.dart
git commit -m "feat(backup): add webdav storage api"
```

---

## Task 5: Downloader Backup Repository with Retention and Manual Delete

**Files:**
- Create: `lib/features/backup/data/downloader_backup_repository.dart`
- Modify: `lib/services/downloader_backup_service.dart`
- Test: `test/unit/features/backup/downloader_backup_repository_test.dart`
- Modify: `test/unit/services/downloader_backup_service_test.dart`
- Delete or replace: `test/unit/services/google_drive_backup_api_test.dart`

- [ ] **Step 1: Write failing repository tests**

Create `test/unit/features/backup/downloader_backup_repository_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/backup/data/backup_exceptions.dart';
import 'package:windwalker/features/backup/data/backup_storage_api.dart';
import 'package:windwalker/features/backup/data/downloader_backup_repository.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/models/app_user.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/models/downloader_backup_version.dart';

class FakeBackupStorageApi implements BackupStorageApi {
  List<DownloaderBackupVersion> versions = const [];
  DownloaderBackupBundle? uploaded;
  List<int> downloadedBytes = const [];
  Object? deleteError;
  final deleted = <String>[];

  @override
  Future<List<DownloaderBackupVersion>> listVersions() async => versions;

  @override
  Future<void> uploadBackup(DownloaderBackupBundle bundle) async {
    uploaded = bundle;
  }

  @override
  Future<List<int>> downloadBackup(String versionId) async => downloadedBytes;

  @override
  Future<void> deleteBackup(String versionId) async {
    if (deleteError != null) throw deleteError!;
    deleted.add(versionId);
  }
}

Downloader _downloader(String id) {
  return Downloader(
    id: id,
    name: id,
    type: DownloaderType.aria2,
    host: 'localhost',
    port: 6800,
  );
}

DownloaderBackupVersion _version(String id, String createdAt) {
  return DownloaderBackupVersion(
    fileId: id,
    fileName: '$id.json',
    backupId: id,
    createdAt: DateTime.parse(createdAt),
    appVersion: '1.0.0',
    downloaderCount: 1,
    isLatest: false,
  );
}

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
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return '/tmp/test_windwalker';
        }
        return null;
      },
    );
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
  });

  test('exportBackup uploads bundle and deletes versions beyond newest two', () async {
    final storage = FakeBackupStorageApi()
      ..versions = [
        _version('oldest', '2026-07-01T00:00:00Z'),
        _version('middle', '2026-07-02T00:00:00Z'),
        _version('newest', '2026-07-03T00:00:00Z'),
      ];
    final downloaderController = DownloaderController();
    downloaderController.setTestDownloadersForTest([_downloader('d1')]);
    final repo = DownloaderBackupRepository(
      storageApi: storage,
      downloaderController: downloaderController,
      currentUser: () => const AppUser(uid: '42'),
      currentAppVersion: () async => '1.1.1',
    );

    await repo.exportBackup();

    expect(storage.uploaded?.userUid, '42');
    expect(storage.uploaded?.downloaders.single.id, 'd1');
    expect(storage.deleted, ['oldest']);
  });

  test('restoreBackup replaces downloaders through controller', () async {
    final storage = FakeBackupStorageApi();
    storage.downloadedBytes = utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'backupId': 'backup-1',
        'createdAt': '2026-07-04T12:30:15Z',
        'appVersion': '1.1.1',
        'user': {'uid': '42'},
        'downloaders': [_downloader('restored').toJson()],
      }),
    );
    final downloaderController = DownloaderController();
    downloaderController.setTestDownloadersForTest([_downloader('old')]);
    final repo = DownloaderBackupRepository(
      storageApi: storage,
      downloaderController: downloaderController,
      currentUser: () => const AppUser(uid: '42'),
      currentAppVersion: () async => '1.1.1',
    );

    await repo.restoreBackup(versionId: 'file-1');

    expect(downloaderController.downloaders.single.id, 'restored');
  });

  test('deleteBackup delegates to storage', () async {
    final storage = FakeBackupStorageApi();
    final repo = DownloaderBackupRepository(
      storageApi: storage,
      downloaderController: DownloaderController(),
      currentUser: () => const AppUser(uid: '42'),
      currentAppVersion: () async => '1.1.1',
    );

    await repo.deleteBackup(versionId: 'file-1');

    expect(storage.deleted, ['file-1']);
  });

  test('exportBackup surfaces cleanup failure as partial success', () async {
    final storage = FakeBackupStorageApi()
      ..versions = [
        _version('oldest', '2026-07-01T00:00:00Z'),
        _version('middle', '2026-07-02T00:00:00Z'),
        _version('newest', '2026-07-03T00:00:00Z'),
      ]
      ..deleteError = const BackupException(
        reason: BackupFailureReason.deleteFailed,
      );
    final downloaderController = DownloaderController();
    downloaderController.setTestDownloadersForTest([_downloader('d1')]);
    final repo = DownloaderBackupRepository(
      storageApi: storage,
      downloaderController: downloaderController,
      currentUser: () => const AppUser(uid: '42'),
      currentAppVersion: () async => '1.1.1',
    );

    expect(
      repo.exportBackup,
      throwsA(isA<BackupPartialSuccessException>()),
    );
    expect(storage.uploaded, isNotNull);
  });
}
```

- [ ] **Step 2: Run repository tests and verify they fail**

Run:

```bash
flutter test test/unit/features/backup/downloader_backup_repository_test.dart
```

Expected: fails because `DownloaderBackupRepository` does not exist.

- [ ] **Step 3: Implement DownloaderBackupRepository**

Create `lib/features/backup/data/downloader_backup_repository.dart`:

```dart
import 'dart:convert';

import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/backup/data/backup_exceptions.dart';
import 'package:windwalker/features/backup/data/backup_storage_api.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/models/app_user.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/models/downloader_backup_version.dart';
import 'package:windwalker/services/analytics_service.dart';

class DownloaderBackupRepository {
  DownloaderBackupRepository({
    required BackupStorageApi storageApi,
    required DownloaderController downloaderController,
    required AppUser Function() currentUser,
    required Future<String> Function() currentAppVersion,
  })  : _storageApi = storageApi,
        _downloaderController = downloaderController,
        _currentUser = currentUser,
        _currentAppVersion = currentAppVersion;

  final BackupStorageApi _storageApi;
  final DownloaderController _downloaderController;
  final AppUser Function() _currentUser;
  final Future<String> Function() _currentAppVersion;

  AnalyticsService get analyticsService => AnalyticsService.instance;

  Future<List<DownloaderBackupVersion>> listVersions() {
    return _storageApi.listVersions();
  }

  Future<void> exportBackup() async {
    final now = DateTime.now().toUtc();
    final bundle = DownloaderBackupBundle(
      schemaVersion: DownloaderBackupBundle.supportedSchemaVersion,
      backupId: _buildBackupId(now),
      createdAt: now,
      appVersion: await _currentAppVersion(),
      userUid: _currentUser().uid,
      downloaders: _downloaderController.downloaders,
    );

    try {
      await _storageApi.uploadBackup(bundle);
      await _cleanupOldVersions();
      await analyticsService.track(
        'downloader_backup_export_result',
        params: <String, Object>{
          'result': 'success',
          'downloader_count': bundle.downloaders.length,
        },
      );
    } catch (e) {
      if (e is BackupPartialSuccessException) {
        await analyticsService.track(
          'downloader_backup_export_result',
          params: <String, Object>{'result': 'partial_success'},
        );
      } else {
        await analyticsService.track(
          'downloader_backup_export_result',
          params: <String, Object>{'result': 'failure'},
        );
      }
      rethrow;
    }
  }

  Future<void> restoreBackup({required String versionId}) async {
    try {
      final bytes = await _storageApi.downloadBackup(versionId);
      final bundle = DownloaderBackupBundle.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
      await _downloaderController.replaceAllDownloadersFromBackup(
        downloaders: bundle.downloaders,
        sourceBackupId: bundle.backupId,
      );
      await analyticsService.track(
        'downloader_backup_import_result',
        params: <String, Object>{
          'result': 'success',
          'downloader_count': bundle.downloaders.length,
        },
      );
    } catch (e) {
      await analyticsService.track(
        'downloader_backup_import_result',
        params: <String, Object>{'result': 'failure'},
      );
      rethrow;
    }
  }

  Future<void> deleteBackup({required String versionId}) async {
    try {
      await _storageApi.deleteBackup(versionId);
      await analyticsService.track(
        'downloader_backup_delete_result',
        params: <String, Object>{'result': 'success'},
      );
    } catch (e) {
      await analyticsService.track(
        'downloader_backup_delete_result',
        params: <String, Object>{'result': 'failure'},
      );
      rethrow;
    }
  }

  Future<void> _cleanupOldVersions() async {
    final versions = await _storageApi.listVersions();
    final sorted = List<DownloaderBackupVersion>.from(versions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final deletions = sorted.skip(2).toList();
    try {
      for (final version in deletions) {
        await _storageApi.deleteBackup(version.fileId);
      }
    } catch (e, st) {
      Log.e('Backup cleanup failed', error: e, stackTrace: st);
      throw BackupPartialSuccessException(
        warning: '备份成功，但旧版本清理失败',
        cause: e,
      );
    }
  }

  static String _buildBackupId(DateTime now) {
    final iso = now.toUtc().toIso8601String().replaceAll(':', '');
    final suffix =
        (now.microsecondsSinceEpoch % 100000).toString().padLeft(5, '0');
    return '${iso}_$suffix';
  }
}
```

- [ ] **Step 4: Run repository tests**

Run:

```bash
flutter test test/unit/features/backup/downloader_backup_repository_test.dart
```

Expected: tests pass.

- [ ] **Step 5: Verify the new repository has no Google Drive dependency**

Run:

```bash
rg -n "GoogleDriveBackupApi|DriveAuthException|drive.appdata" lib/features/backup test/unit/features/backup
```

Expected: no matches. Keep legacy Google Drive files in `lib/services/` until Task 8, after `app.dart` no longer imports them.

- [ ] **Step 6: Replace old service tests**

Remove obsolete Drive-specific tests:

```bash
rm test/unit/services/google_drive_backup_api_test.dart
```

Remove the old service orchestration test because rollback and retention assertions now live in `test/unit/features/backup/downloader_backup_repository_test.dart`:

```bash
rm test/unit/services/downloader_backup_service_test.dart
```

- [ ] **Step 7: Run affected backup tests**

Run:

```bash
flutter test test/unit/features/backup/downloader_backup_repository_test.dart
```

Expected: tests pass and no removed test file is referenced by imports.

- [ ] **Step 8: Commit Task 5**

Run:

```bash
git add \
  lib/features/backup/data/downloader_backup_repository.dart \
  test/unit/features/backup/downloader_backup_repository_test.dart
git add -u \
  lib/services/downloader_backup_service.dart \
  test/unit/services/google_drive_backup_api_test.dart \
  test/unit/services/downloader_backup_service_test.dart
git commit -m "feat(backup): add downloader backup repository"
```

---

## Task 6: Settings Backup Controller and Provider Wiring

**Files:**
- Modify: `lib/features/settings/presentation/controllers/settings_backup_controller.dart`
- Modify: `lib/app.dart`
- Test: `test/unit/features/settings/settings_backup_controller_test.dart`

- [ ] **Step 1: Write failing SettingsBackupController tests**

Replace `test/unit/features/settings/settings_backup_controller_test.dart` with tests covering configured and deletion states:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/backup/data/backup_exceptions.dart';
import 'package:windwalker/features/backup/data/downloader_backup_repository.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';
import 'package:windwalker/features/backup/data/webdav_config_store.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_backup_controller.dart';
import 'package:windwalker/models/downloader_backup_version.dart';

class FakeBackupRepository implements DownloaderBackupRepository {
  List<DownloaderBackupVersion> versions = const [];
  Object? exportError;
  Object? deleteError;
  String? deletedId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<DownloaderBackupVersion>> listVersions() async => versions;

  @override
  Future<void> exportBackup() async {
    if (exportError != null) throw exportError!;
  }

  @override
  Future<void> restoreBackup({required String versionId}) async {}

  @override
  Future<void> deleteBackup({required String versionId}) async {
    if (deleteError != null) throw deleteError!;
    deletedId = versionId;
  }
}

class MemoryWebDavConfigStore implements WebDavConfigStore {
  WebDavConfig? config;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  WebDavConfig? read() => config;

  @override
  Future<void> save(WebDavConfig config) async {
    this.config = config;
  }

  @override
  Future<void> clear() async {
    config = null;
  }
}

DownloaderBackupVersion _version(String id) {
  return DownloaderBackupVersion(
    fileId: id,
    fileName: '$id.json',
    backupId: id,
    createdAt: DateTime.parse('2026-07-04T12:00:00Z'),
    appVersion: '1.0.0',
    downloaderCount: 1,
    isLatest: true,
  );
}

void main() {
  test('hasWebDavConfig reflects store state', () {
    final store = MemoryWebDavConfigStore();
    final controller = SettingsBackupController(configStore: store);

    expect(controller.hasWebDavConfig, isFalse);

    store.config = const WebDavConfig(
      baseUrl: 'https://example.com/dav/',
      remoteDirectory: 'WindWalker/Backups',
      username: 'alice',
      password: 'token',
    );
    controller.reloadConfig();

    expect(controller.hasWebDavConfig, isTrue);
  });

  test('deleteBackupVersion toggles deleting state and refreshes versions', () async {
    final repo = FakeBackupRepository()..versions = [_version('file-1')];
    final controller = SettingsBackupController(
      backupRepository: repo,
      configStore: MemoryWebDavConfigStore(),
    );

    await controller.deleteBackupVersion(versionId: 'file-1');

    expect(repo.deletedId, 'file-1');
    expect(controller.isDeletingVersion, isFalse);
    expect(controller.deletingVersionId, isNull);
    expect(controller.availableBackups, hasLength(1));
  });

  test('export partial success sets cleanup warning summary', () async {
    final repo = FakeBackupRepository()
      ..exportError = BackupPartialSuccessException(
        warning: '备份成功，但旧版本清理失败',
        cause: Exception('delete failed'),
      );
    final controller = SettingsBackupController(
      backupRepository: repo,
      configStore: MemoryWebDavConfigStore(),
    );

    await controller.exportBackup();

    expect(controller.errorMessage, isNull);
    expect(controller.lastOperationSummary, contains('清理失败'));
  });
}
```

- [ ] **Step 2: Run controller tests and verify they fail**

Run:

```bash
flutter test test/unit/features/settings/settings_backup_controller_test.dart
```

Expected: fails because controller constructor and delete state do not exist.

- [ ] **Step 3: Refactor SettingsBackupController**

Replace `lib/features/settings/presentation/controllers/settings_backup_controller.dart` with a controller that includes these fields and methods:

```dart
bool _isDeletingVersion = false;
String? _deletingVersionId;
WebDavConfig? _webDavConfig;

bool get isDeletingVersion => _isDeletingVersion;
String? get deletingVersionId => _deletingVersionId;
bool get hasWebDavConfig => _webDavConfig?.isComplete ?? false;
WebDavConfig? get webDavConfig => _webDavConfig;

void reloadConfig() {
  _webDavConfig = _configStore?.read();
  notifyListeners();
}

Future<void> deleteBackupVersion({required String versionId}) async {
  final repository = _backupRepository;
  if (repository == null) {
    _errorMessage = '备份服务未初始化';
    notifyListeners();
    return;
  }

  _isDeletingVersion = true;
  _deletingVersionId = versionId;
  _errorMessage = null;
  notifyListeners();

  try {
    await repository.deleteBackup(versionId: versionId);
    _lastOperationSummary = '备份版本已删除';
    _availableBackups = await repository.listVersions();
  } on Exception catch (e, st) {
    _errorMessage = '删除失败: $e';
    Log.e('SettingsBackupController.deleteBackupVersion failed', error: e, stackTrace: st);
  } finally {
    _isDeletingVersion = false;
    _deletingVersionId = null;
    notifyListeners();
  }
}
```

The constructor must support test injection:

```dart
SettingsBackupController({
  DownloaderBackupRepository? backupRepository,
  WebDavConfigStore? configStore,
})  : _backupRepository = backupRepository,
      _configStore = configStore {
  _webDavConfig = _configStore?.read();
}
```

Keep existing export, list, restore, and undo behavior, but replace `DownloaderBackupService` with `DownloaderBackupRepository`. In `exportBackup`, catch `BackupPartialSuccessException` and set `_lastOperationSummary = e.warning` without setting `_errorMessage`.

- [ ] **Step 4: Wire providers in app.dart**

Modify the SettingsBackupController provider in `lib/app.dart` to create WebDAV-backed repository only when config exists:

```dart
ChangeNotifierProxyProvider2<AuthController, DownloaderController,
    SettingsBackupController>(
  create: (_) => SettingsBackupController(configStore: WebDavConfigStore()),
  update: (_, auth, downloader, previous) {
    final controller = previous ?? SettingsBackupController(
      configStore: WebDavConfigStore(),
    );
    final config = controller.webDavConfig;
    if (config != null && auth.user != null) {
      controller.attach(
        backupRepository: DownloaderBackupRepository(
          storageApi: WebDavBackupStorageApi(
            config: config,
            httpClient: controller.httpClient,
          ),
          downloaderController: downloader,
          currentUser: () => auth.user ?? (throw StateError('Not signed in')),
          currentAppVersion: () async {
            final info = await AppVersion.info();
            return info.version;
          },
        ),
        authController: auth,
        downloaderController: downloader,
      );
    } else {
      controller.attachAuthOnly(
        authController: auth,
        downloaderController: downloader,
      );
    }
    return controller;
  },
),
```

Add imports:

```dart
import 'package:windwalker/features/backup/data/downloader_backup_repository.dart';
import 'package:windwalker/features/backup/data/webdav_backup_storage_api.dart';
import 'package:windwalker/features/backup/data/webdav_config_store.dart';
```

- [ ] **Step 5: Run controller tests**

Run:

```bash
flutter test test/unit/features/settings/settings_backup_controller_test.dart
```

Expected: tests pass.

- [ ] **Step 6: Commit Task 6**

Run:

```bash
git add \
  lib/features/settings/presentation/controllers/settings_backup_controller.dart \
  lib/app.dart \
  test/unit/features/settings/settings_backup_controller_test.dart
git commit -m "feat(settings): wire webdav backup controller"
```

---

## Task 7: WebDAV Settings UI, Restore List, and Manual Delete

**Files:**
- Create: `lib/features/settings/presentation/pages/webdav_config_page.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_ja.arb`
- Test: `test/widget/settings_page_test.dart`

- [ ] **Step 1: Add WebDAV l10n keys**

Add these keys to all three ARB files with localized values:

English:

```json
  "webDavConfig": "WebDAV configuration",
  "webDavUrl": "WebDAV URL",
  "webDavDirectory": "Remote directory",
  "webDavUsername": "Username",
  "webDavPassword": "Password or app token",
  "testConnection": "Test connection",
  "save": "Save",
  "backupToWebDav": "Back up to WebDAV",
  "restoreFromWebDav": "Restore from WebDAV",
  "configureWebDavToUseBackup": "Configure WebDAV to use backup",
  "deleteBackupVersion": "Delete backup version",
  "deleteBackupVersionConfirm": "This backup version will be permanently deleted.",
  "backupVersionDeleted": "Backup version deleted"
```

Chinese:

```json
  "webDavConfig": "WebDAV 配置",
  "webDavUrl": "WebDAV 地址",
  "webDavDirectory": "远端目录",
  "webDavUsername": "用户名",
  "webDavPassword": "密码或应用 Token",
  "testConnection": "测试连接",
  "save": "保存",
  "backupToWebDav": "备份到 WebDAV",
  "restoreFromWebDav": "从 WebDAV 恢复",
  "configureWebDavToUseBackup": "配置 WebDAV 后使用备份",
  "deleteBackupVersion": "删除备份版本",
  "deleteBackupVersionConfirm": "该备份版本将被永久删除。",
  "backupVersionDeleted": "备份版本已删除"
```

Japanese:

```json
  "webDavConfig": "WebDAV 設定",
  "webDavUrl": "WebDAV URL",
  "webDavDirectory": "リモートディレクトリ",
  "webDavUsername": "ユーザー名",
  "webDavPassword": "パスワードまたはアプリトークン",
  "testConnection": "接続をテスト",
  "save": "保存",
  "backupToWebDav": "WebDAV にバックアップ",
  "restoreFromWebDav": "WebDAV から復元",
  "configureWebDavToUseBackup": "バックアップを使用するには WebDAV を設定してください",
  "deleteBackupVersion": "バックアップバージョンを削除",
  "deleteBackupVersionConfirm": "このバックアップバージョンは完全に削除されます。",
  "backupVersionDeleted": "バックアップバージョンを削除しました"
```

Run:

```bash
flutter gen-l10n
```

Expected: generated localization getters compile.

- [ ] **Step 2: Add WebDAV route**

Modify `lib/core/router/app_router.dart`:

Add import:

```dart
import 'package:windwalker/features/settings/presentation/pages/webdav_config_page.dart';
```

Add route after settings:

```dart
GoRoute(
  path: '/settings/webdav',
  name: 'webdav-config',
  builder: (context, state) => const WebDavConfigPage(),
),
```

- [ ] **Step 3: Create WebDAV config page**

Create `lib/features/settings/presentation/pages/webdav_config_page.dart`.

The page must:

- Read and save via `SettingsBackupController`.
- Use text controllers for URL, directory, username, and password.
- Default directory to `WindWalker/Backups`.
- Include password visibility toggle.
- Save a `WebDavConfig`.
- Call `controller.reloadConfig()` after saving.
- Pop after successful save.

Core save code:

```dart
Future<void> _save(SettingsBackupController controller) async {
  await controller.saveWebDavConfig(
    WebDavConfig(
      baseUrl: _urlController.text.trim(),
      remoteDirectory: _directoryController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    ),
  );
  if (mounted && controller.errorMessage == null) context.pop();
}
```

- [ ] **Step 4: Restore backup UI in settings page**

Modify `lib/features/settings/presentation/pages/settings_page.dart`:

- Remove the “temporarily hidden” backup comment block.
- Add a `NeoSettingRow` for WebDAV configuration.
- If signed out, show subtitle `l10n.signInToUseBackup`.
- If signed in but no WebDAV config, show `l10n.configureWebDavToUseBackup`.
- If signed in and configured, show backup and restore rows.
- Restore row opens a bottom sheet that calls `backup.loadAvailableBackups()`.
- Each version row has restore and delete icon buttons.
- Delete icon calls `_showDeleteBackupDialog`.

Dialog action:

```dart
await backup.deleteBackupVersion(versionId: version.fileId);
if (context.mounted) Navigator.pop(ctx);
```

Restore action keeps the existing confirmation and undo-last-restore behavior.

- [ ] **Step 5: Update settings widget tests**

Modify `test/widget/settings_page_test.dart` to assert:

```dart
expect(find.text('WebDAV configuration'), findsOneWidget);
expect(find.textContaining('WebDAV'), findsWidgets);
```

Add a test for the config route if the existing helper supports router navigation:

```dart
await tester.tap(find.text('WebDAV configuration'));
await tester.pumpAndSettle();
expect(find.text('WebDAV URL'), findsOneWidget);
expect(find.text('Remote directory'), findsOneWidget);
```

- [ ] **Step 6: Run Task 7 widget tests**

Run:

```bash
flutter test test/widget/settings_page_test.dart
```

Expected: tests pass.

- [ ] **Step 7: Commit Task 7**

Run:

```bash
git add \
  lib/features/settings/presentation/pages/webdav_config_page.dart \
  lib/features/settings/presentation/pages/settings_page.dart \
  lib/core/router/app_router.dart \
  lib/l10n \
  test/widget/settings_page_test.dart
git commit -m "feat(settings): add webdav backup UI"
```

---

## Task 8: Final Cleanup, Full Test Pass, and Verification

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Delete: `lib/services/google_drive_backup_api.dart`
- Delete: `lib/services/drive_auth_exception.dart`
- Delete: `lib/services/downloader_backup_service.dart`

- [ ] **Step 1: Search for obsolete Google auth and Drive references**

Run:

```bash
rg -n "GoogleDriveBackupApi|DriveAuthException|FirebaseAuthProvider|firebase_auth|google_sign_in|signInWithGoogle|backupToGoogleDrive|restoreFromGoogleDrive|authorizeScopes|authorizationHeaders|drive.appdata" lib test pubspec.yaml
```

Expected: no matches.

- [ ] **Step 2: Search for sensitive analytics params**

Run:

```bash
rg -n "email|password|token|secret|host|username" lib/services lib/features -g '*.dart'
```

Expected: matches are reviewed. Analytics calls must not include sensitive values. Storage and form fields can still contain these words.

- [ ] **Step 3: Run focused auth and backup tests**

Run:

```bash
flutter test \
  test/unit/features/auth/app_backend_auth_api_test.dart \
  test/unit/features/auth/auth_token_store_test.dart \
  test/unit/features/auth/backend_auth_repository_test.dart \
  test/unit/auth_controller_test.dart \
  test/widget/login_page_test.dart \
  test/unit/features/backup/webdav_config_store_test.dart \
  test/unit/features/backup/webdav_backup_storage_api_test.dart \
  test/unit/features/backup/downloader_backup_repository_test.dart \
  test/unit/features/settings/settings_backup_controller_test.dart \
  test/widget/settings_page_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 4: Run full test suite**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Analyze static issues**

Run:

```bash
flutter analyze
```

Expected: no analyzer errors.

- [ ] **Step 6: Manual smoke run**

Run:

```bash
flutter run
```

Manual checks:

- Login page shows email/password form.
- Register mode sends code through the backend endpoint.
- Sign in with a test account succeeds.
- Settings shows WebDAV configuration.
- Saving WebDAV config returns to settings.
- Backup uploads a file to the configured WebDAV directory.
- Restore lists versions.
- Manual delete removes the selected version.

- [ ] **Step 7: Commit final cleanup**

Run:

```bash
git status --short
git add lib test pubspec.yaml pubspec.lock
git commit -m "chore: remove google auth and drive backup remnants"
```

Expected: working tree is clean except user-owned unrelated files.

---

## Self-Review Checklist

- Spec coverage:
  - Backend password login: Tasks 1-3.
  - Email-code registration: Tasks 1-3.
  - Token refresh on startup: Task 2.
  - WebDAV user configuration: Tasks 4, 6, 7.
  - WebDAV backup restore: Tasks 4-7.
  - Automatic two-version retention: Task 5.
  - Manual delete: Tasks 5-7.
  - Google/Firebase Auth cleanup: Tasks 3 and 8.
  - Privacy-safe analytics: Tasks 2, 5, and 8.
- Completion scan:
  - This plan contains no unresolved values or unspecified test steps.
- Type consistency:
  - Auth API uses `AuthTokenResponse`, `UserInfoResponse`, `AuthSession`.
  - Auth controller depends on repository methods `sendRegisterCode`, `loginWithPassword`, `register`, `restoreSession`, `logout`.
  - Backup repository depends on `BackupStorageApi` methods `listVersions`, `uploadBackup`, `downloadBackup`, `deleteBackup`.
  - Settings backup controller exposes `deleteBackupVersion`, `hasWebDavConfig`, `webDavConfig`, and reload/save config methods.
