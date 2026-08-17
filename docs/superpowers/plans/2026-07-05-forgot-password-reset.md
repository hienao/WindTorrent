# 忘记密码 / 重置密码 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在登录页新增「忘记密码？」入口和独立的「重置密码」页面，支持用户通过邮箱验证码重置密码。

**Architecture:** 复用现有 register 流程的分层结构（API → Repository → Controller → Page）和 countdown 机制。新增 `sendResetPasswordCode` / `resetPassword` 两条数据链路，新增独立路由 `/reset-password` 指向 `ResetPasswordPage`。重置成功后 pop 回登录页并预填邮箱。

**Tech Stack:** Flutter 3.24.5, Provider (ChangeNotifier), go_router, http, GetStorage。测试用 `package:http/testing.dart` 的 `MockClient` + 手写 Fake。

**设计文档：** `docs/superpowers/specs/2026-07-05-forgot-password-reset-design.md`

**关键约束：**
- `template-arb-file` 是 `app_en.arb`——新 key 必须先加 en，再加 zh/ja。
- `AuthApiClient` 是抽象接口，加方法会破坏两个测试文件里的 `FakeAuthApi`（`test/unit/auth_controller_test.dart` 和 `test/unit/features/auth/backend_auth_repository_test.dart`），必须同步实现。
- 错误文案是 controller 里硬编码中文（非 l10n），新增的 controller 行为保持这个模式。
- 新代码 scene 用小写 `'reset-password'`（对齐 OpenAPI 文档）；现有 `sendRegisterCode` 不动（仍传 `'REGISTER'`）。

---

## 文件结构

| 文件 | 责任 | 操作 |
|---|---|---|
| `lib/features/auth/data/app_backend_auth_api.dart` | 抽象接口 + HTTP 实现 | 修改：加 2 方法 + 错误映射分支 |
| `lib/features/auth/data/backend_auth_repository.dart` | Repository 透传 | 修改：加 2 透传方法 |
| `lib/features/auth/presentation/controllers/auth_controller.dart` | UI 状态管理 | 修改：加 `_isResetting` 状态 + 2 方法 |
| `lib/features/auth/presentation/pages/reset_password_page.dart` | 重置密码 UI | **新建** |
| `lib/features/auth/presentation/pages/login_page.dart` | 登录 UI | 修改：加「忘记密码」入口 + 接收 pop 预填 |
| `lib/core/router/app_router.dart` | 路由 | 修改：加 `/reset-password` 路由 |
| `lib/l10n/app_en.arb` / `app_zh.arb` / `app_ja.arb` | 文案 | 修改：各加 6 key |
| `test/unit/features/auth/app_backend_auth_api_test.dart` | API 测试 | 修改：加 3 测试 |
| `test/unit/features/auth/backend_auth_repository_test.dart` | Repository 测试 | 修改：FakeAuthApi 补 2 方法 stub |
| `test/unit/auth_controller_test.dart` | Controller 测试 | 修改：FakeAuthApi 补 2 方法 stub + 加 3 测试 |
| `test/widget/login_page_test.dart` | 登录页 widget 测试 | 修改：加「忘记密码」入口测试 |

---

## Task 1: API 层 — sendResetPasswordCode + resetPassword 接口与实现

**Files:**
- Modify: `lib/features/auth/data/app_backend_auth_api.dart`（抽象接口 `AuthApiClient` + 实现 `AppBackendAuthApi`）
- Test: `test/unit/features/auth/app_backend_auth_api_test.dart`

- [ ] **Step 1: 写 sendResetPasswordCode 的失败测试**

在 `test/unit/features/auth/app_backend_auth_api_test.dart` 的 `group('AppBackendAuthApi', ...)` 内（最后一个测试之后、group 闭合 `});` 之前）新增：

