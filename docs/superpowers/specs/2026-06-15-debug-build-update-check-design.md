# Debug 构建支持 Play 更新检测 — 设计

**日期：** 2026-06-15
**主题：** 放宽 `_defaultIsSupportedBuild` 的 `!kDebugMode` 门禁，让从 Play 安装的 debug 包也能走真实更新检测流程。

## 背景

Play Store 更新子系统当前在 `lib/features/update/data/play_store_update_service.dart:73-77` 用 `!kDebugMode` 把 debug 构建挡在更新流程之外：

```dart
static bool _defaultIsSupportedBuild(PackageInfo packageInfo) {
  return !kDebugMode &&
      defaultTargetPlatform == TargetPlatform.android &&
      isInstalledFromGooglePlay(packageInfo);
}
```

这导致 debug 包（即便从 Google Play 内部测试轨道安装）调用 `checkForUpdate()` 时直接返回 `UpdateCheckResult.unsupported()`，连真实 Play In-App Update API 都不会触发。测试真实更新流程（检测 → 提示 → 跳转 Play 更新）必须打 release 包，迭代成本高。

## 目标

让从 Google Play 安装的 debug 包能调用真实 Play API 走完整更新流程，便于在内部测试轨道上测试。

## 非目标

- 不改节流 / 冷却 / dismiss 逻辑（7 天冷却、dismiss 版本不再弹、当天只弹一次全部保留，与生产一致）。
- 不引入 "debug 模拟结果注入" 类的测试旁路——避免新增仅供测试的分支。
- 不解决 `flutter run` 直接安装的开发包问题——Play API 本身要求应用从 Play 安装，这是 Play Core 库的硬约束，非本设计范畴。

## 方案

将构建类型门禁从 `!kDebugMode` 放宽为"任何构建类型"，保留平台校验与 Play 安装校验：

```dart
static bool _defaultIsSupportedBuild(PackageInfo packageInfo) {
  return defaultTargetPlatform == TargetPlatform.android &&
      isInstalledFromGooglePlay(packageInfo);
}
```

### 行为变化矩阵

| 构建类型 | 平台 | 安装来源 | 改动前 | 改动后 |
|---------|------|---------|-------|-------|
| debug | android | Play | `unsupported` | 调用真实 Play API |
| debug | android | 非 Play（如 `flutter run`） | `unsupported` | `unsupported`（不变） |
| debug | iOS / 其他 | * | `unsupported` | `unsupported`（不变） |
| profile | android | Play | 调用真实 Play API | 调用真实 Play API（不变） |
| release | android | Play | 调用真实 Play API | 调用真实 Play API（不变） |
| `flutter test` | * | * | 通过 `isSupportedBuild` 注入旁路测试 | 不变 |

## 影响范围

**改动文件：** 仅 `lib/features/update/data/play_store_update_service.dart`。
- 73-77 行：移除 `!kDebugMode &&`。
- 23-26 行注释：更新或删除——原注释说"`_defaultIsSupportedBuild` 依赖 `kDebugMode`，在 `flutter test` 下恒为 true，无法直接断言该分支"。改动后该前提不再成立，注释需相应修订。

**不触碰：** `update_prompt_policy.dart`、`update_controller.dart`、`app.dart`、`about_page.dart`、`home_tab_container.dart`、`profile_tab.dart`。

## 测试

- 现有 `test/unit/features/update/play_store_update_service_test.dart` 的 `unsupported` 测试通过注入 `isSupportedBuild: (_) => false` 走旁路，**不依赖 `kDebugMode`，继续通过**。
- 现有节流 / controller / widget 测试均不依赖构建类型门禁，**继续通过**。
- **新增一个红绿回归测试**，直接编码本特性意图："debug 构建从 Play 安装时应走更新流程"。
  - 关键洞察：`flutter test` 下 `kDebugMode` 恒为 `true`，这恰好让"移除 `!kDebugMode`"在单测里**可被**断言——用真实默认 gate（不注入 `isSupportedBuild`），传入 Android + `com.android.vending` 配置：
    - **改动前**（`!kDebugMode && ...`）：因 `kDebugMode` 为 true，gate 短路为 `false` → 返回 `unsupported`，测试 **fail**。
    - **改动后**（`android && fromPlay`）：gate 通过 → 调用注入的 Play 快照 → 返回 `available`，测试 **pass**。
  - 该测试天然锁定 `kDebugMode` 门禁不能被重新加回，符合 TDD red-green 流程。

## 风险

- **低。** release 包门禁条件（android + fromPlay）不变，生产行为零变化。
- debug 包调用真实 Play API 失败时落到 `unknown` 状态，与 profile/release 失败路径一致，UI 已有对应状态展示（About 页 `updateCheckUnavailable`），无新失败模式。
