# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

御风 (WindWalker) - 多下载器管理工具，支持 Aria2、qBittorrent、Transmission 三大下载器的统一管理。

## 常用命令

```bash
# 获取依赖
flutter pub get

# 运行项目
flutter run

# 运行所有测试
flutter test

# 运行指定测试
flutter test test/unit/models_test.dart

# 构建 APK
flutter build apk --debug
flutter build apk --release
```

## 架构规范

### 分层架构
- **UI Layer**: `features/*/presentation/pages/` - Widget 和页面
- **Logic Layer**: `features/*/presentation/controllers/` - ChangeNotifier ViewModels
- **Data Layer**: `services/` + `models/` - API 服务和数据模型

### 状态管理
使用 **Provider + ChangeNotifier** (MVVM 模式)：
- 全局状态通过 `MultiProvider` 在 `app.dart` 中注册
- `DownloaderController`、`TaskController` 和 `SettingsController` 是核心控制器
- ViewModel 继承 `ChangeNotifier`，使用 `notifyListeners()` 触发重建

### 路由
使用 **go_router** 声明式路由，配置在 `lib/core/router/app_router.dart`

### 日志系统
使用统一的 `Log` 工具类 (`lib/core/utils/log.dart`)：
```dart
Log.d('Debug message');      // Debug level
Log.i('Info message');       // Info level
Log.w('Warning message');   // Warning level
Log.e('Error message', error: e, stackTrace: st);  // Error level
Log.init(tag: 'WindWalker'); // 在 main() 中初始化
```
- Debug 模式使用 `debugPrint`
- Release 模式自动路由到 Android LogCat / iOS os_log
- 便于后续替换为 firebase_crashlytics、sentry 等

### 数据持久化
- **GetStorage**: 下载器配置列表
- **shared_preferences**: 用户设置

### Firebase Hosting（隐私政策部署）
```bash
# 部署隐私政策页面
cd firebase-hosting
firebase deploy
# 访问 https://windwalker.51cloud.de/privacy-policy.html
```

### Google Play 发布（Gradle Play Publisher）
```bash
# 1. 进入 Android 工程目录
cd android

# 2. 构建并上传到 Google Play Internal Testing（draft）
./gradlew :app:publishReleaseBundle

# 3. 仅构建（不上传）
./gradlew :app:bundleRelease
```

**前提条件：**
- GitHub Actions 使用受保护 Environment Secret 注入 Google Play 服务账号凭证；凭证文件禁止提交到 Git
- 已安装并配置可用 JDK（建议 17+）
- Play Console 中已完成：商店信息、内容分级、数据安全表单

## 目录结构

```
lib/
  core/
    constants/     # AppConstants、枚举定义
    router/       # go_router 配置
    theme/        # Material 3 主题
    utils/        # 工具类 (Log, ResponsiveLayout)
  features/
    home/         # 首页 - 下载器列表概览
    tasks/        # 任务管理
    add_task/     # 添加下载任务
    downloaders/  # 下载器管理
    settings/     # 应用设置
    update/       # Play 商店更新检测与低打扰提醒（domain/data/presentation/controllers）
  models/         # DownloadTask、Downloader 数据模型
  services/       # 下载器 API 服务
  app.dart        # 应用入口，Provider 配置
  main.dart       # main 函数
test/
  unit/           # 单元测试
  widget/          # Widget 测试
```

## 服务层设计

### DownloaderService 抽象类 (`lib/services/base_downloader_service.dart`)
所有下载器服务继承此基类，提供统一接口：
- `testConnection()` - 测试连接
- `getTasks()` - 获取任务列表
- `getGlobalStat()` - 获取全局统计
- `addDownload()` / `pauseTask()` / `resumeTask()` / `removeTask()` - 任务操作

### 具体实现
- `Aria2Service` - JSON-RPC 协议，端口 6800
- `QBitService` - facade 模式，自动探测 qBittorrent 4.1–4.6.x（legacy，pause/resume 端点）/ 5.0+（modern，stop/start 端点）代际，端口 8080
  - 内部由 `QBitVersionDetector` + `QBitSession` + `QBitV4Adapter` / `QBitV5Adapter` 实现，共享逻辑在 `QBitBaseApiAdapter`
  - 任务详情接口：`getTaskFullDetail`/`getTaskFiles`/`getTaskSources`/`getTaskPeers`/`getTaskOptions`/`updateTaskOptions`，合并 `/torrents/info`、`/properties`、`/trackers`、`/webseeds`、`/files`、`/sync/torrentPeers`、`/categories`、`/tags` 端点