```dart
    test(
      'sendResetPasswordCode posts email with reset-password scene',
      () async {
        late http.Request capturedRequest;
        final client = MockClient((request) async {
          capturedRequest = request;
          return http.Response('', 204);
        });

        final api = AppBackendAuthApi(
          baseUri: Uri.parse('https://api.example.com'),
          appId: 'windwalker-app',
          appKey: 'secret-key',
          client: client,
        );

        await api.sendResetPasswordCode(email: 'bob@example.com');

        expect(capturedRequest.method, 'POST');
        expect(
          capturedRequest.url.toString(),
          'https://api.example.com/api/auth/email/send-code',
        );
        expect(capturedRequest.headers['X-App-Id'], 'windwalker-app');
        expect(capturedRequest.headers['X-App-Key'], 'secret-key');
        expect(jsonDecode(capturedRequest.body), {
          'email': 'bob@example.com',
          'scene': 'reset-password',
        });
      },
    );
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/features/auth/app_backend_auth_api_test.dart`
Expected: 编译错误 — `sendResetPasswordCode` 方法未定义（接口和实现都没有）。同时 `backend_auth_repository_test.dart` 和 `auth_controller_test.dart` 的 `FakeAuthApi` 也会编译失败（因为接口加了方法但 fake 没实现）。**注意：此时多个测试文件编译失败是预期的**，本任务只关注 api 测试文件。

- [ ] **Step 3: 在 AuthApiClient 抽象接口加 2 个方法签名**

在 `lib/features/auth/data/app_backend_auth_api.dart` 的 `abstract class AuthApiClient` 内，`me` 方法之后、`logout` 方法之前（约第 26 行后）新增：

```dart
  Future<void> sendResetPasswordCode({required String email});

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
```

- [ ] **Step 4: 在 AppBackendAuthApi 实现 sendResetPasswordCode**

在 `AppBackendAuthApi` 类的 `refreshToken` 方法之后、`me` 方法之前（约第 96 行后，即 `loginWithPassword` 实现块之后），新增：

```dart
  @override
  Future<void> sendResetPasswordCode({required String email}) async {
    await _post(
      '/api/auth/email/send-code',
      headers: _appAuthHeaders(),
      body: {'email': email, 'scene': 'reset-password'},
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _post(
      '/api/auth/password/reset',
      headers: _appAuthHeaders(),
      body: {'email': email, 'code': code, 'newPassword': newPassword},
    );
  }
```

- [ ] **Step 5: 修复 backend_auth_repository_test.dart 的 FakeAuthApi 编译错误**

接口加了新方法，`test/unit/features/auth/backend_auth_repository_test.dart` 的 `FakeAuthApi`（第 8 行）必须实现新接口。在 `logout` 方法之后（约第 77 行后，class 闭合 `}` 之前）新增：

```dart
  @override
  Future<void> sendResetPasswordCode({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {}
```

- [ ] **Step 6: 修复 auth_controller_test.dart 的 FakeAuthApi 编译错误**

`test/unit/auth_controller_test.dart` 的 `FakeAuthApi`（第 9 行）也必须实现新接口。先在 class 顶部字段区（`Object? sendCodeError;` 之后，约第 26 行后）新增可注入的错误字段：

```dart
  Object? resetError;
```

然后在 `logout` 方法之后（约第 67 行后，class 闭合 `}` 之前）新增：

```dart
  @override
  Future<void> sendResetPasswordCode({required String email}) async {
    if (sendCodeError != null) throw sendCodeError!;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (resetError != null) throw resetError!;
  }
```

- [ ] **Step 7: 运行 sendResetPasswordCode 测试确认通过**

Run: `flutter test test/unit/features/auth/app_backend_auth_api_test.dart`
Expected: PASS（包含新测试 + 原有测试全绿）。

- [ ] **Step 8: 写 resetPassword 的失败测试**

在 `app_backend_auth_api_test.dart` 的 group 内（上一步新增的 `sendResetPasswordCode` 测试之后）新增：

```dart
    test(
      'resetPassword posts email/code/newPassword and treats 204 as success',
      () async {
        late http.Request capturedRequest;
        final client = MockClient((request) async {
          capturedRequest = request;
          return http.Response('', 204);
        });

        final api = AppBackendAuthApi(
          baseUri: Uri.parse('https://api.example.com'),
          appId: 'windwalker-app',
          appKey: 'secret-key',
          client: client,
        );

        await api.resetPassword(
          email: 'bob@example.com',
          code: '123456',
          newPassword: 'NewP@ssw0rd',
        );

        expect(capturedRequest.method, 'POST');
        expect(
          capturedRequest.url.toString(),
          'https://api.example.com/api/auth/password/reset',
        );
        expect(capturedRequest.headers['X-App-Id'], 'windwalker-app');
        expect(capturedRequest.headers['X-App-Key'], 'secret-key');
        expect(jsonDecode(capturedRequest.body), {
          'email': 'bob@example.com',
          'code': '123456',
          'newPassword': 'NewP@ssw0rd',
        });
      },
    );
```

