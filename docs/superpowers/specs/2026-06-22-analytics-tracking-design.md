# WindWalker App 内埋点设计

**日期：** 2026-06-22
**分支：** dev
**状态：** 待实施

---

## 1. 背景与目标

WindWalker 是支持 Aria2、qBittorrent、Transmission 的多下载器管理工具。项目已集成 `firebase_analytics`，并有一个 `AuthTelemetryService` 范本（Google 登录结果埋点），但其余核心业务路径尚未埋点。

本设计的目标是建立**完整、隐私安全、可维护**的埋点体系，覆盖四大业务诉求：

1. **留存与活跃分析** — DAU/WAU/留存率、会话时长
2. **核心漏斗转化** — 新增下载器 → 添加任务 → 任务操作 → 持续使用
3. **故障与稳定性监控** — 连接失败、任务操作失败、登录失败、初始化失败的归因
4. **功能使用度与画像** — 下载器类型占比、主题/语言偏好分布、更新弹窗接受率等

## 2. 设计决策摘要

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 架构方案 | 统一 `AnalyticsService` 单例 + 重构 `AuthTelemetryService` | 复用现有 Firebase 基础设施，集中管理 env params 与 user_property，消除现有重复代码 |
| 隐私边界 | **严格** — 不记录 host/port/URL/文件名/任务名等用户内容 | 本项目是个人下载器管理工具，用户内容可能含敏感信息 |
| 登录要求 | 匿名也可用全功能 | 埋点区分 `is_anonymous`，但不强制登录 |
| 用户分群 | 使用 Firebase `user_property` | 便于跨会话分析用户画像 |
| 命名规范 | 沿用现有 `xxx_result` + `result/error_type/reason` 三件套 | 与 `auth_google_sign_in_result` 对齐，一致性优先 |

## 3. 整体架构

### 3.1 核心基础设施

新建 `lib/services/analytics_service.dart`，作为唯一埋点入口：

```dart
class AnalyticsService {
  static final instance = AnalyticsService._();

  /// 统一事件上报（自动合并 env params + 隐私护栏）
  Future<void> track(String name, {Map<String, Object>? params});

  /// 设置用户属性（分群）
  Future<void> setUserProperty(String key, String? value);

  /// 批量刷新用户属性（登录态变化时调用）
  Future<void> refreshUserProperties({required AuthSnapshot snapshot});

  /// 绑定/解绑用户 ID
  Future<void> setUserId(String? uid);

  /// 退出登录时清理用户属性
  Future<void> resetUserProperties();
}
```

现有 `AuthTelemetryService` 重构为薄封装：内部改为调用 `AnalyticsService.instance.track(...)`，env params 由底层服务自动注入，保持外部 API 不变（向后兼容，零回归）。

### 3.2 命名约定

- **事件名**：`snake_case`，模块前缀（如 `downloader_add_result`、`task_action_result`、`update_prompt_response`）
- **参数名**：`snake_case`，全埋点共用一组标准参数名
- **结果类参数**：统一用 `result: 'success' | 'failed'`
- **错误类参数**：`error_type`（高层分类）+ `reason`（细分），与现有 auth 埋点对齐

### 3.3 公共参数（自动注入，无需手动传）

| 参数 | 来源 | 示例 |
|------|------|------|
| `app_version` / `app_build` | PackageInfo | `1.0.3` / `2026062104` |
| `platform` / `os_version` | Platform | `android` / `15` |
| `locale` | PlatformDispatcher | `zh-CN` |
| `network_type` | connectivity_plus | `wifi` / `mobile` |
| `android_api_level` / `android_release` | device_info_plus | `35` / `15` |
| `is_anonymous` | AuthController | `true` / `false` |
| `user_role` | UserRoleService | `normal` / `vip` |

### 3.4 隐私护栏（硬规则，写入服务层）

在 `AnalyticsService.track()` 内置**字段黑名单**，关键字命中则：
- **Debug 模式**：抛 `ArgumentError`（尽早暴露开发期违规）
- **Release 模式**：截断该字段 + `Log.w` 告警

黑名单关键字（字段名包含即拦截）：

```
url, host, port, path, secret, password, token,
task_name, file_name, display_name, email, phone,
save_path, tracker
```