- `TransmissionService` - facade 模式，自动识别 modern（4.1.0+ JSON-RPC 2.0）/ legacy（<4.1.0）协议，端口 9091
  - 内部由 `TransmissionProtocolDetector` + `TransmissionModernRpcAdapter` / `TransmissionLegacyRpcAdapter` 实现

### 服务工厂
`DownloaderController._createService()` 根据下载器类型创建对应服务实例。

## 更新检测子系统 (`lib/features/update/`)

基于 Google Play 官方能力的静默更新检测与低打扰提醒，仅 Android 正式包（非 debug + Android + Play 安装来源）启用。参考设计：`docs/superpowers/specs/2026-06-15-play-store-update-check-design.md`。

- **`PlayStoreUpdateService`** (`data/`) - 调用 `InAppUpdate.checkForUpdate()` 与 `InAppReview.openStoreListing()`，返回四态 `UpdateCheckResult`（unsupported/unknown/upToDate/available）。依赖全 typedef 注入以便单测；检查失败降级为 `unknown` + 日志（非主流程，允许静默降级，不伪造"已最新"）。
- **`UpdatePromptPolicy`** (`domain/`) - 纯函数决策器，输出 `none / badgeOnly / dialogAllowed`。有活跃下载、会话已消费、同版本已 dismiss、今日已弹、冷却期（默认 7 天）内 → badgeOnly。
- **`UpdateController`** (`presentation/controllers/`) - ChangeNotifier，协调检查/持久化（GetStorage）/节流，暴露 `status`/`hasUpdate`/`shouldShowUpdateBadge`/`shouldOfferUpdateDialog`。通过 `ChangeNotifierProxyProvider` 绑定 `TaskController`，有活跃下载（`hasActiveTransfers`）时压制弹窗。
- **UI 接入** - `about_page`（检查更新入口 + 四态文案）、`profile_tab`（轻提示 badge）、`home_tab_container`（首屏稳定后静默检查并消费一次温和弹窗机会）。

## 数据模型

### Downloader (`lib/models/downloader.dart`)
- `id`, `name`, `type`, `host`, `port`
- `secret` (Aria2 RPC 密钥)
- `username` / `password` (qBit/Trans)
- `status`, `downloadSpeed`, `uploadSpeed`

### DownloadTask (`lib/models/download_task.dart`)
- `id`, `gid`, `name`, `status`
- `totalSize`, `downloaded`, `progress`
- `downloadSpeed`, `uploadSpeed`
- `savePath`, `downloaderId`

### qBit Task Detail Models (`lib/models/qbit_task_*.dart`)
- `QBitTaskDetail` - 合并 info/properties/trackers/webseeds 的信息主页读模型
- `QBitTaskFileNode` - 只读文件树节点（目录/文件，含格式化大小和进度）
- `QBitTaskSource` - 来源统计卡模型（DHT/PeX/LSD/tracker-like sources）
- `QBitTaskPeer` - 节点行模型（address/port/protocol/speeds/progress/relevance）
- `QBitTaskOptions` - 选项读模型（queue position/category/tags/available catalogs）
- `QBitTaskOptionsUpdate` - 选项写入载荷（queue action/category/tag reconciliation）
- `QBitQueuePriorityAction` - 队列动作枚举（unchanged/increase/decrease/top/bottom）

## 路由配置

```dart
/               → HomePage
/tasks          → TasksPage
/tasks/detail/:id → TaskDetailPage (按下载器类型分派: qBit → QBitTaskDetailPage / Trans → TransmissionTaskDetailPage / 其他 → GenericTaskDetailPage)
/tasks/detail/:id/qbit/files   → QBitTaskFilesPage (qBit 文件树)
/tasks/detail/:id/qbit/sources → QBitTaskSourcesPage (qBit 来源/Tracker)
/tasks/detail/:id/qbit/peers   → QBitTaskPeersPage (qBit 节点)
/tasks/detail/:id/qbit/options → QBitTaskOptionsPage (qBit 选项编辑: 队列/分类/标签)
/tasks/detail/:id/transmission/files   → TransmissionTaskFilesPage
/tasks/detail/:id/transmission/trackers → TransmissionTrackersPage
/add-task       → AddTaskPage (支持 ?url= 参数)
/downloaders    → DownloadersPage
/settings       → SettingsPage
```

