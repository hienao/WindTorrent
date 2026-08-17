# 忘记密码 / 重置密码 功能设计

**日期：** 2026-07-05
**状态：** 已批准（待写实现计划）

## 背景

WindWalker 登录页当前支持邮箱密码登录和邮箱验证码注册，但缺少「忘记密码」找回入口。用户忘记密码后无法自助重置。

后端 OpenAPI（`https://appapi.51cloud.de/q/openapi`）已新增重置密码相关接口：

- `POST /api/auth/email/send-code`（统一发送验证码接口，靠 `scene` 字段区分场景，支持 `register | login | reset-password`）
- `POST /api/auth/password/reset`（用邮箱 + 验证码 + 新密码重置）

本设计在前端新增「忘记密码」入口和「重置密码」流程。

## 目标与非目标

**目标：**
- 登录页提供「忘记密码？」入口
- 用户可通过邮箱验证码重置密码
- 重置成功后返回登录页并预填邮箱，引导用户用新密码登录

**非目标：**
- 不做手机号/其他渠道重置（仅邮箱）
- 不做密码强度校验（后端 OpenAPI 仅要求非空 `\S`，前端不额外加规则）
- 不改 controller 现有硬编码中文文案为 l10n（保持现状，避免范围蔓延）
- 不实现重置后自动登录（reset 接口只返回 204 无 token，技术上无法自动登录）

## 后端契约（已确认）

### A. 发送重置验证码 — `POST /api/auth/email/send-code`

| 项 | 值 |
|---|---|
| Headers | `X-App-Id`（必填）、`X-App-Key`（必填）、无 Authorization |
| Body | `{email: string, scene: "reset-password"}` |
| 成功响应 | `204 No Content`（无 body） |
| 429 | 频率限制（per-email）→ `ApiErrorResponse` |
| 400 | 参数校验失败 → `ApiErrorResponse` |

### B. 重置密码 — `POST /api/auth/password/reset`

| 项 | 值 |
|---|---|
| Headers | `X-App-Id`（必填）、`X-App-Key`（必填）、无 Authorization |
| Body | `{email: string, code: string, newPassword: string}` |
| 成功响应 | `204 No Content`（无 body） |
| 400 | 参数校验失败**或**验证码无效/过期 → `ApiErrorResponse` |
| 401 | 用户不可用（如账号被禁用）→ `ApiErrorResponse` |
| 404 | 用户不存在 → `ApiErrorResponse` |

**错误码说明：** OpenAPI 未枚举具体的符号化 error code（如 `RESET_CODE_INVALID`），唯一示例是 `EMAIL_ALREADY_REGISTERED`。重置相关的错误语义靠 HTTP 状态码区分。验证码无效/过期统一落到 400。

**scene 大小写：** OpenAPI 枚举值为小写 `reset-password`。现有注册代码传大写 `'REGISTER'` 能跑通（后端大小写不敏感）。**新代码按文档用小写 `'reset-password'`**，现有 `sendRegisterCode` 不动。

## 整体流程

```
LoginPage（signIn 模式，密码框下方）
  └─「忘记密码？」TextButton
        ↓ context.push('/reset-password')
  ResetPasswordPage
        用户填写：邮箱 + 验证码 + 新密码 + 确认新密码
        ↓ 重置成功
        显示成功提示（~1.5s）
        ↓ context.pop(result: email)
  LoginPage 接收 pop 返回值
        预填邮箱 + 切到 signIn 模式
```

**为什么独立路由：** 遵循项目现有 go_router 模式（见 `app_router.dart`），与登录页状态解耦。重置流程不污染登录页的 `_mode`/`_localError` 状态。push 保留登录页栈，pop 自然返回。

## UI 设计（ResetPasswordPage）

复用登录页的视觉组件保持一致：`NeoPageHeader`、`NeoCard`、`NeoInputShell`、`NeoButton`、`_buildField` 同款签名。

```
ResetPasswordPage (/reset-password)
├─ NeoPageHeader
│   标题：重置密码 (l10n.resetPassword)
│   副标题：通过邮箱验证码设置新密码 (l10n.resetPasswordSubtitle)
│   带返回按钮 (context.pop)
└─ NeoCard
   ├─ [提示区]（错误/成功，复用登录页 NeoInputShell 样式）
   │   - 错误：读 auth.errorMessage，红色
   │   - 成功：本地 _localSuccess，绿色，配 check 图标
   ├─ 邮箱字段（TextEditingController，EmailAddress 键盘类型）
   ├─ 验证码 + [发送]按钮 行（Row 布局，同登录页 register 模式）
   │   - 发送按钮：auth.isSendingCode 时禁用并显示倒计时
   │   - 倒计时读 auth.nextCodeSendAt
   ├─ 新密码字段（obscureText: true，lock 图标）
   ├─ 确认新密码字段（obscureText: true，lock 图标）
   └─ [重置密码] 主按钮（NeoButton.primary，auth.isResetting 时转圈禁用）
```