- [ ] **Step 9: 运行 resetPassword 测试确认通过**

Run: `flutter test test/unit/features/auth/app_backend_auth_api_test.dart`
Expected: PASS（resetPassword 实现已在 Step 4 写好，应直接通过）。

- [ ] **Step 10: 提交**

```bash
git add lib/features/auth/data/app_backend_auth_api.dart test/unit/features/auth/app_backend_auth_api_test.dart test/unit/features/auth/backend_auth_repository_test.dart test/unit/auth_controller_test.dart
git commit -m "feat(auth): add sendResetPasswordCode and resetPassword api methods"
```

---

## Task 2: API 层 — reset 的 400 INVALID_CODE 错误映射

**Files:**
- Modify: `lib/features/auth/data/app_backend_auth_api.dart`（`_mapResponseToException` 方法）
- Test: `test/unit/features/auth/app_backend_auth_api_test.dart`

- [ ] **Step 1: 写失败测试 — resetPassword 的 400 INVALID_CODE 映射到 invalidCode**

在 `app_backend_auth_api_test.dart` 的 group 内（resetPassword 测试之后）新增：

```dart
    test(
      'resetPassword maps 400 INVALID_CODE to invalidCode',
      () async {
        final client = MockClient((_) async {
          return http.Response(
            jsonEncode({'code': 'INVALID_CODE', 'message': 'invalid code'}),
            400,
          );
        });

        final api = AppBackendAuthApi(
          baseUri: Uri.parse('https://api.example.com'),
          appId: 'windwalker-app',
          appKey: 'secret-key',
          client: client,
        );

        await expectLater(
          () => api.resetPassword(
            email: 'bob@example.com',
            code: 'bad',
            newPassword: 'NewP@ssw0rd',
          ),
          throwsA(
            isA<AuthException>()
                .having((e) => e.reason, 'reason', AuthFailureReason.invalidCode)
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.code, 'code', 'INVALID_CODE'),
          ),
        );
      },
    );
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/features/auth/app_backend_auth_api_test.dart -N 'maps 400 INVALID_CODE' --plain-name`
Expected: FAIL — 400 INVALID_CODE 当前落 `unknown`（而非 `invalidCode`），因为现有映射只对 401 + INVALID_CODE 映射 invalidCode。

- [ ] **Step 3: 在 _mapResponseToException 加 400 INVALID_CODE 分支**

在 `lib/features/auth/data/app_backend_auth_api.dart` 的 `_mapResponseToException` 方法内，找到现有的 401 INVALID_CODE 分支：

```dart
    if (statusCode == 401 &&
        (code == 'INVALID_CODE' || code == 'CODE_EXPIRED')) {
      return AuthException(
        reason: AuthFailureReason.invalidCode,
        statusCode: statusCode,
        code: code,
        message: message,
      );
    }
```

在这个 if 块**之后**、`if (statusCode == 401)`（401 兜底）**之前**，插入新分支：

```dart
    if (statusCode == 400 &&
        (code == 'INVALID_CODE' || code == 'CODE_EXPIRED')) {
      return AuthException(
        reason: AuthFailureReason.invalidCode,
        statusCode: statusCode,
        code: code,
        message: message,
      );
    }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/unit/features/auth/app_backend_auth_api_test.dart`
Expected: PASS（全部测试，含新测试）。

- [ ] **Step 5: 提交**

```bash
git add lib/features/auth/data/app_backend_auth_api.dart test/unit/features/auth/app_backend_auth_api_test.dart
git commit -m "feat(auth): map 400 INVALID_CODE to invalidCode for reset flow"
```

---

## Task 3: Repository 层 — 2 个透传方法

**Files:**
- Modify: `lib/features/auth/data/backend_auth_repository.dart`
- Test: `test/unit/features/auth/backend_auth_repository_test.dart`

- [ ] **Step 1: 写 sendResetPasswordCode 透传测试**

