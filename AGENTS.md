# PROJECT KNOWLEDGE BASE

**Generated:** 2026-08-17
**Commit:** 8235bc1
**Branch:** (current branch)

## OVERVIEW
WindWalker - Multi-downloader manager supporting Aria2, qBittorrent, and Transmission. Flutter 3.24.5 app with Provider state management and go_router routing.

## STRUCTURE
```
lib/
├── core/
│   ├── constants/     # AppConstants, enums
│   ├── router/        # go_router config
│   ├── theme/         # Material 3 theme
│   └── utils/         # Utilities (Log, ResponsiveLayout)
├── features/
│   ├── add_task/      # Add download task
│   ├── downloaders/   # Downloader management
│   │   └── controllers/  # DownloaderController
│   ├── home/          # Dashboard
│   ├── settings/      # App settings
│   │   └── controllers/  # SettingsController
│   └── tasks/         # Task management
│       └── controllers/  # TaskController
├── models/            # DownloadTask, Downloader
├── services/          # Aria2/qBit/Transmission APIs
├── app.dart           # Provider + router bootstrap
└── main.dart          # Entry point
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add feature | `features/<name>/presentation/` | Follow existing pattern |
| State management | `lib/app.dart` + `features/*/controllers/` | Provider + ChangeNotifier |
| Routing | `lib/core/router/app_router.dart` | go_router declarative |
| Downloader services | `lib/services/` | Service factory pattern |
| 埋点 (Analytics) | `lib/services/analytics_service.dart` | 统一入口，隐私护栏，env params 自动注入 |
| Data models | `lib/models/` | Downloader, DownloadTask |
| Logging | `lib/core/utils/log.dart` | Unified Log utility |

## CODE MAP

### Entry Points
- `lib/main.dart` — Initializes GetStorage, calls runApp()
- `lib/app.dart` — MultiProvider setup, MaterialApp.router

### Core Services (lib/services/)
- `base_downloader_service.dart` — Abstract base class
- `aria2_service.dart` — JSON-RPC, port 6800
- `qbit_service.dart` — WebUI API, port 8080
- `transmission_service.dart` — JSON-RPC, port 9091

### Models (lib/models/)
- `downloader.dart` — Downloader config (host, port, credentials)
- `download_task.dart` — Task state (gid, progress, speeds)

### Feature Controllers (lib/features/*/presentation/controllers/)
- `downloaders/downloader_controller.dart` — Downloader CRUD + service factory
- `tasks/task_controller.dart` — Task list + operations
- `settings/settings_controller.dart` — App settings (Provider pattern)

### Utilities (lib/core/utils/)
- `log.dart` — Unified logging utility with Android/iOS platform support
- `responsive_layout.dart` — Responsive layout helpers

## CONVENTIONS (THIS PROJECT)
- Pages: `*_page.dart` (e.g., `home_page.dart`)
- Controllers: `*_controller.dart` (ChangeNotifier)
- Services: `*_service.dart`
- Models: PascalCase .dart files
- Routing: Named routes via `GoRoute`
- Logging: Use `Log.d()` / `Log.i()` / `Log.w()` / `Log.e()` from `lib/core/utils/log.dart`

## LOGGING
Use `Log` utility from `lib/core/utils/log.dart`:
```dart
Log.d('Debug message');      // Debug level
Log.i('Info message');        // Info level
Log.w('Warning message');     // Warning level
Log.e('Error message', error: e, stackTrace: st);  // Error level
Log.init(tag: 'WindWalker'); // Initialize at app start
```

Platform-native logging (Android LogCat, iOS os_log) is used automatically.

## ANTI-PATTERNS (THIS PROJECT)
- **Controller init() pattern** — DownloaderController requires UI to call init() explicitly
- **sample_feature missing** — Referenced in docs but doesn't exist
- **防御性编程（禁止）** — 本项目采用 fail-fast 原则。详见 `CLAUDE.md` 的「编码规范：禁止防御性编程」章节。核心：禁止静默吞异常（catch 后返回默认值不传播）、禁止不可能为 null 的 null 检查、禁止 try-catch 处理"未找到"（用 firstWhereOrNull）、禁止吞致命初始化错误。错误传播链：service 抛异常 → controller 写 errorState → UI 显示。

## UNIQUE STYLES
- Feature-sliced but data layer centralized (lib/models/ + lib/services/)
- 3/5 features lack controllers (add_task, home)
- Only features/tasks, features/downloaders, and features/settings have full presentation/controllers/

## COMMANDS
```bash
flutter pub get
flutter run
flutter test
flutter test test/unit/models_test.dart
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

## Google Play 发布（Gradle Play Publisher）
```bash
# 进入 Android 工程
cd android

# 构建并上传到 Internal Testing（draft）
./gradlew :app:publishReleaseBundle

# 仅构建（不上传）
./gradlew :app:bundleRelease
```

**前提条件：**
- GitHub Actions 使用受保护 Environment Secret 注入 Google Play 服务账号凭证；凭证文件禁止提交到 Git
- 已安装并配置可用 JDK（建议 17+）
- Play Console 中已完成：商店信息、内容分级、数据安全表单

## FIREBASE HOSTING（隐私政策部署）
项目目录：`/firebase-hosting/`
```bash
# 安装 Firebase CLI
npm install -g firebase-tools

# 登录
firebase login

# 进入目录并初始化（如尚未初始化）
cd firebase-hosting
firebase init hosting
# 选择 windwalker-a37d0 项目，public 目录选 public，single-page: No

# 部署隐私政策页面
firebase deploy
# 访问 https://windwalker.51cloud.de/privacy-policy.html
```

## GOTCHAS
1. DownloaderController.init() must be called by UI to avoid blocking startup
2. Seed file selection in add_task unimplemented (TODO in code)
3. Android applicationId and signing config are TODOs in build.gradle
4. Log.init() should be called early in main() for platform logging