**本地校验（提交前）：**
- 邮箱无效 → `emailAddressInvalid`（复用现有 key）
- 验证码为空 → `verificationCodeRequired`（复用现有 key）
- 新密码为空 → `passwordRequired`（复用现有 key）
- 确认密码 ≠ 新密码 → `passwordMismatch`（复用现有 key）

本地校验失败设置 `_localError` + `auth.clearErrorMessage()`（同登录页模式）。

### Countdown 机制复用

登录页的 countdown（`_codeTicker` / `_syncTicker` / `_sendCodeLabel` / `_showCodeSentHint`）逻辑搬到重置页。这些读写的 controller 状态（`isSendingCode`、`nextCodeSendAt`）是共享的，但**两个页面不会同时发验证码**（登录页发码只在 register 模式，重置页是独立路由 push 进来，登录页不活跃），所以复用同一组 controller 状态字段不冲突。

## 数据层设计

### API 层（`lib/features/auth/data/app_backend_auth_api.dart`）

`AuthApiClient` 抽象接口新增 2 个方法：

```dart
Future<void> sendResetPasswordCode({required String email});
Future<void> resetPassword({
  required String email,
  required String code,
  required String newPassword,
});
```

`AppBackendAuthApi` 实现：

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

两个方法都用 `_appAuthHeaders()`（X-App-Id + X-App-Key），无需 token。`sendRegisterCode` 保持不动（仍传 `'REGISTER'`）。

### 错误映射（`_mapResponseToException`）

新增一条规则，处理 reset 接口 400 的「验证码无效/过期」：

```dart
// 在现有 401 INVALID_CODE 分支之后、401 兜底分支之前插入
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

这样 reset 的 400 验证码错误会复用 `invalidCode` reason → 现有文案「验证码无效或已过期」，提示准确。

其余 reset 错误处理：
- 400（其他参数错误）→ 落 `unknown` → 「操作失败，请重试」
- 401（用户不可用）→ 落 `invalidCredentials` → 「邮箱或密码错误」（文案略不准但罕见，本次不修文案 bug）
- 404（用户不存在）→ 落 `unknown` → 「操作失败，请重试」
- 429 → `rateLimited` → 「验证码发送过于频繁，请稍后再试」（已有映射，复用）

**不新增 `AuthFailureReason` enum 值。**（404 用户不存在虽然语义独特，但本次不为它新增 enum，落 unknown 即可；如果后续要精确提示「邮箱未注册」再加）

### Repository 层（`lib/features/auth/data/backend_auth_repository.dart`）

新增 2 个透传方法（reset 不返回 session，无需保存）：

```dart
Future<void> sendResetPasswordCode({required String email}) {
  return _api.sendResetPasswordCode(email: email);
}

Future<void> resetPassword({
  required String email,
  required String code,
  required String newPassword,
}) {
  return _api.resetPassword(email: email, code: code, newPassword: newPassword);
}
```

### Controller 层（`lib/features/auth/presentation/controllers/auth_controller.dart`）

新增状态字段：

```dart
bool _isResetting = false;
bool get isResetting => _isResetting;
```

新增 2 个方法：

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

**说明：**
- `sendResetPasswordCode` 复用 `_isSendingCode` / `_nextCodeSendAt` 倒计时状态（与 `sendRegisterCode` 同机制）
- `resetPassword` 用独立的 `_isResetting` 状态（避免与 `_isLoading` 混淆，`_isLoading` 是登录/注册用的）
- telemetry 用 `AnalyticsService.instance.track`（参照现有 `signOut` 的埋点模式，不复用 `AuthTelemetryService` 的 login/register 专用方法，避免语义混淆）

## 路由（`lib/core/router/app_router.dart`）

新增路由：

```dart
GoRoute(
  path: '/reset-password',
  name: 'reset-password',
  builder: (context, state) => const ResetPasswordPage(),
),
```

放在 `/login` 路由之后。登录页入口用 `context.push('/reset-password')`。

## 成功后行为

**成功检测机制：** `resetPassword` 返回 void（遵循现有 `loginWithPassword`/`register` 靠状态字段通信的模式）。重置页 `await auth.resetPassword(...)` 完成后，检查 `mounted && auth.errorMessage == null` 推断成功——因为方法开头清空 `_errorMessage`，仅出错时才设置。成功后：

1. 设置页面本地 `_localSuccess = l10n.resetPasswordSuccess`
2. 渲染成功提示（绿色 NeoInputShell + check 图标）
3. 延时 ~1.5s 后 `context.pop(email)`

> 注：`AuthTelemetryService.trackSendCodeResult` 不区分 register/reset scene（只跟踪"发送验证码"结果）。本设计接受这一歧义——如后续需区分，再扩展 telemetry 方法签名。

登录页改造：`LoginPage` 的入口从直接 `context.push` 改为接收返回值：

```dart
final email = await context.push<String>('/reset-password');
if (email != null && mounted) {
  _emailController.text = email;
  setState(() {
    _mode = _AuthMode.signIn;
    _localError = null;
  });
  auth.clearErrorMessage();
}
```

登录页密码框下方（仅 signIn 模式）新增「忘记密码？」TextButton：

```dart
if (_mode == _AuthMode.signIn)
  Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: () => _forgotPassword(context),
      child: Text(l10n.forgotPassword),
    ),
  )