`user_property` 也走同一套黑名单校验。

---

## 4. 启动与生命周期埋点

**目标**：留存活跃基石。Firebase 自动采集 `session_start` / `user_engagement` / `first_open`，本模块只补**启动性能**和**初始化失败**。

复用现有 `lib/core/utils/startup_trace.dart`，接入 `AnalyticsService`。

| 事件名 | 触发点 | 参数 | 用途 |
|--------|--------|------|------|
| `app_first_open_tracked` | 首次安装后 `main()` 首次执行（GetStorage 标记位 `app_first_open`） | 无额外 | 区分新增 vs 老用户（补 Firebase `first_open` 在卸装重装时失效的场景） |
| `app_launch` | `runApp()` 后首个 frame 构建完成（复用 `StartupTrace.markFirstFrameBuilt`） | `cold_start: bool`（best-effort）、`launch_duration_ms: int`（`main_enter` 到首个 frame 耗时）、`init_phase: String`（正常为 `completed`，初始化失败时为 phase 名） | 启动性能 P50/P90 |
| `app_init_failed` | `main()` 中 Firebase/GetStorage 初始化抛异常前 | `phase: 'firebase' \| 'get_storage' \| 'system_ui'`、`error_type: String` | 致命初始化失败监控 |

**fail-fast 原则不变**：`main()` 中用 `try/catch` + `rethrow`，catch 块内只上报事件后重新抛出，**不吞异常**。

---

## 5. 认证模块埋点

**现状**：`AuthTelemetryService` 已埋 `auth_google_sign_in_result`。本节补退出、登录态切换、用户属性同步。

| 事件名 | 触发点 | 参数 | 用途 |
|--------|--------|------|------|
| `auth_google_sign_in_result` | （已存在）登录成功/失败 | 沿用 `result/error_type/reason/provider_code` | 不改 |
| `auth_sign_out_result` | `AuthController.signOut()` 完成 | `result: 'success' \| 'failed'`、`error_type: String?` | 登出成功率、流失节点关联 |
| `auth_session_state_changed` | `_authSub` 监听到登录态翻转（有→无 或 无→有，避免重复触发） | `state: 'signed_in' \| 'signed_out'`、`source: 'cache' \| 'provider' \| 'explicit'` | 匿名→登录的留存分群、被动登出（token 失效）监控 |

**用户 ID 绑定**
- 登录成功：`AnalyticsService.setUserId(authUser.uid)`（原值，Firebase 自身持有该 uid）
- 登出/被动登出：`AnalyticsService.setUserId(null)`
- 匿名用户不上报 `user_id`（保留 Firebase 自动生成的 app instance id）

**漏斗关系**：`app_launch` → `app_first_open_tracked`（首次）→ `auth_google_sign_in_result(success)` → `auth_session_state_changed(signed_in)`。

---

## 6. 下载器模块埋点

**埋点位置策略**：埋在 controller 层（`addDownloader`/`updateDownloader`/`removeDownloader`/`refreshStatus`），单一入口，覆盖所有调用方。

| 事件名 | 触发点 | 参数 | 用途 |
|--------|--------|------|------|
| `downloader_add_result` | `addDownloader()` 返回后 | `result`、`type: 'aria2' \| 'qbittorrent' \| 'transmission'`、`failure_category: 'network' \| 'auth' \| 'version_unsupported' \| 'unknown'`、`use_https: bool` | 新增漏斗、类型占比、连接失败归因 |
| `downloader_update_result` | `updateDownloader()` 返回后 | 同上 | 配置变更成功率、版本不兼容占比 |
| `downloader_remove` | `removeDownloader()` 完成 | `type: String` | 用户流失节点、删除诱因分析 |
| `downloader_status_changed` | `refreshStatus()` 中状态跨阈值翻转时（online↔offline，非每次刷新） | `type: String`、`transition: 'online_to_offline' \| 'offline_to_online'`、`consecutive_failures: int` | 下载器可用性、断连频率 |

**关键设计点**
1. `refreshStatus` 每 20 秒定时刷新**不埋点**（噪声），仅状态翻转时上报。
2. `failure_category` 直接映射 `ConnectionFailure.category`，无需重新分类。
3. **不埋 host/port/secret/username/password**（隐私护栏）。

