# 我的 tab 支持入口（隐私政策/联系开发者/分享）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在「我的」tab（`ProfileTab`）新增「支持与分享」Card，含隐私政策、联系开发者、分享 App 三个入口。

**Architecture:** 三个入口的对外动作直接在 `ListTile.onTap` 内联调用 `url_launcher` / `share_plus`，URL/邮箱/Play 链接作为常量集中放 `AppConstants`。不抽工具类（无状态一次性动作，YAGNI）。新增「支持与分享」「应用」两个小标题让两块 Card 视觉对称。

**Tech Stack:** Flutter 3.24.5 + Provider + Material 3；新增 `url_launcher`、`share_plus`（Flutter 官方 plus 家族）；l10n 通过 `flutter gen-l10n`（`l10n.yaml` 配置，template `app_en.arb`）。

**Spec:** `docs/superpowers/specs/2026-06-15-profile-support-links-design.md`

---

### Task 1: 新增常量到 AppConstants（TDD）

**Files:**
- Create: `test/unit/app_constants_test.dart`
- Modify: `lib/core/constants/app_constants.dart:1-17`（在 `aboutRoute` 后、路由区段结束前插入）

- [ ] **Step 1: 写失败测试**

创建 `test/unit/app_constants_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';

void main() {
  group('支持入口常量', () {
    test('privacyPolicyUrl 是合法的 https URL', () {
      final uri = Uri.parse(AppConstants.privacyPolicyUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, 'windwalker.51cloud.de');
      expect(uri.path, '/privacy-policy.html');
    });

    test('developerEmail 是合法邮箱格式', () {
      expect(AppConstants.developerEmail, contains('@'));
      expect(AppConstants.developerEmail, 'shiwentao666@gmail.com');
    });

    test('playStoreUrl 指向正确的包名', () {
      final uri = Uri.parse(AppConstants.playStoreUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, 'play.google.com');
      expect(
        uri.queryParameters['id'],
        'com.windwalker.download.manager',
      );
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/app_constants_test.dart`
Expected: FAIL — `AppConstants.privacyPolicyUrl` / `developerEmail` / `playStoreUrl` 未定义（编译错误或 getter not found）。

- [ ] **Step 3: 写最小实现**

编辑 `lib/core/constants/app_constants.dart`，在路由常量区段后（第 17 行 `upgradeRoute` 之后）新增：

```dart
  static const String upgradeRoute = '/upgrade';

  // 外部链接与联系信息
  static const String privacyPolicyUrl =
      'https://windwalker.51cloud.de/privacy-policy.html';
  static const String developerEmail = 'shiwentao666@gmail.com';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.windwalker.download.manager';
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/unit/app_constants_test.dart`
Expected: PASS（3 个测试通过）。

- [ ] **Step 5: 提交**

```bash
git add test/unit/app_constants_test.dart lib/core/constants/app_constants.dart
git commit -m "feat: add support link constants (privacy/email/play url)"
```

---

### Task 2: 添加 i18n 文案到三个 arb 文件

**Files:**
- Modify: `lib/l10n/app_en.arb`（末尾 `}` 前插入）
- Modify: `lib/l10n/app_zh.arb`（末尾 `}` 前插入）
- Modify: `lib/l10n/app_ja.arb`（末尾 `}` 前插入）

三个 arb 文件当前最后一项是 `updateCheckNotSupported`，格式为：
```
  "updateCheckNotSupported": "...",
}
```
**注意：** 需先给 `updateCheckNotSupported` 行补逗号，再在 `}` 前插入新 key。`shareAppMessage` 的 `@shareAppMessage` 元数据要声明 placeholders（参考现有 `totalDownloaders` 的写法）。

- [ ] **Step 1: 编辑 `lib/l10n/app_en.arb`**

把末尾的：
```json
  "updateCheckNotSupported": "Automatic updates aren't supported on this build"
}
```
替换为：
```json
  "updateCheckNotSupported": "Automatic updates aren't supported on this build",
  "supportSectionTitle": "Support & Share",
  "appSectionTitle": "App",
  "privacyPolicy": "Privacy Policy",
  "privacyPolicyDesc": "View our privacy policy",
  "contactDeveloper": "Contact Developer",
  "contactDeveloperDesc": "Send feedback via email",
  "shareApp": "Share App",
  "shareAppDesc": "Share with friends",
  "contactEmailSubject": "WindWalker Feedback",
  "openLinkFailed": "Unable to open link",
  "shareFailed": "Share failed",
  "shareAppMessage": "Check out {appName}: {url}",
  "@shareAppMessage": {
    "placeholders": {
      "appName": { "type": "String" },
      "url": { "type": "String" }
    }
  }
}
```