在 `test/unit/features/auth/backend_auth_repository_test.dart` 的 `group('BackendAuthRepository', ...)` 内（最后一个测试之后）新增：

```dart
    test('sendResetPasswordCode delegates to api', () async {
      final api = FakeAuthApi();
      final store = MemoryAuthTokenStore();
      final repo = BackendAuthRepository(api: api, tokenStore: store);

      await repo.sendResetPasswordCode(email: 'bob@example.com');

      // 纯透传：无 session 保存、无异常即视为成功
      expect(store.session, isNull);
    });

    test('resetPassword delegates to api', () async {
      final api = FakeAuthApi();
      final store = MemoryAuthTokenStore();
      final repo = BackendAuthRepository(api: api, tokenStore: store);

      await repo.resetPassword(
        email: 'bob@example.com',
        code: '123456',
        newPassword: 'NewP@ssw0rd',
      );

      // 纯透传：无 session 保存、无异常即视为成功
      expect(store.session, isNull);
    });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/features/auth/backend_auth_repository_test.dart`
Expected: 编译错误 — `BackendAuthRepository` 没有 `sendResetPasswordCode` / `resetPassword` 方法。

- [ ] **Step 3: 在 BackendAuthRepository 加 2 个透传方法**

在 `lib/features/auth/data/backend_auth_repository.dart` 的 `sendRegisterCode` 方法之后（约第 37 行后）新增：

```dart
  Future<void> sendResetPasswordCode({required String email}) {
    return _api.sendResetPasswordCode(email: email);
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _api.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/unit/features/auth/backend_auth_repository_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/auth/data/backend_auth_repository.dart test/unit/features/auth/backend_auth_repository_test.dart
git commit -m "feat(auth): add reset password pass-through methods to repository"
```

---

## Task 4: Controller 层 — _isResetting 状态 + sendResetPasswordCode + resetPassword

**Files:**
- Modify: `lib/features/auth/presentation/controllers/auth_controller.dart`
- Test: `test/unit/auth_controller_test.dart`

- [ ] **Step 1: 写 sendResetPasswordCode 成功测试**

在 `test/unit/auth_controller_test.dart`（顶层 `void main()` 内，最后一个 test 之后）新增：

```dart
  test('sendResetPasswordCode sets resend timestamp', () async {
    final controller = await makeController();

    await controller.sendResetPasswordCode(email: 'bob@example.com');

    expect(controller.isSendingCode, isFalse);
    expect(controller.nextCodeSendAt, isNotNull);
  });

  test('resetPassword clears isResetting on success', () async {
    final controller = await makeController();

    await controller.resetPassword(
      email: 'bob@example.com',
      code: '123456',
      newPassword: 'NewP@ssw0rd',
    );

    expect(controller.isResetting, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('resetPassword maps invalidCode to message', () async {
    final api = FakeAuthApi()
      ..resetError = const backend.AuthException(
        reason: backend.AuthFailureReason.invalidCode,
      );
    final controller = await makeController(api: api);

    await controller.resetPassword(
      email: 'bob@example.com',
      code: 'bad',
      newPassword: 'NewP@ssw0rd',
    );

    expect(controller.errorMessage, contains('验证码'));
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/auth_controller_test.dart`
Expected: 编译错误 — `AuthController` 没有 `sendResetPasswordCode` / `resetPassword` / `isResetting`。

- [ ] **Step 3: 在 AuthController 加 _isResetting 状态字段**

在 `lib/features/auth/presentation/controllers/auth_controller.dart`，找到状态字段区（约第 17-21 行）：

```dart
  AppUser? _user;
  bool _isLoading = false;
  bool _isSendingCode = false;
  String? _errorMessage;
  DateTime? _nextCodeSendAt;
```

在 `_isSendingCode` 之后新增：

```dart
  bool _isResetting = false;
```

然后在 getter 区（约第 23-28 行，`bool get isSendingCode` 之后）新增：

```dart
  bool get isResetting => _isResetting;
```

- [ ] **Step 4: 在 AuthController 加 sendResetPasswordCode 方法**

在 `sendRegisterCode` 方法之后（约第 85 行后，`loginWithPassword` 之前）新增。**注意：这个方法的 telemetry 用 `AuthTelemetryService.trackSendCodeResult`（与 sendRegisterCode 一致，不区分 scene）：**