## 注意事项

1. **控制器初始化**: `DownloaderController` 构造函数不执行初始化，`init()` 方法需由 UI 层调用以避免阻塞启动。
2. **日志系统**: 使用统一的 `Log` 工具类，在 main() 中调用 `Log.init()` 初始化。

## 编码规范：禁止防御性编程

本项目采用 **fail-fast** 原则：错误必须显式传播，禁止用默认值掩盖失败。对齐现有 `auth_controller` 的分层异常范式与 `ConnectionResult` 的类型化设计。

### 禁止的模式

**1. 静默吞异常** —— `catch` 捕获异常后返回默认值（空列表/空 Map/false/void/空串）且不向调用方传播失败信号。
```dart
// ❌ 禁止
try { return await api.getTasks(); } catch (e) { return []; }

// ✅ 抛出，由 controller 捕获并传播给 UI
try { return await api.getTasks(); } catch (e) { throw Exception('获取任务失败: $e'); }
```

**2. 不可能为 null 的 null 检查** —— 类型已是 non-nullable，或控制流已保证非空（如 switch 穷举枚举的返回值）时，不得写 `if (x == null)`。
```dart
// ❌ 禁止：_createService 的 switch 已穷举 DownloaderType，返回值不可能为 null
final service = _createService(type);
if (service == null) return;
```

**3. try-catch 处理"未找到"等正常控制流** —— 应用 `firstWhereOrNull` / `where().firstOrNull`，而非 try-catch 包裹 `firstWhere`。
```dart
// ❌ 禁止
try { return list.firstWhere((d) => d.id == id); } catch (e) { return null; }

// ✅
return list.where((d) => d.id == id).firstOrNull;
```

**4. 吞掉致命初始化错误** —— 应用启动关键初始化（Firebase、GetStorage 等）失败不得 catch 后继续运行。
```dart
// ❌ 禁止
try { await Firebase.initializeApp(); } catch (e) { Log.e(...); } // 继续 runApp

// ✅ 让异常传播（fail fast），或进入明确降级态
```

**5. 内部已保证字段的兜底** —— 内部创建/传递的对象字段，不得用 `?? defaultValue` 掩盖本应暴露的 bug。
```dart
// ❌ 禁止：downloaderId 是 WindWalker 自身必填字段，缺失即是 bug
downloaderId: json['downloaderId'] ?? ''
```

**6. 重复参数/状态验证** —— 同一前置条件不得在多个方法里反复校验，应抽取 helper 或靠类型/契约保证。

### 错误传播规范

- **service 层**：移除静默 catch，抛出异常（可保留网络 I/O 外层 try-catch，但捕获后必须抛出/传播）
- **controller 层**：catch 异常 → 写入 `errorState`/`errorMessage` 字段 → `notifyListeners()`
- **UI 层**：根据 errorState 显式区分"空数据"与"加载失败"两种状态

### 外部数据解析（分层 fail-fast）

解析下载器 API 响应、用户输入、持久化数据时：
- **协议必填字段**（ID/name/status 等）缺失或类型错 → **抛出解析异常**
- **可选/统计字段** → 用 **nullable 类型**，UI 显式处理 null（不用 `?? 0` 伪装成有值）
- **未知枚举值** → 归入 `unknown`/default 分支 + **告警日志**（便于发现新枚举值）

### 允许的例外（合理边界处理，不算防御性编程）

1. 网络请求外层 `try-catch`（捕获 `SocketException`/`Timeout`）——但捕获后**必须抛出或传播**，不得返回默认值
2. Flutter `if (!mounted) return;`（async gap 后的框架要求）
3. `copyWith` 的 `?? this.xxx`（Dart 语言惯例）；可空字段的"清空 vs 不改"用显式布尔参数（参考 `add_task_request.dart` 的 `clearUrl` 模式）
4. 枚举 `default` 分支归 `unknown` + 告警日志
5. 日志/埋点等次要功能失败时降级（不影响主流程）
6. 幂等保护（如 `if (_initialized) return;`）
