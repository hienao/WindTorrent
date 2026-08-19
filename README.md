# 御风 (WindTorrent)

多下载器管理工具，支持 Aria2、qBittorrent、Transmission。

## 项目结构

```
lib/
  core/
    constants/       # 应用常量
    theme/          # 主题 (Material 3 设计系统)
    utils/          # 工具类 (Log, ResponsiveLayout)
    router/         # 路由配置 (go_router)
  features/
    home/           # 首页 - 下载器列表
    tasks/          # 任务管理
    add_task/       # 添加任务
    downloaders/     # 下载器管理
    settings/       # 设置
  models/           # 数据模型
  services/         # API 服务
  app.dart          # 应用入口
  main.dart         # 主函数
```

## 技术栈

- **Flutter** 3.24.5
- **Provider** 状态管理 (flutter-managing-state)
- **go_router** 声明式路由 (flutter-implementing-navigation-and-routing)
- **GetStorage** 本地存储 (flutter-caching-data)

## 架构规范

本项目严格遵循 [Flutter Skills](https://github.com/flutter/skills) 最佳实践：

### ✅ flutter-architecting-apps
- **分层架构**: UI Layer (Presentation) / Logic Layer / Data Layer
- **单向数据流**: 状态从数据层流向 UI 层
- **单一数据源 (SSOT)**: Repository 模式管理数据

### ✅ flutter-managing-state
- **MVVM 模式**: 使用 Provider + ChangeNotifier
- **Unidirectional Data Flow**: 状态向下流动，事件向上流动
- **ViewModel**: 继承 ChangeNotifier，使用 notifyListeners() 触发重建

### ✅ flutter-building-forms
- **Form Widget**: 使用 GlobalKey<FormState> 管理表单状态
- **验证器**: TextFormField 配合 validator 回调
- **状态持久化**: 表单状态在验证过程中保持

### ✅ flutter-handling-http-and-json
- **HTTPS**: 所有网络请求使用 HTTPS
- **错误处理**: 验证 statusCode 并抛出明确异常
- **手动序列化**: 使用 dart:convert 进行 JSON 解析

### ✅ flutter-implementing-navigation-and-routing
- **go_router**: 声明式路由配置
- **深链接支持**: 通过路径参数和查询参数传递数据
- **嵌套路由**: 支持任务的嵌套路由

### ✅ flutter-theming-apps
- **Material 3**: 使用 useMaterial3: true
- **Design Tokens**: 定义 AppColors、AppSpacing、AppRadius
- **明暗主题**: 同时支持 lightTheme 和 darkTheme

### ✅ flutter-improving-accessibility
- **触摸目标**: 最小 48x48 像素触摸区域
- **语义标签**: 为图标按钮、空状态、卡片添加 Semantics
- **颜色对比度**: 符合 WCAG 4.5:1 标准

### ✅ flutter-caching-data
- **GetStorage**: 用于轻量级设置存储
- **本地缓存**: 下载器列表本地缓存

### ✅ flutter-testing-apps
- **单元测试**: test/unit/models_test.dart
- **Widget 测试**: test/widget/home_page_test.dart

## 日志系统

使用统一的 `Log` 工具类，支持 Android LogCat 和 iOS os_log：

```dart
Log.init(tag: 'WindTorrent');  // 在 main() 中初始化

Log.d('Debug message');        // Debug level
Log.i('Info message');         // Info level
Log.w('Warning message');      // Warning level
Log.e('Error', error: e, stackTrace: st);  // Error level
```

- **Debug 模式**: 使用 `debugPrint`
- **Release 模式**: 自动路由到 Android `Log.d/i/w/e` 或 iOS `os_log`
- **平台通道**: 通过 MethodChannel 与原生日志系统通信

## 支持的下载器

| 下载器 | 协议 | 端口 | 默认 |
|--------|------|------|------|
| Aria2 | JSON-RPC | 6800 | ✅ |
| qBittorrent | WebUI API | 8080 | ✅ |
| Transmission | JSON-RPC | 9091 | ✅ |

## 运行项目

```bash
# 获取依赖
flutter pub get

# 运行项目
flutter run

# 运行测试
flutter test

# 构建 APK
flutter build apk --debug --flavor github
flutter build apk --release --flavor github \
  --dart-define=APP_RELEASE_TRACK=beta
```

Android 使用相同包名 `com.hienao.windtorrent` 的 `play`、`github` 两个分发 flavor。Debug 默认使用 `github + beta`，未配置 keystore 时使用 Android 默认 Debug key；Release 必须通过 `APP_RELEASE_TRACK=stable|beta` 固化更新轨道。公开 PR 只执行静态检查和测试，不读取任何 Secret。

## 发布前：版本号调整（Google Play）

Android 版本号现在由 Flutter 默认机制注入，直接来自 `pubspec.yaml`。  
发布前只需要修改这一个字段：

1. `pubspec.yaml`
- `version: x.y.z+buildNumber`
- 示例：`version: 0.0.2+2026052701`

推荐规则：
- `versionName`（展示版本）使用语义化版本，如 `0.0.2`
- `versionCode`（构建号）必须严格递增，且不能重复
- `versionCode` 必须是正整数，且 **<= 2147483647**（Android `int` 上限）
- 建议使用 10 位：`yyyyMMddNN`（`NN` 为当日递增序号），例如 `2026053001`
- 不要使用 12 位分钟时间戳（如 `202605301528`），会超出上限导致构建失败

映射关系：
- `versionName` = `x.y.z`
- `versionCode` = `buildNumber`
- Android 构建脚本（`android/app/build.gradle`）会直接解析 `pubspec.yaml` 的 `version`，不会再依赖 `android/local.properties` 中的版本字段

本地发布命令（Google Play production 草稿）：
```bash
cd android
dart_defines="$(printf 'APP_RELEASE_TRACK=stable' | base64 | tr -d '\n')"
./gradlew -Pdart-defines="$dart_defines" :app:publishPlayReleaseBundle \
  --track production \
  --release-status draft
```

发布命令需要通过 `ANDROID_KEYSTORE_FILE`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD` 和 `PLAY_SERVICE_ACCOUNT_FILE` 提供签名与 Google Play 凭证；这些文件不会提交到 Git。

GitHub 发布规则：

- PR 合并到 `beta`：仅构建 `github + beta`，在 GitHub Releases 中创建 Pre-release，不构建或上传 Google Play AAB。
- PR 合并到 `main`：并行构建 `github + stable` 和 `play + stable`；前者创建正式 GitHub Release，后者上传 Google Play `production` 轨道为 Draft。
- GitHub Release 同时提供 `arm64-v8a`、`armeabi-v7a`、`x86_64` 和 `universal` APK，并附带渠道 manifest、SHA-256 校验文件及本次合并 PR 的更新内容。
- Universal APK 和校验文件在 Actions Artifact 中保留 7 天；长期下载及分架构 APK 使用 GitHub Releases。Flutter、Pub 与 Gradle 依赖使用 Actions Cache 加速后续构建。
- 普通 push、tag、手动运行以及仅关闭但未合并的 PR 都不会构建 Beta/Release。
- `beta` 版本名必须符合 `x.y.z-beta.n`，`main` 必须为 `x.y.z`；两者的 `versionCode` 都必须大于另一个发布分支的已发布值，保持同包名应用全局单调递增。
- GitHub APK 发布前会将签名证书与仓库变量 `APP_SIGNING_CERT_SHA256` 比较。该变量填写 Play Console“应用签名密钥证书”的 SHA-256；签名 Secret 与 Play 服务账号凭证均从无审批规则的 `google-play-internal` Environment 注入，GitHub 渠道任务不会读取 Play 服务账号凭证。

## 开发

- `main` 分支：正式版，只接受 Release PR 合并
- `beta` 分支：Beta 版，只接受 Beta PR 合并
- `dev` 分支：日常开发版

---

> 御风而行，下载极速