- [ ] **Step 2: 编辑 `lib/l10n/app_zh.arb`**

把末尾的：
```json
  "updateCheckNotSupported": "当前版本不支持自动检查更新"
}
```
替换为：
```json
  "updateCheckNotSupported": "当前版本不支持自动检查更新",
  "supportSectionTitle": "支持与分享",
  "appSectionTitle": "应用",
  "privacyPolicy": "隐私政策",
  "privacyPolicyDesc": "查看我们的隐私政策",
  "contactDeveloper": "联系开发者",
  "contactDeveloperDesc": "通过邮件反馈问题",
  "shareApp": "分享 App",
  "shareAppDesc": "分享给朋友",
  "contactEmailSubject": "WindWalker 反馈",
  "openLinkFailed": "无法打开链接",
  "shareFailed": "分享失败",
  "shareAppMessage": "推荐你试试 {appName}：{url}",
  "@shareAppMessage": {
    "placeholders": {
      "appName": { "type": "String" },
      "url": { "type": "String" }
    }
  }
}
```

- [ ] **Step 3: 编辑 `lib/l10n/app_ja.arb`**

把末尾的：
```json
  "updateCheckNotSupported": "このバージョンは自動更新に対応していません"
}
```
替换为：
```json
  "updateCheckNotSupported": "このバージョンは自動更新に対応していません",
  "supportSectionTitle": "サポートと共有",
  "appSectionTitle": "アプリ",
  "privacyPolicy": "プライバシーポリシー",
  "privacyPolicyDesc": "プライバシーポリシーを表示",
  "contactDeveloper": "開発者に連絡",
  "contactDeveloperDesc": "メールでフィードバック",
  "shareApp": "アプリを共有",
  "shareAppDesc": "友達に共有",
  "contactEmailSubject": "WindWalker フィードバック",
  "openLinkFailed": "リンクを開けません",
  "shareFailed": "共有に失敗しました",
  "shareAppMessage": "{appName}をチェックしてみて：{url}",
  "@shareAppMessage": {
    "placeholders": {
      "appName": { "type": "String" },
      "url": { "type": "String" }
    }
  }
}
```

- [ ] **Step 4: 重新生成 l10n**

Run: `flutter gen-l10n`
Expected: 成功，`lib/l10n/app_localizations.dart` 及 `_zh.dart` / `_en.dart` / `_ja.dart` 自动更新，含新增的 12 个 getter / 方法。

- [ ] **Step 5: 验证生成结果**

Run: `flutter analyze lib/l10n/app_localizations.dart`
Expected: 无报错。

再验证关键方法签名已生成：
Run: `grep -n "shareAppMessage\|supportSectionTitle\|appSectionTitle" lib/l10n/app_localizations.dart`
Expected: 能看到 `String shareAppMessage(String appName, String url);` 及各 getter 声明。

- [ ] **Step 6: 提交**

```bash
git add lib/l10n/
git commit -m "feat: add i18n strings for support links (zh/en/ja)"
```

---

### Task 3: 添加依赖 url_launcher 和 share_plus

**Files:**
- Modify: `pubspec.yaml:9-33`（dependencies 区段）

- [ ] **Step 1: 添加依赖**

在 `pubspec.yaml` 的 `dependencies:` 区段（`device_info_plus: ^13.1.0` 之后、`file_picker` 之前）新增两行：

```yaml
  device_info_plus: ^13.1.0
  url_launcher: ^6.3.1
  share_plus: ^10.1.2
  file_picker: ^12.0.0-beta
```

- [ ] **Step 2: 安装依赖**

Run: `flutter pub get`
Expected: 成功解析并安装两个包，无版本冲突。