```dart
  Future<void> sendResetPasswordCode({required String email}) async {
    _isSendingCode = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.sendResetPasswordCode(email: email.trim());
      _nextCodeSendAt = DateTime.now().add(const Duration(seconds: 60));
      await AuthTelemetryService.trackSendCodeResult(success: true);
    } on AuthException catch (e) {
      _errorMessage = _messageForBackend(e);
      await AuthTelemetryService.trackSendCodeResult(
        success: false,
        reason: e.reason,
      );
    } catch (e, st) {
      _errorMessage = _messageForUnknown();
      Log.e('sendResetPasswordCode failed', error: e, stackTrace: st);
      await AuthTelemetryService.trackSendCodeResult(success: false);
    } finally {
      _isSendingCode = false;
      notifyListeners();
    }
  }
```

- [ ] **Step 5: 在 AuthController 加 resetPassword 方法**

在 `register` 方法之后、`signOut` 方法之前（约第 153 行后）新增。**注意：telemetry 用 `AnalyticsService.instance.track`（参照 signOut 模式，不复用 AuthTelemetryService 的 login/register 专用方法）：**

```dart
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _isResetting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.resetPassword(
        email: email.trim(),
        code: code.trim(),
        newPassword: newPassword,
      );
      await AnalyticsService.instance.track(
        'auth_reset_password_result',
        params: <String, Object>{'result': 'success'},
      );
    } on AuthException catch (e) {
      _errorMessage = _messageForBackend(e);
      await AnalyticsService.instance.track(
        'auth_reset_password_result',
        params: <String, Object>{
          'result': 'failed',
          'error_type': 'auth_exception',
          'reason': e.reason.name,
        },
      );
    } catch (e, st) {
      _errorMessage = _messageForUnknown();
      Log.e('resetPassword failed', error: e, stackTrace: st);
      await AnalyticsService.instance.track(
        'auth_reset_password_result',
        params: <String, Object>{
          'result': 'failed',
          'error_type': e.runtimeType.toString(),
        },
      );
    } finally {
      _isResetting = false;
      notifyListeners();
    }
  }
```

- [ ] **Step 6: 运行 controller 测试确认通过**

Run: `flutter test test/unit/auth_controller_test.dart`
Expected: PASS（含 3 个新测试 + 原有全绿）。

- [ ] **Step 7: 提交**

```bash
git add lib/features/auth/presentation/controllers/auth_controller.dart test/unit/auth_controller_test.dart
git commit -m "feat(auth): add reset password controller methods and isResetting state"
```

---

## Task 5: 国际化 — 新增 6 个 ARB key

**Files:**
- Modify: `lib/l10n/app_en.arb`（模板，必须先加）
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_ja.arb`
- Generated: `lib/l10n/app_localizations.dart` + `app_localizations_en.dart` + `app_localizations_zh.dart` + `app_localizations_ja.dart`（`flutter gen-l10n` 自动生成）

- [ ] **Step 1: 在 app_en.arb 加 6 个 key（带 @description 元数据）**

在 `lib/l10n/app_en.arb` 末尾（最后一个 key 的逗号之后、闭合 `}` 之前）新增：

```json
  "forgotPassword": "Forgot password?",
  "@forgotPassword": { "description": "Forgot password link on login page" },
  "resetPassword": "Reset Password",
  "@resetPassword": { "description": "Reset password page title and submit button" },
  "resetPasswordSubtitle": "Set a new password via email verification code",
  "@resetPasswordSubtitle": { "description": "Reset password page subtitle" },
  "newPassword": "New Password",
  "@newPassword": { "description": "New password field label" },
  "confirmNewPassword": "Confirm New Password",
  "@confirmNewPassword": { "description": "Confirm new password field label" },
  "resetPasswordSuccess": "Password reset. Please log in with your new password.",
  "@resetPasswordSuccess": { "description": "Reset password success message" },
```

- [ ] **Step 2: 在 app_zh.arb 加对应 6 个 key（仅值，不加 @description）**

在 `lib/l10n/app_zh.arb` 末尾新增：

```json
  "forgotPassword": "忘记密码？",
  "resetPassword": "重置密码",
  "resetPasswordSubtitle": "通过邮箱验证码设置新密码",
  "newPassword": "新密码",
  "confirmNewPassword": "确认新密码",
  "resetPasswordSuccess": "密码已重置，请使用新密码登录",
