# 我的 tab 新增隐私政策 / 联系开发者 / 分享 App 入口 — 设计

**日期：** 2026-06-15
**主题：** 在「我的」tab（`ProfileTab`）新增「支持与分享」分组 Card，提供隐私政策、联系开发者、分享 App 三个入口。

## 背景

`ProfileTab`（「我的」tab，`lib/features/home/presentation/pages/profile_tab.dart`）当前只有两块内容：

1. 用户卡片（头像 / 登录入口）
2. 一个 Card，含「设置」+「关于 WindWalker」两个 `ListTile`

缺少合规与增长所需的三类入口：
- **隐私政策**：Google Play 数据安全表单要求应用内提供隐私政策入口（项目已有托管页 `https://windwalker.51cloud.de/privacy-policy.html`，见 AGENTS.md Firebase Hosting 章节，但应用内无入口）。
- **联系开发者**：用户反馈渠道。
- **分享 App**：增长入口，让用户把 Play 链接分享出去。

## 目标

在 `ProfileTab` 新增一个「支持与分享」Card（含三个入口），并为视觉对称给现有「设置/关于」Card 也补小标题。

## 非目标

- 不改 `SettingsPage` / `AboutPage`（这三类入口不放那里）。
- 不引入有状态的工具类（如 `ReviewManager` 模式）——隐私政策 / 邮件 / 分享都是无状态的一次性外部动作，封装属 YAGNI。
- 不做应用内 WebView 打开隐私政策——用外部浏览器。
- 不为三个入口引入 widget test mock（plugin channel mock 收益低、维护成本高）。

## 方案

### 整体架构

三个入口的对外动作（打开 URL / 唤起邮件 / 系统分享）直接在 `ProfileTab` 的 `ListTile.onTap` 内联调用，URL / 邮箱 / Play 链接作为常量集中放 `AppConstants`。

**为什么不用工具类：** 项目已有的 `ReviewManager`（`lib/core/utils/review_manager.dart`）之所以是类，是因为它持有**有状态逻辑**（启动计数、冷却期、dismiss 版本）。而隐私政策 / 邮件 / 分享都是**无状态一次性动作**，抽类属于过度设计。这与项目 YAGNI 与 fail-fast 原则一致。

### 常量（`lib/core/constants/app_constants.dart`）

新增：

```dart
// 外部链接与联系信息
static const String privacyPolicyUrl =
    'https://windwalker.51cloud.de/privacy-policy.html';
static const String developerEmail = 'shiwentao666@gmail.com';
static const String playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.windwalker.download.manager';
```

包名 `com.windwalker.download.manager` 来自 `android/app/build.gradle:102` 的 `applicationId`，与现有 GPP 发布一致。

### 依赖（`pubspec.yaml`）

新增两个 Flutter 官方维护的 plus 家族插件（与已有 `package_info_plus` 一致）：

- `url_launcher`：打开隐私政策 URL（外部浏览器）+ `mailto:` 唤起邮件
- `share_plus`：唤起系统分享面板

### UI 布局（`ProfileTab`）

ListView 结构（改动后）：

```
[用户卡片]                                  ← 不变
  ↓
_sectionTitle(l10n.supportSectionTitle)     ← 新增"支持与分享"小标题
Card(                                        ← 新增 Card
  ├─ 隐私政策     Icons.privacy_tip_outlined
  ├─ 联系开发者   Icons.mail_outline
  └─ 分享 App     Icons.share_outlined
)
  ↓
_sectionTitle(l10n.appSectionTitle)          ← 新增"应用"小标题（视觉对称）
Card(                                        ← 现有 Card，内容不变
  ├─ 设置        Icons.settings_outlined
  └─ 关于 WindWalker
)
```

每个新 `ListTile` 沿用现有模式：`leading` icon + `title` + `subtitle`（简短描述）+ `trailing` chevron + `onTap`。Card 内用 `Divider(height: 1)` 分隔。

### 三个入口的行为

**① 隐私政策**
```dart
onTap: () async {
  final ok = await launchUrl(
    Uri.parse(AppConstants.privacyPolicyUrl),
    mode: LaunchMode.externalApplication,
  );
  if (!ok) _showOpenLinkFailed(context);  // SnackBar
}
```
外部浏览器打开（非应用内 WebView）。

**② 联系开发者**
```dart
onTap: () async {
  final uri = Uri.parse(
    'mailto:${AppConstants.developerEmail}?subject=${Uri.encodeComponent(l10n.contactEmailSubject)}',
  );
  final ok = await launchUrl(uri);
  if (!ok) _showOpenLinkFailed(context);
}
```
预填收件人 `shiwentao666@gmail.com` + 主题（`WindWalker Feedback` / `WindWalker 反馈` / `WindWalker フィードバック`），便于开发者筛选邮件。`subject` 用 `Uri.encodeComponent` 编码。

**③ 分享 App**
```dart
onTap: () async {
  try {
    await Share.share(l10n.shareAppMessage(
      l10n.appName,  // 随语言切换：中文"御风"、英文"WindWalker"、日文同 en
      AppConstants.playStoreUrl,
    ));
  } catch (e, st) {
    Log.e('分享失败', error: e, stackTrace: st);
    _showShareFailed(context);  // SnackBar
  }
}
```
文案用 l10n 占位（ICU `{appName}` / `{url}`），`l10n.appName` 随语言切换：中文"御风"、英文"WindWalker"。用户已确认用 l10n appName（而非固定的 `AppConstants.appNameEn`）。