- [ ] **Step 3: 提交**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add url_launcher and share_plus dependencies"
```

---

### Task 4: AndroidManifest 添加 queries（Android 11+ 包可见性）

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

`url_launcher` 在 Android 11+（API 30+）打开 `https` / `mailto` scheme 需要在 `<manifest>` 下声明 `<queries>`，否则 `launchUrl` 会返回 `false`（找不到目标 app）。当前 manifest 只有 `<uses-permission>` 和 `<application>`，无 `<queries>`。

- [ ] **Step 1: 在 `<application>` 标签后、`</manifest>` 前插入 `<queries>`**

把：
```xml
    </application>
</manifest>
```
替换为：
```xml
    </application>

    <!-- Android 11+ (API 30+) 包可见性：url_launcher 打开 https/mailto 需要声明 -->
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="mailto" />
        </intent>
    </queries>
</manifest>
```

- [ ] **Step 2: 验证 manifest 合法性**

Run: `cd android && ./gradlew :app:processDebugManifest -q` （或 `flutter build apk --debug` 末段不报 manifest 错误）
Expected: 无 manifest 合并 / 解析错误。

如果不想跑完整构建，至少做一次 `flutter analyze` 不报错即可（manifest 错误通常在构建期才暴露，但 `<queries>` 语法简单，风险低）。

- [ ] **Step 3: 提交**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: add manifest queries for url_launcher (https/mailto)"
```

---

### Task 5: ProfileTab 新增「支持与分享」Card + 两个 section 标题

**Files:**
- Modify: `lib/features/home/presentation/pages/profile_tab.dart`

这是本特性的核心改动。`ProfileTab` 当前是 `StatelessWidget`，build 里 `Consumer2<AuthController, UpdateController>` 返回 ListView。新加的三入口不依赖任何 controller 状态，直接在现有 ListView 里插入。

- [ ] **Step 1: 添加 import**