```

- [ ] **Step 3: 在 app_ja.arb 加对应 6 个 key**

在 `lib/l10n/app_ja.arb` 末尾新增：

```json
  "forgotPassword": "パスワードをお忘れですか？",
  "resetPassword": "パスワードリセット",
  "resetPasswordSubtitle": "メール認証コードで新しいパスワードを設定",
  "newPassword": "新しいパスワード",
  "confirmNewPassword": "新しいパスワード（確認）",
  "resetPasswordSuccess": "パスワードがリセットされました。新しいパスワードでログインしてください",
```

- [ ] **Step 4: 运行 gen-l10n 重新生成本地化代码**

Run: `flutter gen-l10n`
Expected: 无错误输出。`lib/l10n/app_localizations.dart` 等文件自动更新，新增 6 个 getter（`forgotPassword`、`resetPassword`、`resetPasswordSubtitle`、`newPassword`、`confirmNewPassword`、`resetPasswordSuccess`）。

- [ ] **Step 5: 验证生成的代码无 analyze 问题**

Run: `flutter analyze lib/l10n/`
Expected: No issues found.

- [ ] **Step 6: 提交**

```bash
git add lib/l10n/
git commit -m "feat(i18n): add forgot/reset password localization keys"
```

---

## Task 6: 路由 — 新增 /reset-password

**Files:**
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: 在 app_router.dart 加 /reset-password 路由**

在 `lib/core/router/app_router.dart` 找到 `/login` 路由（约第 40-44 行）：

```dart
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
```

在它**之后**新增：

```dart
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
```

- [ ] **Step 2: 加 ResetPasswordPage 的 import**

在文件顶部 import 区（`import '.../login_page.dart';` 之后，约第 24 行后）新增：

```dart
import 'package:windwalker/features/auth/presentation/pages/reset_password_page.dart';
```

- [ ] **Step 3: 运行 analyze 确认（此时会失败，因为 ResetPasswordPage 还没创建）**

Run: `flutter analyze lib/core/router/app_router.dart`
Expected: 报错 `Target of URI doesn't exist: '.../reset_password_page.dart'` — **这是预期的**，下个 Task 创建页面后会通过。

- [ ] **Step 4: 暂不提交（等 Task 7 创建页面后一起提交）**

---

## Task 7: 重置密码页面 — ResetPasswordPage

**Files:**
- Create: `lib/features/auth/presentation/pages/reset_password_page.dart`
- Reference（复用样式）: `lib/features/auth/presentation/pages/login_page.dart`

- [ ] **Step 1: 创建 reset_password_page.dart**