```

插入位置：密码字段之后、提交按钮的 `SizedBox(height: AppSpacing.xl)` 之前。

## 国际化

新增 ARB key（zh/en/ja 三语言，加到 `app_zh.arb` / `app_en.arb` / `app_ja.arb`）：

| Key | zh | en | ja |
|---|---|---|---|
| `forgotPassword` | 忘记密码？ | Forgot password? | パスワードをお忘れですか？ |
| `resetPassword` | 重置密码 | Reset Password | パスワードリセット |
| `resetPasswordSubtitle` | 通过邮箱验证码设置新密码 | Set a new password via email verification code | メール認証コードで新しいパスワードを設定 |
| `newPassword` | 新密码 | New Password | 新しいパスワード |
| `confirmNewPassword` | 确认新密码 | Confirm New Password | 新しいパスワード（確認） |
| `resetPasswordSuccess` | 密码已重置，请使用新密码登录 | Password reset. Please log in with your new password. | パスワードがリセットされました。新しいパスワードでログインしてください |

**复用现有 key：** `emailAddress`、`emailAddressInvalid`、`verificationCode`、`verificationCodeRequired`、`sendCode`、`sendingCode`、`sendCodeCountdown`、`passwordRequired`、`passwordMismatch`、`login`。

新增 key 后需运行 `flutter gen-l10n` 重新生成 `app_localizations*.dart`（或 `flutter pub get` 触发）。

## 测试

### API 层测试（`test/unit/features/auth/app_backend_auth_api_test.dart`）

新增 2 个测试，复用现有 `MockClient` + `capturedRequest` 模式：

1. **`sendResetPasswordCode posts email with reset-password scene`**
   - 断言：method=POST、URL=`/api/auth/email/send-code`、body `{email, scene: 'reset-password'}`、headers 含 X-App-Id/X-App-Key、204 视为成功
2. **`resetPassword posts email/code/newPassword and treats 204 as success`**
   - 断言：method=POST、URL=`/api/auth/password/reset`、body `{email, code, newPassword}`、headers 含 X-App-Id/X-App-Key、204 视为成功
3. （可选）**`resetPassword maps 400 INVALID_CODE to invalidCode`** — 验证新增的错误映射分支

### Controller 测试（`test/unit/auth_controller_test.dart`）

`FakeAuthApi` 补 `sendResetPasswordCode` / `resetPassword` stub（含可注入的 `sendCodeError` / `resetError` 字段）。

新增测试：
1. **`sendResetPasswordCode sets resend timestamp`** — 成功后 `nextCodeSendAt` 被设置
2. **`resetPassword clears isResetting on success`** — 成功后 `isResetting == false`、无 errorMessage
3. **`resetPassword maps invalidCode to message`** — 注入 invalidCode AuthException，断言 errorMessage 含「验证码」

### Widget 测试（可选）

`test/widget/login_page_test.dart` 新增：登录页 signIn 模式渲染「忘记密码？」按钮。重置页 widget 测试可后续补。

## 涉及文件清单

| 文件 | 改动 |
|---|---|
| `lib/features/auth/data/auth_api_models.dart` | 无（reset 无新模型，204 无 body） |
| `lib/features/auth/data/app_backend_auth_api.dart` | 新增 2 接口方法 + 实现；错误映射加 400 INVALID_CODE 分支 |
| `lib/features/auth/data/backend_auth_repository.dart` | 新增 2 透传方法 |
| `lib/features/auth/presentation/controllers/auth_controller.dart` | 新增 `_isResetting` 状态 + 2 方法 |
| `lib/features/auth/presentation/pages/reset_password_page.dart` | **新建** |
| `lib/features/auth/presentation/pages/login_page.dart` | 新增「忘记密码？」入口 + 接收 pop 预填邮箱 |
| `lib/core/router/app_router.dart` | 新增 `/reset-password` 路由 |
| `lib/l10n/app_zh.arb` / `app_en.arb` / `app_ja.arb` | 新增 6 个 key |
| `lib/l10n/app_localizations*.dart` | `flutter gen-l10n` 自动生成 |
| `test/unit/features/auth/app_backend_auth_api_test.dart` | 新增 2-3 测试 |
| `test/unit/auth_controller_test.dart` | FakeAuthApi 补 stub + 新增 2-3 测试 |
| `test/widget/login_page_test.dart` | （可选）新增「忘记密码」入口测试 |

## 风险与权衡

1. **404 用户不存在落 unknown**：文案显示「操作失败，请重试」而非「邮箱未注册」，提示不够精确。本次接受（避免新增 enum）；后续如需精确提示再加 `emailNotFound` reason。
2. **countdown 状态跨页面共享**：理论上若用户在重置页发码后 pop 回登录页再进 register 模式，倒计时会延续。实际场景概率极低（用户重置中途放弃注册），接受。
3. **scene 大小写不一致**：新代码用文档值 `reset-password`，老代码 `sendRegisterCode` 仍用 `REGISTER`。后端大小写不敏感所以无功能问题，但不统一。本次不顺手重构老代码（避免改现有接口签名 + 测试）。