在 `profile_tab.dart` 顶部 import 区，`l10n/app_localizations.dart` 之后新增：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/utils/app_version.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/core/utils/responsive_layout.dart';
import 'package:windwalker/features/auth/presentation/controllers/auth_controller.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';
```

（即在现有 import 基础上新增 `url_launcher`、`share_plus`、`app_constants`、`log` 四行——确认现有文件已有哪些，只补缺的。）

- [ ] **Step 2: 改 ListView children 结构**

当前 ListView children（`profile_tab.dart:36-134`）结构是：`[Card(用户卡片), SizedBox, Card(设置/关于)]`。

改为：`[Card(用户卡片), SizedBox, _sectionTitle(support), Card(支持与分享), SizedBox, _sectionTitle(app), Card(设置/关于)]`。

把现有的（约 91-133 行）：
```dart
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: Text(l10n.settings),
                      subtitle: Text(l10n.settingsSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.aboutWindWalker),
                      subtitle: Text(
                        update.hasUpdate
                            ? l10n.updateAvailableBadge
                            : l10n.aboutSubtitle,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FutureBuilder<String>(
                            future: AppVersion.displayVersion(),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? '--',
                                style: const TextStyle(
                                  color: AppColors.textSecondaryLight,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
              ),
```

替换为：
```dart
              const SizedBox(height: AppSpacing.md),
              _sectionTitle(context, l10n.supportSectionTitle),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(l10n.privacyPolicy),
                      subtitle: Text(l10n.privacyPolicyDesc),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPrivacyPolicy(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.mail_outline),
                      title: Text(l10n.contactDeveloper),
                      subtitle: Text(l10n.contactDeveloperDesc),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _contactDeveloper(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.share_outlined),
                      title: Text(l10n.shareApp),
                      subtitle: Text(l10n.shareAppDesc),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _shareApp(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _sectionTitle(context, l10n.appSectionTitle),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: Text(l10n.settings),
                      subtitle: Text(l10n.settingsSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.aboutWindWalker),
                      subtitle: Text(
                        update.hasUpdate
                            ? l10n.updateAvailableBadge
                            : l10n.aboutSubtitle,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FutureBuilder<String>(
                            future: AppVersion.displayVersion(),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? '--',
                                style: const TextStyle(
                                  color: AppColors.textSecondaryLight,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
              ),
```

- [ ] **Step 3: 在 `ProfileTab` 类内添加 `_sectionTitle` 方法**

`ProfileTab` 当前没有 `_sectionTitle`（那个方法在 `SettingsPage` 里）。在 `ProfileTab` 类内（`build` 方法之后）新增：

```dart
  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondaryLight,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
```

（与 `SettingsPage._sectionTitle` 写法一致，保持视觉统一。）

- [ ] **Step 4: 添加三个入口动作方法 + 两个 SnackBar 辅助方法**

在 `ProfileTab` 类内（`_sectionTitle` 之后）新增：

```dart
  Future<void> _openPrivacyPolicy(BuildContext context) async {
    try {
      final ok = await launchUrl(
        Uri.parse(AppConstants.privacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        _showSnackBar(context, AppLocalizations.of(context)!.openLinkFailed);
      }
    } catch (e, st) {
      Log.e('打开隐私政策失败', error: e, stackTrace: st);
      if (context.mounted) {
        _showSnackBar(context, AppLocalizations.of(context)!.openLinkFailed);
      }
    }
  }

  Future<void> _contactDeveloper(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.parse(
      'mailto:${AppConstants.developerEmail}?subject=${Uri.encodeComponent(l10n.contactEmailSubject)}',
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        _showSnackBar(context, l10n.openLinkFailed);
      }
    } catch (e, st) {
      Log.e('打开邮件客户端失败', error: e, stackTrace: st);
      if (context.mounted) {
        _showSnackBar(context, l10n.openLinkFailed);
      }
    }
  }

  Future<void> _shareApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Share.share(
        l10n.shareAppMessage(l10n.appName, AppConstants.playStoreUrl),
      );
    } catch (e, st) {
      Log.e('分享失败', error: e, stackTrace: st);
      if (context.mounted) {
        _showSnackBar(context, l10n.shareFailed);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
```

- [ ] **Step 5: 验证编译**

Run: `flutter analyze lib/features/home/presentation/pages/profile_tab.dart`
Expected: 无报错。如果报 `context.mounted` 在 StatelessWidget 不可用——不对，`context.mounted` 在 Flutter 3.7+ 对 BuildContext 可用，本项目 3.24.5 支持。

- [ ] **Step 6: 提交**

```bash
git add lib/features/home/presentation/pages/profile_tab.dart
git commit -m "feat: add support links card to profile tab"
```

---

### Task 6: 全量验证

**Files:** 无改动，仅运行检查。

- [ ] **Step 1: 全量 analyze**

Run: `flutter analyze`
Expected: 无 error（warning 可接受但要确认非本次引入）。

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: 所有现有测试 + Task 1 的新测试全部通过。

- [ ] **Step 3: 构建验证（debug apk）**

Run: `flutter build apk --debug`
Expected: 构建成功，无 manifest / 插件解析错误。

- [ ] **Step 4: （可选）真机手动验证清单**

如条件允许，在真机验证三个入口：
1. 「我的」tab → 看到两个带小标题的 Card（「支持与分享」在上，「应用」在下）
2. 隐私政策 → 外部浏览器打开 `https://windwalker.51cloud.de/privacy-policy.html`
3. 联系开发者 → 邮件 app 弹出，收件人 `shiwentao666@gmail.com`，主题「WindWalker Feedback」（或对应语言）
4. 分享 App → 系统分享面板，文本含 appName + Play 链接
5. 切换语言到英文 / 日文，验证文案

- [ ] **Step 5: 最终提交（如有修复）**

如果前面验证发现问题并修复，按需提交。否则本任务无新增 commit。

---

## Self-Review 记录

（实现完成后由执行者填写验证结论，计划本身已对照 spec 自检：）

- **Spec 覆盖：** 12 个 i18n key（Task 2）、3 个常量（Task 1）、2 个依赖（Task 3）、Android queries（Task 4）、ProfileTab 三入口 + 两标题（Task 5）—— spec 各节均有对应 task。
- **占位符扫描：** 所有 step 含完整代码，无 TBD/TODO。
- **类型一致性：** `l10n.shareAppMessage(String appName, String url)` 在 Task 2 生成、Task 5 调用，签名一致；`_sectionTitle` 在 Task 5 Step 3 定义、Step 2 调用，签名一致；三个动作方法 `_openPrivacyPolicy` / `_contactDeveloper` / `_shareApp` 定义与 onTap 调用一致。
