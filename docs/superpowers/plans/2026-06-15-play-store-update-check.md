# Play 商店更新检测 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 WindWalker Android 正式包增加基于 Google Play 官方能力的静默更新检测、轻提示和低打扰弹窗提醒，并在有下载任务时禁止自动弹窗。

**Architecture:** 新增一个小而可测的更新子系统：`PlayStoreUpdateService` 负责官方检查与商店跳转，`UpdatePromptPolicy` 负责“只显示 badge / 允许弹窗 / 不提示”的决策，`UpdateController` 负责状态、节流和本地持久化。UI 只接入 `AboutPage`、`ProfileTab` 和 `HomeTabContainer` 三个点，不直接依赖 Play API。

**Tech Stack:** Flutter、Dart、Provider + ChangeNotifier、GetStorage、`in_app_update`、`in_app_review`、`package_info_plus`、Flutter widget/unit tests、`flutter gen-l10n`。

参考设计：`docs/superpowers/specs/2026-06-15-play-store-update-check-design.md`

---

## File Structure

| 文件 | 职责 | 改动类型 |
|---|---|---|
| `pubspec.yaml` | 添加 Google Play 更新检查依赖 | 修改 |
| `lib/features/update/domain/update_check_result.dart` | 统一表达“有更新 / 已最新 / 不支持 / 未知” | 新增 |
| `lib/features/update/domain/update_prompt_policy.dart` | 低打扰提醒决策：`none / badgeOnly / dialogAllowed` | 新增 |
| `lib/features/update/data/play_store_update_service.dart` | 调用 Google Play 官方检查 + 打开商店页 | 新增 |
| `lib/features/update/presentation/controllers/update_controller.dart` | 检查、持久化、节流、页面可读状态 | 新增 |
| `lib/features/tasks/presentation/controllers/task_controller.dart` | 暴露“是否有活跃下载任务”的只读接口 | 修改 |
| `lib/app.dart` | 注册 `UpdateController` Provider | 修改 |
| `lib/features/home/presentation/pages/home_tab_container.dart` | 首屏稳定后触发静默检查，消费一次弹窗机会 | 修改 |
| `lib/features/home/presentation/pages/profile_tab.dart` | 关于入口显示更新轻提示 | 修改 |
| `lib/features/settings/presentation/pages/about_page.dart` | 新增“检查更新”入口与版本提示文案 | 修改 |
| `lib/l10n/app_en.arb` | 英文文案 | 修改 |
| `lib/l10n/app_zh.arb` | 中文文案 | 修改 |
| `lib/l10n/app_ja.arb` | 日文文案 | 修改 |
| `lib/l10n/app_localizations*.dart` | 由 `flutter gen-l10n` 生成的新字符串 | 生成 |
| `test/unit/features/update/play_store_update_service_test.dart` | 更新服务单测 | 新增 |
| `test/unit/features/update/update_prompt_policy_test.dart` | 提醒策略单测 | 新增 |
| `test/unit/features/update/update_controller_test.dart` | 控制器单测 | 新增 |
| `test/unit/task_controller_shared_state_test.dart` | 活跃下载 getter 单测 | 修改 |
| `test/widget/test_helpers.dart` | 为 widget 测试注入 `UpdateController` 和 `/about` 路由 | 修改 |
| `test/widget/about_page_update_test.dart` | About 页“检查更新”与状态展示测试 | 新增 |
| `test/widget/profile_tab_update_badge_test.dart` | ProfileTab 轻提示标记测试 | 新增 |
| `test/widget/home_update_prompt_test.dart` | 首页自动提醒弹窗测试 | 新增 |

---

## Task 1: 更新结果模型与 Play 更新服务

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/update/domain/update_check_result.dart`
- Create: `lib/features/update/data/play_store_update_service.dart`
- Test: `test/unit/features/update/play_store_update_service_test.dart`

- [ ] **Step 1: 写失败测试**

Create `test/unit/features/update/play_store_update_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:windwalker/features/update/data/play_store_update_service.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

