# Debug 构建支持 Play 更新检测 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让从 Google Play 安装的 debug 包能调用真实 Play In-App Update API 走完整更新检测流程，便于在内部测试轨道上测试。

**Architecture:** 收缩 `PlayStoreUpdateService._defaultIsSupportedBuild` 的门禁条件——移除 `!kDebugMode`，保留平台校验（android）与 Play 安装校验（`isInstalledFromGooglePlay`）。其余子系统（policy / controller / UI）零改动。

**Tech Stack:** Dart, Flutter, `in_app_update`, `package_info_plus`, `flutter_test`。

**Spec:** `docs/superpowers/specs/2026-06-15-debug-build-update-check-design.md`

---

## 关键测试设计原理（执行前必读）

回归测试用真实默认 gate（**不注入 `isSupportedBuild`**），靠 `flutter test` 的两个恒定行为制造 red→green：

| 条件 | `flutter test` 下的值 |
|------|----------------------|
| `kDebugMode` | 恒 `true` |
| `defaultTargetPlatform` | 默认 `iOS`（需用 `debugDefaultTargetPlatformOverride` 覆盖为 android） |

- **改动前**（`!kDebugMode && android && fromPlay`）：因 `kDebugMode == true`，`!kDebugMode == false`，gate 短路为 `false` → 返回 `unsupported`。测试断言 `available` → **red**。
- **改动后**（`android && fromPlay`）：gate 通过 → 调用注入快照 → 返回 `available`。测试 → **green**。

这个测试天然锁死 `kDebugMode` 门禁不能被重新加回。

---

### Task 1: 写失败回归测试（red）

**Files:**
- Modify: `test/unit/features/update/play_store_update_service_test.dart`

- [ ] **Step 1: 添加 `flutter/foundation` import**

在 `test/unit/features/update/play_store_update_service_test.dart` 顶部 import 区（第 1-4 行），确认已有 `import 'package:flutter_test/flutter_test.dart';`。在其下方新增：

```dart
import 'package:flutter/foundation.dart';
```

最终顶部 import 区为：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:windwalker/features/update/data/play_store_update_service.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
```

- [ ] **Step 2: 在 `_packageInfo` 之后、`void main()` 之前，添加平台覆盖 helper**

定位 `_packageInfo` 函数（当前第 6-13 行）结尾的 `);` 之后、`void main() {` 之前，插入：

```dart

Future<void> _withAndroidPlatform(Future<void> Function() body) async {
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}
```

- [ ] **Step 3: 在 `PlayStoreUpdateService` group 末尾追加 red 测试**

在 `group('PlayStoreUpdateService', ...)` 内，紧接 `'service returns unknown when Play check throws'` 测试的闭合 `});`（当前第 81 行）之后，插入新测试：

```dart

    test('debug build installed from Play proceeds to update flow', () async {
      // flutter test 下 kDebugMode 恒为 true。
      // 不注入 isSupportedBuild → 走真实默认 gate。
      // 改动前（!kDebugMode && ...）：gate 短路为 false → unsupported。
      // 改动后（android && fromPlay）：gate 通过 → 调用快照 → available。
      await _withAndroidPlatform(() async {
        final service = PlayStoreUpdateService(
          packageInfoLoader: () async =>
              _packageInfo(installerStore: 'com.android.vending'),
          checkForUpdate: () async => const PlayUpdateSnapshot(
            isUpdateAvailable: true,
            availableVersionCode: 2026061501,
          ),
        );

        final result = await service.checkForUpdate();
        expect(result.status, UpdateCheckStatus.available);
        expect(result.availableVersionCode, 2026061501);
      });
    });
```

注意：此测试**故意不传 `isSupportedBuild`** 参数——这是测试的关键，让它走真实的 `_defaultIsSupportedBuild` 默认实现。

- [ ] **Step 4: 运行测试确认新测试失败（red）**

Run: `flutter test test/unit/features/update/play_store_update_service_test.dart`
Expected: **FAIL**。新测试 `'debug build installed from Play proceeds to update flow'` 失败——当前 `_defaultIsSupportedBuild` 含 `!kDebugMode`，在 `flutter test`（`kDebugMode == true`）下短路为 false，返回 `unsupported` 而非 `available`：
```
Expected: UpdateCheckStatus.available
  Actual: UpdateCheckStatus.unsupported