**漏斗关系**：`downloader_add_result(success)` → `task_add_result` → `task_action_result`。

---

## 7. 任务模块埋点

### 7.1 前置清理（列入实施计划）

`TaskController` 和 `DownloaderController` 中 UI 零调用的遗留接口，整组删除：

**`TaskController` 待删方法（`task_controller.dart`）**
| 待删方法 | 行号 | 理由 |
|--------|------|------|
| `pauseTask` / `resumeTask` / `removeTask` / `addDownload`（无 ForDownloader 后缀） | `399-467` | 生产 UI 仅用 `*ForDownloader` 新接口 |
| `loadTasks` / `loadTaskDetail`（旧接口） | `333-384` | 生产 UI 仅用 `loadTasksForDownloader` / `loadTaskDetailForDownloader` |
| `searchTasks` | `470` | 仅读取 `_tasks`（旧字段），UI 用内联 `_filterTasks` |
| `_tasks` / `_isLoading` 兼容字段及 getters | `36-37, 100-101` | 仅供旧接口使用 |
| `setCurrentDownloaderId`（setter）+ `currentDownloaderId`（getter） | `102-109` | 仅旧接口引用。**保留私有字段 `_currentDownloaderId`**（`clearCurrentTaskForDetail` 仍读写它），仅删公开 setter 和 getter |

**`DownloaderController` 待删方法（`downloader_controller.dart`）**
| 待删方法 | 行号 | 理由 |
|--------|------|------|
| `addDownload` / `addTask`（旧 URL 入口） | `203-246` | 生产 UI 零调用，仅测试覆盖 |

**注意边界**：**service 层**（`BaseDownloaderService` 及各 `*Service` / `*Adapter`）的 `pauseTask/resumeTask/removeTask/addDownload/addTask` **不动**——它们是现役抽象契约，被 `*ForDownloader` 新接口内部调用。

### 7.2 埋点清单

| 事件名 | 触发点 | 参数 | 用途 |
|--------|--------|------|------|
| `task_add_result` | `TaskController.addTask` 返回后 | `result`、`source: 'url' \| 'torrent' \| 'unknown'`、`downloader_type: String`、`has_save_path: bool`、`error_type: String?` | 添加漏斗、来源占比、失败归因 |
| `task_action_result` | `pause/resume/removeTaskForDownloader` 返回后 | `action: 'pause' \| 'resume' \| 'remove'`、`result`、`downloader_type`、`delete_files: bool?`（仅 remove）、`error_type: String?` | 操作成功率、删文件偏好 |
| `task_list_viewed` | `TasksPage.initState` postFrame | `downloader_type`、`task_count`、`active_count`（downloading+waiting） | 使用度、负载画像 |
| `task_detail_viewed` | `TaskDetailPage.initState` postFrame | `downloader_type`、`task_status` | 详情页流量 |

**user_property 同步**

| 属性名 | 值 | 更新时机 |
|--------|----|----|
| `has_active_task` | bool | `refreshGlobalStats` 完成后 |

---

## 8. 更新模块埋点

| 事件名 | 触发点 | 参数 | 用途 |
|--------|--------|------|------|
| `update_check_result` | `UpdateController.runSilentCheck` / `checkForUpdatesManually` 返回后 | `result: 'available' \| 'up_to_date' \| 'unsupported' \| 'unknown'`、`source: 'silent' \| 'manual'`、`available_version_code: int?` | 更新可用率、检查成功率 |
| `update_prompt_response` | `UpdateController.openStorePage`（接受）/ `dismissCurrentVersion`（忽略） | `response: 'accepted' \| 'dismissed'`、`available_version_code: int?` | 更新弹窗转化漏斗、版本忽略率 |

---

## 9. 评价模块埋点

`ReviewManager` 有四条触发信号 + 90 天冷却。

| 事件名 | 触发点 | 参数 | 用途 |
|--------|--------|------|------|
| `review_prompt_shown` | `ReviewManager._maybeRequestReview` 通过冷却检查后、调 `requestReview` 前 | `trigger: 'first_downloader' \| 'successful_task_add' \| 'completed_task' \| 'healthy_usage'` | 评价提示曝光量、各触发路径占比 |
| `review_prompt_result` | `requestReview` try/catch 返回后 | `result: 'completed' \| 'failed'`、`trigger: String`、`error_type: String?` | In-App Review API 成功率 |