void main() {
  group('PlayStoreUpdateService', () {
    test('unsupported build returns unsupported without calling Play API', () async {
      var called = false;
      final service = PlayStoreUpdateService(
        packageInfoLoader: () async => PackageInfo(
          appName: 'WindWalker',
          packageName: 'com.windwalker.app',
          version: '0.0.7',
          buildNumber: '2026060702',
          buildSignature: '',
          installerStore: 'com.android.vending',
        ),
        checkForUpdate: () async {
          called = true;
          return const PlayUpdateSnapshot(
            isUpdateAvailable: true,
            availableVersionCode: 2026061501,
          );
        },
        isSupportedBuild: () => false,
      );

      final result = await service.checkForUpdate();
      expect(result.status, UpdateCheckStatus.unsupported);
      expect(called, isFalse);
    });

    test('available update returns available with version code', () async {
      final service = PlayStoreUpdateService(
        packageInfoLoader: () async => PackageInfo(
          appName: 'WindWalker',
          packageName: 'com.windwalker.app',
          version: '0.0.7',
          buildNumber: '2026060702',
          buildSignature: '',
          installerStore: 'com.android.vending',
        ),
        checkForUpdate: () async => const PlayUpdateSnapshot(
          isUpdateAvailable: true,
          availableVersionCode: 2026061501,
        ),
        isSupportedBuild: () => true,
      );

      final result = await service.checkForUpdate();
      expect(result.status, UpdateCheckStatus.available);
      expect(result.availableVersionCode, 2026061501);
      expect(result.hasUpdate, isTrue);
    });

    test('service returns unknown when Play check throws', () async {
      final service = PlayStoreUpdateService(
        packageInfoLoader: () async => PackageInfo(
          appName: 'WindWalker',
          packageName: 'com.windwalker.app',
          version: '0.0.7',
          buildNumber: '2026060702',
          buildSignature: '',
          installerStore: 'com.android.vending',
        ),
        checkForUpdate: () async => throw Exception('play unavailable'),
        isSupportedBuild: () => true,
      );

      final result = await service.checkForUpdate();
      expect(result.status, UpdateCheckStatus.unknown);
      expect(result.hasUpdate, isFalse);
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/features/update/play_store_update_service_test.dart`

Expected: FAIL，提示 `play_store_update_service.dart` / `update_check_result.dart` 不存在。

- [ ] **Step 3: 添加依赖与实现最小服务**

Modify `pubspec.yaml` under `dependencies:`:

```yaml
  in_app_update: ^4.2.3
```

Create `lib/features/update/domain/update_check_result.dart`:

```dart
enum UpdateCheckStatus {
  unsupported,
  unknown,
  upToDate,
  available,
}

class UpdateCheckResult {
  const UpdateCheckResult._({
    required this.status,
    this.availableVersionCode,
  });

  const UpdateCheckResult.unsupported()
      : this._(status: UpdateCheckStatus.unsupported);

  const UpdateCheckResult.unknown()
      : this._(status: UpdateCheckStatus.unknown);

  const UpdateCheckResult.upToDate()
      : this._(status: UpdateCheckStatus.upToDate);

  const UpdateCheckResult.available(int versionCode)
      : this._(
          status: UpdateCheckStatus.available,
          availableVersionCode: versionCode,
        );

  final UpdateCheckStatus status;
  final int? availableVersionCode;

  bool get hasUpdate => status == UpdateCheckStatus.available;
}
```

Create `lib/features/update/data/play_store_update_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

class PlayUpdateSnapshot {
  const PlayUpdateSnapshot({
    required this.isUpdateAvailable,
    required this.availableVersionCode,
  });

  final bool isUpdateAvailable;
  final int? availableVersionCode;
}

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef PlayUpdateCheck = Future<PlayUpdateSnapshot> Function();
typedef SupportedBuildCheck = bool Function();
typedef OpenStoreListing = Future<void> Function();

class PlayStoreUpdateService {
  PlayStoreUpdateService({
    PackageInfoLoader? packageInfoLoader,
    PlayUpdateCheck? checkForUpdate,
    SupportedBuildCheck? isSupportedBuild,
    OpenStoreListing? openStoreListing,
  }) : _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _checkForUpdate = checkForUpdate ?? _defaultCheckForUpdate,
       _isSupportedBuild = isSupportedBuild ?? _defaultIsSupportedBuild,
       _openStoreListing =
           openStoreListing ?? InAppReview.instance.openStoreListing;

  final PackageInfoLoader _packageInfoLoader;
  final PlayUpdateCheck _checkForUpdate;
  final SupportedBuildCheck _isSupportedBuild;
  final OpenStoreListing _openStoreListing;

  Future<UpdateCheckResult> checkForUpdate() async {
    await _packageInfoLoader();

    if (!_isSupportedBuild()) {
      return const UpdateCheckResult.unsupported();
    }

    try {
      final snapshot = await _checkForUpdate();
      if (!snapshot.isUpdateAvailable || snapshot.availableVersionCode == null) {
        return const UpdateCheckResult.upToDate();
      }
      return UpdateCheckResult.available(snapshot.availableVersionCode!);
    } catch (e, st) {
      Log.w('Play update check failed');
      Log.e('Play update check failed', error: e, stackTrace: st);
      return const UpdateCheckResult.unknown();
    }
  }

  Future<void> openStorePage() {
    return _openStoreListing();
  }

  static bool _defaultIsSupportedBuild() {
    return !kDebugMode && defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<PlayUpdateSnapshot> _defaultCheckForUpdate() async {
    final info = await InAppUpdate.checkForUpdate();
    return PlayUpdateSnapshot(
      isUpdateAvailable:
          info.updateAvailability == UpdateAvailability.updateAvailable,
      availableVersionCode: info.availableVersionCode,
    );
  }
}
```

- [ ] **Step 4: 安装依赖**

Run: `flutter pub get`

Expected: PASS，输出包含 `Resolving dependencies...` 和 `in_app_update` 已拉取。

- [ ] **Step 5: 跑测试验证通过**

Run: `flutter test test/unit/features/update/play_store_update_service_test.dart`

Expected: PASS，3 个测试全部通过。

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/update/domain/update_check_result.dart lib/features/update/data/play_store_update_service.dart test/unit/features/update/play_store_update_service_test.dart
git commit -m "feat: add play store update service"
```

---

## Task 2: 提醒策略、活跃下载判断与 UpdateController

**Files:**
- Create: `lib/features/update/domain/update_prompt_policy.dart`
- Create: `lib/features/update/presentation/controllers/update_controller.dart`
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`
- Modify: `lib/app.dart`
- Test: `test/unit/features/update/update_prompt_policy_test.dart`
- Test: `test/unit/features/update/update_controller_test.dart`
- Test: `test/unit/task_controller_shared_state_test.dart`

- [ ] **Step 1: 写策略与活跃下载失败测试**

Create `test/unit/features/update/update_prompt_policy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/domain/update_prompt_policy.dart';

void main() {
  group('UpdatePromptPolicy', () {
    final now = DateTime(2026, 6, 15, 10);

    test('returns dialogAllowed when update exists and all limits pass', () {
      final decision = const UpdatePromptPolicy().evaluate(
        result: const UpdateCheckResult.available(2026061501),
        now: now,
        hasActiveDownloads: false,
        dialogConsumedInSession: false,
        lastPromptAt: now.subtract(const Duration(days: 8)),
        lastPromptDayKey: '2026-06-07',
        dismissedVersionCode: null,
      );

      expect(decision, UpdatePromptDecision.dialogAllowed);
    });

    test('returns badgeOnly when active downloads exist', () {
      final decision = const UpdatePromptPolicy().evaluate(
        result: const UpdateCheckResult.available(2026061501),
        now: now,
        hasActiveDownloads: true,
        dialogConsumedInSession: false,
        lastPromptAt: null,
        lastPromptDayKey: null,
        dismissedVersionCode: null,
      );

      expect(decision, UpdatePromptDecision.badgeOnly);
    });

    test('returns none when result is unsupported', () {
      final decision = const UpdatePromptPolicy().evaluate(
        result: const UpdateCheckResult.unsupported(),
        now: now,
        hasActiveDownloads: false,
        dialogConsumedInSession: false,
        lastPromptAt: null,
        lastPromptDayKey: null,
        dismissedVersionCode: null,
      );

      expect(decision, UpdatePromptDecision.none);
    });
  });
}
```

Append to `test/unit/task_controller_shared_state_test.dart`:

```dart
    test('hasActiveTransfers 为 true when downloading or waiting task exists', () {
      controller.debugSetTasksForTest('d1', [
        createTestTask(id: 't1', status: TaskStatus.downloading),
        createTestTask(id: 't2', status: TaskStatus.paused),
      ]);

      expect(controller.hasActiveTransfers, isTrue);
    });
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/features/update/update_prompt_policy_test.dart test/unit/task_controller_shared_state_test.dart`

Expected: FAIL，提示 `update_prompt_policy.dart` 不存在，`hasActiveTransfers` getter 不存在。

- [ ] **Step 3: 实现策略与任务 getter**

Create `lib/features/update/domain/update_prompt_policy.dart`:

```dart
import 'package:windwalker/features/update/domain/update_check_result.dart';

enum UpdatePromptDecision {
  none,
  badgeOnly,
  dialogAllowed,
}

class UpdatePromptPolicy {
  const UpdatePromptPolicy({
    this.cooldown = const Duration(days: 7),
  });

  final Duration cooldown;

  UpdatePromptDecision evaluate({
    required UpdateCheckResult result,
    required DateTime now,
    required bool hasActiveDownloads,
    required bool dialogConsumedInSession,
    required DateTime? lastPromptAt,
    required String? lastPromptDayKey,
    required int? dismissedVersionCode,
  }) {
    if (!result.hasUpdate) {
      return UpdatePromptDecision.none;
    }

    if (hasActiveDownloads) return UpdatePromptDecision.badgeOnly;
    if (dialogConsumedInSession) return UpdatePromptDecision.badgeOnly;
    if (dismissedVersionCode == result.availableVersionCode) {
      return UpdatePromptDecision.badgeOnly;
    }

    final dayKey = _dayKey(now);
    if (lastPromptDayKey == dayKey) return UpdatePromptDecision.badgeOnly;
    if (lastPromptAt != null && now.difference(lastPromptAt) < cooldown) {
      return UpdatePromptDecision.badgeOnly;
    }

    return UpdatePromptDecision.dialogAllowed;
  }

  String dayKey(DateTime value) => _dayKey(value);

  String _dayKey(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
  }
}
```

Add to `lib/features/tasks/presentation/controllers/task_controller.dart` near other getters:

```dart
  bool get hasActiveTransfers => allTasks.any(
    (task) =>
        task.status == TaskStatus.downloading ||
        task.status == TaskStatus.waiting,
  );
```

- [ ] **Step 4: 写控制器失败测试**

Create `test/unit/features/update/update_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/update/data/play_store_update_service.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';

class FakeUpdateService extends PlayStoreUpdateService {
  FakeUpdateService({
    required this.result,
  }) : super(
          isSupportedBuild: () => true,
          packageInfoLoader: () async => throw UnimplementedError(),
          checkForUpdate: () async => throw UnimplementedError(),
        );

  UpdateCheckResult result;
  int openStoreCalls = 0;

  @override
  Future<UpdateCheckResult> checkForUpdate() async => result;

  @override
  Future<void> openStorePage() async {
    openStoreCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GetStorage.init();
  });

  test('silent check exposes badge and dialog when no active downloads', () async {
    final service = FakeUpdateService(
      result: const UpdateCheckResult.available(2026061501),
    );
    final tasks = TaskController();
    final controller = UpdateController(
      service: service,
      storage: GetStorage(),
      taskController: tasks,
    );

    await controller.runSilentCheck(now: DateTime(2026, 6, 15, 10));

    expect(controller.hasUpdate, isTrue);
    expect(controller.shouldShowUpdateBadge, isTrue);
    expect(controller.shouldOfferUpdateDialog, isTrue);
  });

  test('silent check downgrades to badge when active downloads exist', () async {
    final service = FakeUpdateService(
      result: const UpdateCheckResult.available(2026061501),
    );
    final tasks = TaskController();
    tasks.debugSetTasksForTest('d1', []);
    tasks.debugSetTasksForTest('d2', []);
    tasks.debugSetTasksForTest('downloading', [
      createTask('t1'),
    ]);

    final controller = UpdateController(
      service: service,
      storage: GetStorage(),
      taskController: tasks,
    );

    await controller.runSilentCheck(now: DateTime(2026, 6, 15, 10));

    expect(controller.shouldShowUpdateBadge, isTrue);
    expect(controller.shouldOfferUpdateDialog, isFalse);
  });
}

DownloadTask createTask(String id) => DownloadTask(
  id: id,
  gid: id,
  name: id,
  downloaderId: 'd1',
  status: TaskStatus.downloading,
);
```

- [ ] **Step 5: 跑控制器测试验证失败**

Run: `flutter test test/unit/features/update/update_controller_test.dart`

Expected: FAIL，提示 `UpdateController` 不存在。

- [ ] **Step 6: 实现 UpdateController 与 Provider 注册**

Create `lib/features/update/presentation/controllers/update_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/update/data/play_store_update_service.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/domain/update_prompt_policy.dart';

class UpdateController extends ChangeNotifier {
  UpdateController({
    PlayStoreUpdateService? service,
    GetStorage? storage,
    TaskController? taskController,
    UpdatePromptPolicy? policy,
  }) : _service = service ?? PlayStoreUpdateService(),
       _storage = storage ?? GetStorage(),
       _taskController = taskController,
       _policy = policy ?? const UpdatePromptPolicy();

  static const _lastPromptAtKey = 'last_update_prompt_at';
  static const _lastPromptDayKey = 'last_update_prompt_day';
  static const _dismissedVersionCodeKey = 'dismissed_update_version_code';

  final PlayStoreUpdateService _service;
  final GetStorage _storage;
  final UpdatePromptPolicy _policy;
  TaskController? _taskController;

  UpdateCheckResult _lastResult = const UpdateCheckResult.unknown();
  bool _isChecking = false;
  bool _dialogConsumedInSession = false;
  bool _shouldOfferUpdateDialog = false;

  bool get isChecking => _isChecking;
  bool get hasUpdate => _lastResult.hasUpdate;
  int? get availableVersionCode => _lastResult.availableVersionCode;
  bool get shouldShowUpdateBadge => _lastResult.hasUpdate;
  bool get shouldOfferUpdateDialog => _shouldOfferUpdateDialog;

  void attachTaskController(TaskController taskController) {
    _taskController = taskController;
    _recomputeDecision();
  }

  Future<void> runSilentCheck({DateTime? now}) async {
    _isChecking = true;
    notifyListeners();
    _lastResult = await _service.checkForUpdate();
    _isChecking = false;
    _recomputeDecision(now: now);
  }

  Future<void> checkForUpdatesManually() async {
    _lastResult = await _service.checkForUpdate();
    _recomputeDecision();
  }

  Future<void> openStorePage() async {
    await _service.openStorePage();
    _recordPromptAccepted(DateTime.now());
  }

  void dismissCurrentVersion({DateTime? now}) {
    final versionCode = _lastResult.availableVersionCode;
    if (versionCode != null) {
      _storage.write(_dismissedVersionCodeKey, versionCode);
    }
    _recordPromptShown(now ?? DateTime.now());
    _dialogConsumedInSession = true;
    _recomputeDecision(now: now);
  }

  void markDialogConsumed({DateTime? now}) {
    _recordPromptShown(now ?? DateTime.now());
    _dialogConsumedInSession = true;
    _recomputeDecision(now: now);
  }

  void _recordPromptAccepted(DateTime now) {
    _recordPromptShown(now);
    _dialogConsumedInSession = true;
    _recomputeDecision(now: now);
  }

  void _recordPromptShown(DateTime now) {
    _storage.write(_lastPromptAtKey, now.millisecondsSinceEpoch);
    _storage.write(_lastPromptDayKey, _policy.dayKey(now));
  }

  void _recomputeDecision({DateTime? now}) {
    final current = now ?? DateTime.now();
    final lastPromptAtMillis = _storage.read<int>(_lastPromptAtKey);
    final lastPromptAt = lastPromptAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastPromptAtMillis);

    final decision = _policy.evaluate(
      result: _lastResult,
      now: current,
      hasActiveDownloads: _taskController?.hasActiveTransfers ?? false,
      dialogConsumedInSession: _dialogConsumedInSession,
      lastPromptAt: lastPromptAt,
      lastPromptDayKey: _storage.read<String>(_lastPromptDayKey),
      dismissedVersionCode: _storage.read<int>(_dismissedVersionCodeKey),
    );

    _shouldOfferUpdateDialog = decision == UpdatePromptDecision.dialogAllowed;
    notifyListeners();
  }
}
```

Modify `lib/app.dart` provider list:

```dart
        ChangeNotifierProvider(create: (_) => TaskController()),
        ChangeNotifierProxyProvider<TaskController, UpdateController>(
          create: (_) => UpdateController(),
          update: (_, taskController, updateController) {
            updateController ??= UpdateController(taskController: taskController);
            updateController.attachTaskController(taskController);
            return updateController;
          },
        ),
        ChangeNotifierProvider(create: (_) => SettingsController()),
```

- [ ] **Step 7: 跑单测验证通过**

Run:

```bash
flutter test test/unit/features/update/update_prompt_policy_test.dart
flutter test test/unit/features/update/update_controller_test.dart
flutter test test/unit/task_controller_shared_state_test.dart
```

Expected: PASS，策略、控制器和任务 getter 测试全部通过。

- [ ] **Step 8: Commit**

```bash
git add lib/features/update/domain/update_prompt_policy.dart lib/features/update/presentation/controllers/update_controller.dart lib/features/tasks/presentation/controllers/task_controller.dart lib/app.dart test/unit/features/update/update_prompt_policy_test.dart test/unit/features/update/update_controller_test.dart test/unit/task_controller_shared_state_test.dart
git commit -m "feat: add update prompt policy and controller"
```

---

## Task 3: About 页、ProfileTab 与首页弹窗宿主

**Files:**
- Modify: `lib/features/settings/presentation/pages/about_page.dart`
- Modify: `lib/features/home/presentation/pages/profile_tab.dart`
- Modify: `lib/features/home/presentation/pages/home_tab_container.dart`
- Modify: `test/widget/test_helpers.dart`
- Test: `test/widget/about_page_update_test.dart`
- Test: `test/widget/profile_tab_update_badge_test.dart`
- Test: `test/widget/home_update_prompt_test.dart`

- [ ] **Step 1: 写 About/Profile/Home 的失败测试**

Create `test/widget/about_page_update_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('About page shows check update tile and update status', (tester) async {
    final updateController = buildUpdateControllerForTest(
      result: const UpdateCheckResult.available(2026061501),
      shouldOfferDialog: false,
    );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        updateController: updateController,
        initialLocation: '/about',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check for Updates'), findsOneWidget);
    expect(find.text('New version available'), findsOneWidget);
  });
}
```

Create `test/widget/profile_tab_update_badge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('Profile tab shows update badge near about entry', (tester) async {
    final updateController = buildUpdateControllerForTest(
      result: const UpdateCheckResult.available(2026061501),
      shouldOfferDialog: false,
    );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        updateController: updateController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mine'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
  });
}
```

Create `test/widget/home_update_prompt_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('Home shows gentle update dialog when controller allows it', (tester) async {
    final updateController = buildUpdateControllerForTest(
      result: const UpdateCheckResult.available(2026061501),
      shouldOfferDialog: true,
    );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        updateController: updateController,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 跑 widget 测试验证失败**

Run:

```bash
flutter test test/widget/about_page_update_test.dart
flutter test test/widget/profile_tab_update_badge_test.dart
flutter test test/widget/home_update_prompt_test.dart
```

Expected: FAIL，因为 `/about` 路由、`UpdateController` 注入、相关文案和弹窗都还不存在。

- [ ] **Step 3: 先扩展 test helpers 让 widget 测试可注入 UpdateController**

Modify `test/widget/test_helpers.dart`:

```dart
import 'package:windwalker/features/settings/presentation/pages/about_page.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';

class FakeUpdateController extends UpdateController {
  FakeUpdateController({
    required UpdateCheckResult result,
    required bool shouldOfferDialog,
  }) : _result = result,
       _shouldOfferDialog = shouldOfferDialog,
       super();

  final UpdateCheckResult _result;
  final bool _shouldOfferDialog;

  @override
  bool get hasUpdate => _result.hasUpdate;

  @override
  int? get availableVersionCode => _result.availableVersionCode;

  @override
  bool get shouldShowUpdateBadge => _result.hasUpdate;

  @override
  bool get shouldOfferUpdateDialog => _shouldOfferDialog;

  @override
  Future<void> runSilentCheck({DateTime? now}) async {}

  @override
  Future<void> checkForUpdatesManually() async {}
}

UpdateController buildUpdateControllerForTest({
  required UpdateCheckResult result,
  required bool shouldOfferDialog,
}) {
  return FakeUpdateController(
    result: result,
    shouldOfferDialog: shouldOfferDialog,
  );
}
```

Also update `createTestApp(...)` signature and providers:

```dart
Widget createTestApp({
  required DownloaderController downloaderController,
  TaskController? taskController,
  SettingsController? settingsController,
  UpdateController? updateController,
  String initialLocation = '/',
}) {
```

Add the `/about` route:

```dart
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
```

Add provider:

```dart
      ChangeNotifierProvider<UpdateController>.value(
        value: updateController ?? buildUpdateControllerForTest(
          result: const UpdateCheckResult.unknown(),
          shouldOfferDialog: false,
        ),
      ),
```

- [ ] **Step 4: 实现页面接入**

Modify `lib/features/settings/presentation/pages/about_page.dart`:

```dart
import 'package:provider/provider.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';
```

Inside `build`:

```dart
    final update = context.watch<UpdateController>();
```

Insert a new `ListTile` between version和评分：

```dart
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_alt_rounded),
                  title: Text(l10n.checkForUpdates),
                  subtitle: Text(
                    update.hasUpdate
                        ? l10n.newVersionAvailable
                        : l10n.upToDate,
                  ),
                  trailing: update.isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.read<UpdateController>().checkForUpdatesManually();
                    if (!context.mounted) return;
                    if (context.read<UpdateController>().hasUpdate) {
                      final go = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.updateAvailableTitle),
                          content: Text(l10n.updateAvailableMessage),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.later),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l10n.updateNow),
                            ),
                          ],
                        ),
                      );
                      if (go == true) {
                        await context.read<UpdateController>().openStorePage();
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.upToDate)),
                      );
                    }
                  },
                ),
```

Modify `lib/features/home/presentation/pages/profile_tab.dart`:

```dart
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';
```

Wrap existing body consumer with `Consumer2<AuthController, UpdateController>` and, in the About tile subtitle/trailing, add:

```dart
          final update = context.watch<UpdateController>();
```

```dart
                      subtitle: Text(
                        update.hasUpdate
                            ? l10n.updateAvailableBadge
                            : l10n.aboutSubtitle,
                      ),
```

Modify `lib/features/home/presentation/pages/home_tab_container.dart`:

```dart
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';
```

In `initState()` post-frame callback after `DownloaderController.init()`:

```dart
      await context.read<UpdateController>().runSilentCheck();
      await _maybeShowUpdatePrompt();
```

Add helper method to `_HomeTabContainerState`:

```dart
  Future<void> _maybeShowUpdatePrompt() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final update = context.read<UpdateController>();
    if (!update.shouldOfferUpdateDialog) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.updateAvailableTitle),
        content: Text(AppLocalizations.of(ctx)!.updateAvailableMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.later),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.updateNow),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (go == true) {
      await update.openStorePage();
      return;
    }

    update.dismissCurrentVersion();
  }
```

- [ ] **Step 5: 跑 widget 测试验证通过**

Run:

```bash
flutter test test/widget/about_page_update_test.dart
flutter test test/widget/profile_tab_update_badge_test.dart
flutter test test/widget/home_update_prompt_test.dart
```

Expected: PASS，About 页入口、Profile 轻提示、Home 温和弹窗三条路径全部通过。

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/pages/about_page.dart lib/features/home/presentation/pages/profile_tab.dart lib/features/home/presentation/pages/home_tab_container.dart test/widget/test_helpers.dart test/widget/about_page_update_test.dart test/widget/profile_tab_update_badge_test.dart test/widget/home_update_prompt_test.dart
git commit -m "feat: surface play update prompts in ui"
```

---

## Task 4: 本地化、生成代码与整体验证

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_ja.arb`
- Generate: `lib/l10n/app_localizations.dart`
- Generate: `lib/l10n/app_localizations_en.dart`
- Generate: `lib/l10n/app_localizations_zh.dart`
- Generate: `lib/l10n/app_localizations_ja.dart`

- [ ] **Step 1: 写入新文案**

Append to `lib/l10n/app_en.arb`:

```json
  "checkForUpdates": "Check for Updates",
  "newVersionAvailable": "New version available",
  "updateAvailableBadge": "Update available",
  "upToDate": "You're up to date",
  "updateAvailableTitle": "Update available",
  "updateAvailableMessage": "A newer WindWalker version is available on Google Play.",
  "updateNow": "Update now",
  "later": "Later"
```

Append to `lib/l10n/app_zh.arb`:

```json
  "checkForUpdates": "检查更新",
  "newVersionAvailable": "发现新版本",
  "updateAvailableBadge": "可更新",
  "upToDate": "当前已是最新版本",
  "updateAvailableTitle": "发现新版本",
  "updateAvailableMessage": "Google Play 上已有更新版本可用。",
  "updateNow": "去更新",
  "later": "稍后"
```

Append to `lib/l10n/app_ja.arb`:

```json
  "checkForUpdates": "更新を確認",
  "newVersionAvailable": "新しいバージョンがあります",
  "updateAvailableBadge": "更新あり",
  "upToDate": "最新バージョンです",
  "updateAvailableTitle": "更新があります",
  "updateAvailableMessage": "Google Play に新しい WindWalker バージョンがあります。",
  "updateNow": "更新する",
  "later": "あとで"
```

- [ ] **Step 2: 生成 l10n 代码**

Run: `flutter gen-l10n`

Expected: PASS，`lib/l10n/app_localizations*.dart` 被更新，新 getter 可用。

- [ ] **Step 3: 跑针对性回归**

Run:

```bash
flutter test test/unit/features/update/play_store_update_service_test.dart
flutter test test/unit/features/update/update_prompt_policy_test.dart
flutter test test/unit/features/update/update_controller_test.dart
flutter test test/unit/task_controller_shared_state_test.dart
flutter test test/widget/about_page_update_test.dart
flutter test test/widget/profile_tab_update_badge_test.dart
flutter test test/widget/home_update_prompt_test.dart
flutter test test/widget/settings_page_test.dart
```

Expected: PASS，更新功能新增测试通过，同时现有设置页测试不回归。

- [ ] **Step 4: 跑静态检查**

Run: `flutter analyze`

Expected: PASS，无新的 analyzer 报错。

- [ ] **Step 5: 手动验证正式 Android 包路径**

Run:

```bash
flutter run
```

手动验证清单：

- 正常启动后不立即打断用户
- About 页能看到“检查更新”入口
- 无更新时显示“当前已是最新版本”
- 有更新且无下载时，首页只弹一次温和弹窗
- 有更新且存在下载中/等待中任务时，不弹窗，只保留轻提示
- 点击“去更新”会跳转 Google Play 商店
- 点击“稍后”后，同版本当天不再重复弹窗

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart
git commit -m "feat: add localized play update prompts"
```

---

## Self-Review Checklist

- Spec coverage:
  - Play 官方检查：Task 1
  - 低打扰策略：Task 2
  - 活跃下载压制弹窗：Task 2 + Task 3
  - About/Profile/Home 三处接入：Task 3
  - 本地化与回归验证：Task 4
- Placeholder scan:
  - 计划中没有 `TODO` / `TBD` / “稍后实现”
  - 每个代码步骤都给了明确代码块
  - 每个测试步骤都有明确命令
- Type consistency:
  - `UpdateCheckResult` / `UpdatePromptPolicy` / `UpdateController` 三者命名统一
  - `shouldShowUpdateBadge` / `shouldOfferUpdateDialog` 在后续 UI 任务中保持一致