创建 `lib/features/auth/presentation/pages/reset_password_page.dart`，完整内容：

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/features/auth/presentation/controllers/auth_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  Timer? _codeTicker;
  String? _localError;
  String? _localSuccess;

  @override
  void dispose() {
    _codeTicker?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode(AuthController auth) async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _localError = l10n.emailAddressInvalid;
        _localSuccess = null;
      });
      auth.clearErrorMessage();
      return;
    }
    setState(() {
      _localError = null;
      _localSuccess = null;
    });
    await auth.sendResetPasswordCode(email: email);
  }

  Future<void> _submit(AuthController auth) async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!_isValidEmail(email)) {
      setState(() {
        _localError = l10n.emailAddressInvalid;
        _localSuccess = null;
      });
      auth.clearErrorMessage();
      return;
    }
    if (code.isEmpty) {
      setState(() {
        _localError = l10n.verificationCodeRequired;
        _localSuccess = null;
      });
      auth.clearErrorMessage();
      return;
    }
    if (newPassword.isEmpty) {
      setState(() {
        _localError = l10n.passwordRequired;
        _localSuccess = null;
      });
      auth.clearErrorMessage();
      return;
    }
    if (confirmPassword != newPassword) {
      setState(() {
        _localError = l10n.passwordMismatch;
        _localSuccess = null;
      });
      auth.clearErrorMessage();
      return;
    }

    setState(() {
      _localError = null;
    });

    await auth.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );

    // 成功检测：方法内出错会设 errorMessage，无 errorMessage 视为成功
    if (!mounted) return;
    if (auth.errorMessage == null) {
      setState(() {
        _localSuccess = l10n.resetPasswordSuccess;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      context.pop(email);
    }
  }

  bool _isValidEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  String _sendCodeLabel(AppLocalizations l10n, AuthController auth) {
    if (auth.isSendingCode) {
      return l10n.sendingCode;
    }
    final next = auth.nextCodeSendAt;
    if (next == null) {
      return l10n.sendCode;
    }
    final seconds = next.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) {
      return l10n.sendCode;
    }
    return l10n.sendCodeCountdown(seconds);
  }

  void _syncTicker(AuthController auth) {
    final hasCountdown =
        (auth.nextCodeSendAt?.difference(DateTime.now()).inSeconds ?? 0) > 0;
    if (hasCountdown && _codeTicker == null) {
      _codeTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        final remaining =
            auth.nextCodeSendAt?.difference(DateTime.now()).inSeconds ?? 0;
        if (remaining <= 0) {
          _codeTicker?.cancel();
          _codeTicker = null;
        }
        setState(() {});
      });
      return;
    }
    if (!hasCountdown && _codeTicker != null) {
      _codeTicker?.cancel();
      _codeTicker = null;
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return NeoInputShell(
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: SafeArea(
        child: Consumer<AuthController>(
          builder: (context, auth, _) {
            _syncTicker(auth);
            final errorMessage = auth.errorMessage ?? _localError;

            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                NeoPageHeader(
                  title: l10n.resetPassword,
                  subtitle: l10n.resetPasswordSubtitle,
                  onBack: () => context.pop(),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: NeoCard(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_localSuccess != null) ...[
                              NeoInputShell(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: tokens.primaryAccent,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        _localSuccess!,
                                        style: TextStyle(
                                          color: tokens.primaryAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ] else if (errorMessage != null) ...[
                              NeoInputShell(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: colorScheme.error,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        errorMessage,
                                        style: TextStyle(
                                          color: colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            _buildField(
                              controller: _emailController,
                              label: l10n.emailAddress,
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildField(
                                    controller: _codeController,
                                    label: l10n.verificationCode,
                                    icon: Icons.verified_outlined,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                SizedBox(
                                  width: 132,
                                  child: NeoButton.secondary(
                                    onPressed: auth.isSendingCode ||
                                            _localSuccess != null
                                        ? null
                                        : () => _sendCode(auth),
                                    label: Text(_sendCodeLabel(l10n, auth)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildField(
                              controller: _newPasswordController,
                              label: l10n.newPassword,
                              icon: Icons.lock_outline_rounded,
                              obscureText: true,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildField(
                              controller: _confirmPasswordController,
                              label: l10n.confirmNewPassword,
                              icon: Icons.lock_reset_rounded,
                              obscureText: true,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            NeoButton.primary(
                              onPressed: auth.isResetting ||
                                      _localSuccess != null
                                  ? null
                                  : () => _submit(auth),
                              label: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (auth.isResetting)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.lock_reset_rounded),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Text(l10n.resetPassword),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 确认无问题**

Run: `flutter analyze lib/features/auth/presentation/pages/reset_password_page.dart lib/core/router/app_router.dart`
Expected: No issues found（页面 + 路由都通过了）。

- [ ] **Step 3: 提交**

```bash
git add lib/features/auth/presentation/pages/reset_password_page.dart lib/core/router/app_router.dart
git commit -m "feat(auth): add ResetPasswordPage and /reset-password route"
```

---

## Task 8: 登录页 — 「忘记密码」入口 + 接收 pop 预填邮箱

**Files:**
- Modify: `lib/features/auth/presentation/pages/login_page.dart`
- Test: `test/widget/login_page_test.dart`

- [ ] **Step 1: 写 widget 测试 — signIn 模式渲染「忘记密码」按钮**

先读 `test/widget/test_helpers.dart` 了解现有 widget 测试的 pump 模式（如何提供 AuthController provider、NeoThemeTokens）。然后参考现有 `test/widget/login_page_test.dart` 的 'Login page shows email auth form' 测试，在其后新增：

```dart
  testWidgets('signIn mode shows forgot password link', (tester) async {
    await tester.pumpWidget(makeTestableApp(const LoginPage()));
    await tester.pumpAndSettle();

    expect(find.text('忘记密码？'), findsOneWidget);
  });
```

> 注：`makeTestableApp` 是 `test_helpers.dart` 的 helper，签名以实际文件为准。若默认 locale 不是 zh，把期望文本换成对应语言的 `forgotPassword` 值，或用 `find.byType(TextButton)` + 子文本匹配。**实现时先读 test_helpers.dart 确认 helper 名和默认 locale。**

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/widget/login_page_test.dart -N 'forgot password link' --plain-name`
Expected: FAIL — 「忘记密码？」文本找不到（登录页还没加这个按钮）。

- [ ] **Step 3: 在 LoginPage 加 _forgotPassword 方法**

在 `lib/features/auth/presentation/pages/login_page.dart` 的 `_LoginPageState` 内，找到 `_sendCode` 方法之前（约第 317 行前）新增：

```dart
  Future<void> _forgotPassword(BuildContext pageContext) async {
    final email = await pageContext.push<String>('/reset-password');
    if (email != null && mounted) {
      _emailController.text = email;
      setState(() {
        _mode = _AuthMode.signIn;
        _localError = null;
      });
      context.read<AuthController>().clearErrorMessage();
    }
  }
```

- [ ] **Step 4: 在 build 方法密码字段之后加「忘记密码」TextButton**

在 `_LoginPageState.build` 方法内，找到密码字段块（约第 228-234 行）：

```dart
                            _buildField(
                              context: context,
                              controller: _passwordController,
                              label: l10n.password,
                              icon: Icons.lock_outline_rounded,
                              obscureText: true,
                            ),
```

在它**之后**、`if (_mode == _AuthMode.register) ...[ confirm password ]` 块**之前**，插入（仅 signIn 模式显示）：

```dart
                            if (_mode == _AuthMode.signIn)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _forgotPassword(context),
                                  child: Text(l10n.forgotPassword),
                                ),
                              ),
```

- [ ] **Step 5: 运行 widget 测试确认通过**

Run: `flutter test test/widget/login_page_test.dart`
Expected: PASS（含新测试 + 原有全绿）。

- [ ] **Step 6: 运行 analyze**

Run: `flutter analyze lib/features/auth/presentation/pages/login_page.dart`
Expected: No issues found.

- [ ] **Step 7: 提交**

```bash
git add lib/features/auth/presentation/pages/login_page.dart test/widget/login_page_test.dart
git commit -m "feat(auth): add forgot password entry on login page and email prefill"
```

---

## Task 9: 全量验证

- [ ] **Step 1: 运行全量 analyze**

Run: `flutter analyze`
Expected: No issues found（或仅与本次改动无关的既有问题）。

- [ ] **Step 2: 运行全量 auth 相关测试**

Run: `flutter test test/unit/features/auth/ test/unit/auth_controller_test.dart test/widget/login_page_test.dart`
Expected: 全部 PASS。

- [ ] **Step 3: 手动冒烟（可选，需连真机/模拟器）**

Run: `flutter run`
验证：
1. 登录页 signIn 模式显示「忘记密码？」链接
2. 点击进入重置页，填邮箱，点「发送验证码」→ 倒计时启动
3. 填验证码 + 新密码 + 确认，点「重置密码」→ 成功提示 → 1.5s 后返回登录页，邮箱已预填
4. 验证码错误场景：填错验证码，提交 → 显示「验证码无效或已过期」

- [ ] **Step 4: 若有改动则补充提交**

如冒烟发现问题并修复，补充提交。否则跳过。

---

## 完成检查清单

- [ ] API 层：`sendResetPasswordCode` / `resetPassword` 实现且测试通过
- [ ] 错误映射：400 INVALID_CODE → invalidCode
- [ ] Repository 层：2 透传方法测试通过
- [ ] Controller 层：`_isResetting` + 2 方法，3 测试通过
- [ ] 国际化：6 key 三语言，gen-l10n 通过
- [ ] 路由：`/reset-password` 注册
- [ ] 重置页：创建并 analyze 通过
- [ ] 登录页：入口 + 预填，widget 测试通过
- [ ] 全量 analyze + 测试通过