**约束**：`InAppReview.requestReview()` 不返回用户是否真的评分，只能知道「弹窗是否成功唤起」。设计上**不追求真实评分转化率**。

**触发顺序**：业务信号 → `review_prompt_shown` → 调 `requestReview` → `review_prompt_result`。确保即使 API 异常也有曝光记录。

---

## 10. 设置模块埋点

| 事件名 | 触发点 | 参数 | 用途 |
|--------|--------|------|------|
| `settings_theme_mode_changed` | `SettingsController.setAppThemeMode` | `from: 'system' \| 'light' \| 'dark'`、`to: 'system' \| 'light' \| 'dark'` | 主题偏好分布、切换路径 |
| `settings_language_changed` | `SettingsController.setAppLocale` | `from: 'system' \| 'en' \| 'zh' \| 'ja'`、`to: 'system' \| 'en' \| 'zh' \| 'ja'` | 语言偏好分布、切换路径 |

**不埋**：设置页浏览（依赖 Firebase 自动 `screen_view`）、登出（已在第 5 节 `auth_sign_out_result` 覆盖）。

---

## 11. user_property 全表

| 属性名 | 来源 | 更新时机 |
|--------|------|----|
| `is_anonymous` | AuthController | 登录态变化 |
| `user_role` | UserRoleService | 登录后角色获取 |
| `account_age_days` | Firebase user metadata | 登录后（best-effort，无注册时间则不设） |
| `downloader_count` | DownloaderController | 增删下载器后 |
| `downloader_types` | DownloaderController | 增删下载器后 |
| `has_online_downloader` | DownloaderController | 状态翻转时 |
| `has_active_task` | TaskController | `refreshGlobalStats` 后 |
| `theme_mode` | SettingsController | 主题切换后 |
| `app_locale` | SettingsController | 语言切换后 |

---

## 12. 实施优先级

分两批，避免单次改动过大。

### P0 批次（核心漏斗 + 故障监控，价值最高）
1. 新建 `AnalyticsService` + 重构 `AuthTelemetryService`
2. 启动 3 个事件 + user_property 同步
3. 认证补 2 个事件（`sign_out` / `session_state_changed`）+ user_property 同步
4. 任务模块前置清理（删旧接口）
5. 下载器 4 个事件 + user_property 同步
6. 任务 4 个事件 + user_property 同步

### P1 批次（软指标）
7. 更新 2 个事件
8. 评价 2 个事件
9. 设置 2 个事件 + user_property 同步

---

## 13. 测试策略

- **`AnalyticsService` 单元测试**：用 `MethodChannel` mock Firebase Analytics（`setMockMessageHandler`），断言事件名/参数；隐私护栏黑名单用例（传入含 `url`/`host` 等关键字的参数，断言 release 截断 / debug 抛异常）。
- **Controller 集成测试**：现有 mockito 测试注入 mock `AnalyticsService`，验证关键路径触发正确事件。
- **回归测试**：`AuthTelemetryService` 重构后，`auth_controller_test.dart` 等既有测试应全部通过（API 不变）。

---

## 14. 漏斗全景

```
app_launch → app_first_open_tracked（首次）
       ↓
auth_google_sign_in_result(success) → auth_session_state_changed(signed_in)
       ↓
downloader_add_result(success)
       ↓
task_add_result(success) → review_prompt_shown（累计成功触发）
       ↓
task_action_result → task_list_viewed / task_detail_viewed（留存信号）
       ↓
update_check_result(available) → update_prompt_response(accepted)
```

---

## 15. 隐私合规说明

- 不收集任何用户内容（host/port/URL/文件名/任务名/savePath/tracker 等）
- 仅收集聚合指标（类型、状态、数量、结果、错误分类）
- `user_id` 为 Firebase 生成的随机 ID，不含邮箱/手机号
- 所有用户属性不含敏感字段
- 需在隐私政策中披露使用 Firebase Analytics 进行使用数据收集