### 错误处理

项目采用 fail-fast 原则（见 AGENTS.md「禁止防御性编程」章节）。这里的 `try/catch` **不违反**该原则，因为：

- 项目规范的核心是禁止**静默吞异常**（catch 后返回默认值、不传播、不让用户/上层知道）。
- 这里的错误被**如实传播给用户**：`SnackBar` 明确告知"无法打开链接"/"分享失败"，并 `Log.e()` 记录。这符合规范中"service 抛异常 → controller 写 errorState → UI 显示"的精神——用户可见的失败反馈。
- `launchUrl` 返回 `false`（无可用 app）或 `Share.share` 抛异常，是**真实的用户操作失败**，需要 UI 反馈，不能让用户点了没反应。

| 失败场景 | 处理 |
|---------|------|
| `launchUrl` 返回 `false`（无浏览器/邮件 app） | `SnackBar`：`l10n.openLinkFailed` + `Log.e` |
| `launchUrl` 抛异常 | `try/catch` → `SnackBar` + `Log.e` |
| `Share.share` 抛异常 | `try/catch` → `SnackBar`：`l10n.shareFailed` + `Log.e` |

辅助方法（私有，放 `ProfileTab` 内）：
```dart
void _showOpenLinkFailed(BuildContext context) { /* SnackBar */ }
void _showShareFailed(BuildContext context) { /* SnackBar */ }
```

## i18n

新增 12 个 key 到三个 arb 文件，然后 `flutter gen-l10n` 重新生成。

| key | 中文 | 英文 | 日文 |
|-----|------|------|------|
| `supportSectionTitle` | 支持与分享 | Support & Share | サポートと共有 |
| `appSectionTitle` | 应用 | App | アプリ |
| `privacyPolicy` | 隐私政策 | Privacy Policy | プライバシーポリシー |
| `privacyPolicyDesc` | 查看我们的隐私政策 | View our privacy policy | プライバシーポリシーを表示 |
| `contactDeveloper` | 联系开发者 | Contact Developer | 開発者に連絡 |
| `contactDeveloperDesc` | 通过邮件反馈问题 | Send feedback via email | メールでフィードバック |
| `shareApp` | 分享 App | Share App | アプリを共有 |
| `shareAppDesc` | 分享给朋友 | Share with friends | 友達に共有 |
| `contactEmailSubject` | WindWalker 反馈 | WindWalker Feedback | WindWalker フィードバック |
| `openLinkFailed` | 无法打开链接 | Unable to open link | リンクを開けません |
| `shareFailed` | 分享失败 | Share failed | 共有に失敗しました |
| `shareAppMessage` | 推荐你试试 {appName}：{url} | Check out {appName}: {url} | {appName}をチェックしてみて：{url} |

`shareAppMessage` 用 ICU 占位 `{appName}` / `{url}`，`l10n` 会生成 `shareAppMessage(String appName, String url)` 方法。

## 影响范围

| 文件 | 改动 |
|------|------|
| `pubspec.yaml` | 加 `url_launcher`、`share_plus` 依赖 |
| `lib/core/constants/app_constants.dart` | 加 3 个常量 |
| `lib/l10n/app_zh.arb` | 加 12 个 key |
| `lib/l10n/app_en.arb` | 加 12 个 key |
| `lib/l10n/app_ja.arb` | 加 12 个 key |
| `lib/l10n/app_localizations*.dart` | `flutter gen-l10n` 自动生成（不改手写） |
| `lib/features/home/presentation/pages/profile_tab.dart` | 加新 Card（3 个 ListTile）+ 两个 Card 的小标题 + 2 个私有 SnackBar 辅助方法 |

**不触碰：** `SettingsPage`、`AboutPage`、`app_router.dart`、`ReviewManager`、`UpdateController`、`AuthController`。

## 测试

- **不引入 widget test mock**：`url_launcher` / `share_plus` 是 plugin，widget test 需 mock method channel，收益低、维护成本高，属 YAGNI。
- **常量正确性**：可选加轻量单测断言 `privacyPolicyUrl` / `developerEmail` / `playStoreUrl` 格式正确（URL 可解析、邮箱含 `@`、Play 链接含正确包名），防止常量被误改。
- **手动验证**（真机）：
  1. 隐私政策 → 外部浏览器打开 `https://windwalker.51cloud.de/privacy-policy.html`
  2. 联系开发者 → 邮件 app 弹出，收件人 `shiwentao666@gmail.com`，主题预填
  3. 分享 App → 系统分享面板，文本含 appName + Play 链接
  4. 三语切换验证文案

## 风险

- **低。** 改动局限于 `ProfileTab` 的 ListView 内容 + 常量 + 依赖，不触碰任何 controller / service / 路由。
- `url_launcher` / `share_plus` 是成熟官方插件，无平台特定风险。
- `mailto:` 在极少数无邮件客户端的设备上会失败 → 已有 `SnackBar` 反馈兜底。
- Android 需确认 `url_launcher` 是否要加 `<queries>`（Android 11+ 包可见性）。当前只打开 https / mailto scheme，通常需在 `AndroidManifest.xml` 加 `<queries>` 声明 http/https 与 mailto——这是 `url_launcher` 在 Android 11+ 的已知要求，实现时需验证。

## 待实现时确认的点

- Android `AndroidManifest.xml` 是否需要加 `<queries>` for `https` / `mailto` scheme（Android 11+ 包可见性）。实现第一步先验证，缺则补。