```
其余 4 个现有测试（`unsupported` / `available` / `upToDate` / `unknown`）应继续 PASS——它们都注入了 `isSupportedBuild`，gate 短路在注入逻辑里，不受平台覆盖与 `kDebugMode` 影响。

- [ ] **Step 5: 提交 red 测试**

```bash
git add test/unit/features/update/play_store_update_service_test.dart
git commit -m "test: add red test for debug build play update flow"
```

---

### Task 2: 移除 `!kDebugMode` 门禁（green）

**Files:**
- Modify: `lib/features/update/data/play_store_update_service.dart:73-77`（gate 实现）
- Modify: `lib/features/update/data/play_store_update_service.dart:21-26`（过时注释）

- [ ] **Step 1: 移除 `_defaultIsSupportedBuild` 中的 `!kDebugMode &&`**

将 `lib/features/update/data/play_store_update_service.dart:73-77`：

```dart
  static bool _defaultIsSupportedBuild(PackageInfo packageInfo) {
    return !kDebugMode &&
        defaultTargetPlatform == TargetPlatform.android &&
        isInstalledFromGooglePlay(packageInfo);
  }
```

改为：

```dart
  static bool _defaultIsSupportedBuild(PackageInfo packageInfo) {
    return defaultTargetPlatform == TargetPlatform.android &&
        isInstalledFromGooglePlay(packageInfo);
  }
```

- [ ] **Step 2: 更新 `isInstalledFromGooglePlay` 上方过时注释**

将 `lib/features/update/data/play_store_update_service.dart:21-24`：

```dart
/// 判断应用是否从 Google Play 商店安装。
///
/// 抽成纯函数以便单测覆盖 installer 判定（`_defaultIsSupportedBuild` 依赖
/// `kDebugMode`，在 `flutter test` 下恒为 true，无法直接断言该分支）。
```

改为：

```dart
/// 判断应用是否从 Google Play 商店安装。
///
/// 抽成纯函数以便单测覆盖 installer 判定（`_defaultIsSupportedBuild`
/// 仅依赖平台与 installer，不依赖 `kDebugMode`，可在 `flutter test` 下断言）。
```

- [ ] **Step 3: 确认 `kDebugMode` 仍被其它代码使用，保留 import**

`lib/features/update/data/play_store_update_service.dart` 第 1 行 `import 'package:flutter/foundation.dart';` 仍被 `defaultTargetPlatform` / `TargetPlatform` 使用，**不要删除该 import**。

- [ ] **Step 4: 运行新测试确认 green**

Run: `flutter test test/unit/features/update/play_store_update_service_test.dart`
Expected: **PASS**。`'debug build installed from Play proceeds to update flow'` 现在通过——gate 不再含 `!kDebugMode`，在 android 平台覆盖下 gate 通过，调用注入快照返回 `available`。全文件 5 个测试全部 PASS。

- [ ] **Step 5: 提交 green 实现**

```bash
git add lib/features/update/data/play_store_update_service.dart
git commit -m "feat: allow debug builds from play to check for updates"
```

---

### Task 3: 全量回归

**Files:** 无改动，验证性质。

- [ ] **Step 1: 跑全量测试套件确认无回归**

Run: `flutter test`
Expected: **全部 PASS**。重点关注 update 子系统的 6 个测试文件：
- `test/unit/features/update/update_prompt_policy_test.dart`
- `test/unit/features/update/update_controller_test.dart`
- `test/unit/features/update/play_store_update_service_test.dart`（含新测试）
- `test/widget/about_page_update_test.dart`
- `test/widget/home_update_prompt_test.dart`
- `test/widget/profile_tab_update_badge_test.dart`

- [ ] **Step 2: （可选）真机验证**

若手头有从 Play 内部测试轨道安装的 debug 包，可在真机上验证：
- 启动 debug 包 → 观察启动时 silent check 是否触发（日志 / 网络行为）。
- 打开 About 页 → 点 "检查更新" → 确认状态走 `available` / `upToDate` 而非 `unsupported`。

无真机环境可跳过此步，单测已覆盖门禁逻辑。

---

## Self-Review 记录

**Spec 覆盖：**
- spec「移除 `!kDebugMode` 门禁」→ Task 2 Step 1 ✓
- spec「更新/删除过时注释」→ Task 2 Step 2 ✓
- spec「新增红绿回归测试」→ Task 1（red）+ Task 2（green）✓
- spec「现有测试继续通过」→ Task 3 Step 1 ✓
- spec 非目标（不碰节流/policy/controller/UI）→ 全程未触碰这些文件 ✓

**Placeholder 扫描：** 无 TODO/TBD，所有代码块完整、可执行。

**类型/命名一致性：** `PlayStoreUpdateService`、`PlayUpdateSnapshot`、`UpdateCheckStatus.available`、`_packageInfo`、`isSupportedBuild`、`debugDefaultTargetPlatformOverride`、`TargetPlatform.android` 均与现有代码/Flutter API 一致。`_withAndroidPlatform` 为本 plan 新增 helper，带下划线前缀以匹配同文件 `_packageInfo` 的库私有风格。
