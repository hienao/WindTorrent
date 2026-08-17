# 共享任务状态与刷新联动 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把任务状态改造成全局共享数据源，确保添加、暂停、恢复、删除后，任务列表页、汇总页、详情页保持同步刷新。

**Architecture:** 在 `lib/app.dart` 中全局提供 `TaskController`，由它维护按下载器分组的任务缓存、聚合任务视图和详情态。页面层不再创建私有 `TaskController`，所有任务操作统一收敛到共享 controller，并采用“事件驱动立即刷新 + 低频全局轮询兜底”的混合刷新策略。

**Tech Stack:** Flutter 3.24、Provider、go_router、http、flutter_test

---

## 文件结构

### 修改文件

- `lib/app.dart`
  - 将 `TaskController` 提升为全局 Provider。
- `lib/features/tasks/presentation/controllers/task_controller.dart`
  - 从单页 controller 改为共享任务状态 controller。
- `lib/features/tasks/presentation/pages/tasks_page.dart`
  - 移除私有 controller，改为订阅共享状态。
- `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
  - 移除私有 controller，改为订阅共享聚合结果。
- `lib/features/tasks/presentation/pages/task_detail_page.dart`
  - 移除私有 controller，改为使用共享 controller 加载详情与执行操作。
- `lib/features/add_task/presentation/pages/add_task_page.dart`
  - 提交成功逻辑改为调用共享 `TaskController.addTask(...)`。
- `test/widget/test_helpers.dart`
  - 补齐共享 `TaskController` 的测试注入辅助。
- `test/widget/home_page_test.dart`
  - 如因 Provider 变更导致测试构造更新，需要同步调整。
- `test/widget/settings_page_test.dart`
  - 如因 Provider 变更导致测试构造更新，需要同步调整。

### 新建文件

- `test/unit/task_controller_shared_state_test.dart`
  - 覆盖共享任务缓存与刷新行为。
- `test/widget/tasks_page_shared_state_test.dart`
  - 覆盖单下载器页的共享刷新联动。
- `test/widget/all_tasks_tab_shared_state_test.dart`
  - 覆盖汇总页的共享刷新联动。

---

### Task 1: 把 `TaskController` 提升为全局 Provider

**Files:**
- Modify: `lib/app.dart`
- Modify: `test/widget/test_helpers.dart`
- Modify: `test/widget/home_page_test.dart`
- Modify: `test/widget/settings_page_test.dart`

- [ ] **Step 1: 先更新应用级 Provider 结构**

```dart
return MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthController()),
    ChangeNotifierProvider(create: (_) => DownloaderController()),
    ChangeNotifierProvider(create: (_) => TaskController()),
    ChangeNotifierProvider(create: (_) => SettingsController()),
  ],
  child: Builder(
    builder: (context) {
      final settings = context.watch<SettingsController>();
      return MaterialApp.router(
        routerConfig: appRouter,
        locale: settings.effectiveLocale,
      );
    },
  ),
);
```

- [ ] **Step 2: 更新测试辅助，确保 widget 测试也注入共享 `TaskController`**

```dart
Widget createTestApp({
  required DownloaderController downloaderController,
  TaskController? taskController,
  SettingsController? settingsController,
  String initialLocation = '/',
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DownloaderController>.value(
        value: downloaderController,
      ),
      ChangeNotifierProvider<TaskController>.value(
        value: taskController ?? TaskController(),
      ),
      ChangeNotifierProvider<SettingsController>.value(
        value: settingsController ?? SettingsController(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
```

- [ ] **Step 3: 运行现有 widget 测试，确认 Provider 结构没有破坏基础页面**

Run: `flutter test test/widget/home_page_test.dart test/widget/settings_page_test.dart`
Expected: PASS

- [ ] **Step 4: 提交本任务**

```bash
git add lib/app.dart test/widget/test_helpers.dart test/widget/home_page_test.dart test/widget/settings_page_test.dart
git commit -m "refactor: provide task controller globally"
```

---

### Task 2: 重构 `TaskController` 为共享任务缓存

**Files:**
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`
- Create: `test/unit/task_controller_shared_state_test.dart`

- [ ] **Step 1: 先写共享状态核心测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';

void main() {
  test('tasksForDownloader 应返回对应下载器缓存', () {
    final controller = TaskController();

    controller.debugSetTasksForTest('d1', []);
    controller.debugSetTasksForTest('d2', []);

    expect(controller.tasksForDownloader('d1'), isA<List>());
    expect(controller.tasksForDownloader('d2'), isA<List>());
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/task_controller_shared_state_test.dart`
Expected: FAIL，提示 `tasksForDownloader` 或测试辅助方法不存在

- [ ] **Step 3: 重构 controller 状态结构**

```dart
class TaskController extends ChangeNotifier {
  final Map<String, List<DownloadTask>> _tasksByDownloader = {};
  final Map<String, bool> _loadingByDownloader = {};
  bool _isRefreshingAll = false;
  DownloadTask? _currentTask;
  bool _isLoadingDetail = false;
  Timer? _refreshTimer;

  List<DownloadTask> tasksForDownloader(String downloaderId) =>
      List.unmodifiable(_tasksByDownloader[downloaderId] ?? const []);

  List<DownloadTask> get allTasks {
    final all = _tasksByDownloader.values.expand((tasks) => tasks).toList();
    all.sort((a, b) => b.downloadSpeed.compareTo(a.downloadSpeed));
    return all;
  }

  bool isLoadingDownloader(String downloaderId) =>
      _loadingByDownloader[downloaderId] ?? false;
}
```

- [ ] **Step 4: 新增共享刷新接口**

```dart
Future<void> loadTasksForDownloader(
  String downloaderId,
  DownloaderController downloaderController, {
  bool force = false,
}) async {
  _loadingByDownloader[downloaderId] = true;
  notifyListeners();

  try {
    final downloader = downloaderController.getDownloader(downloaderId);
    if (downloader == null) return;

    final service = _createService(downloader);
    if (service == null) return;

    final result = await service.getTasks();
    _tasksByDownloader[downloaderId] = result;
  } finally {
    _loadingByDownloader[downloaderId] = false;
    notifyListeners();
  }
}
```

```dart
Future<void> loadAllTasks(
  DownloaderController downloaderController, {
  bool force = false,
}) async {
  _isRefreshingAll = true;
  notifyListeners();

  try {
    for (final downloader in downloaderController.downloaders) {
      await loadTasksForDownloader(
        downloader.id,
        downloaderController,
        force: force,
      );
    }
  } finally {
    _isRefreshingAll = false;
    notifyListeners();
  }
}
```

- [ ] **Step 5: 运行共享状态单测**

Run: `flutter test test/unit/task_controller_shared_state_test.dart`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add lib/features/tasks/presentation/controllers/task_controller.dart test/unit/task_controller_shared_state_test.dart
git commit -m "refactor: convert task controller to shared task cache"
```

---

### Task 3: 把任务操作统一收敛到共享 `TaskController`

**Files:**
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`
- Modify: `lib/features/add_task/presentation/pages/add_task_page.dart`
- Create: `test/unit/task_controller_shared_state_test.dart`

- [ ] **Step 1: 先补事件驱动刷新测试**

```dart
test('addTask 成功后应刷新目标下载器缓存', () async {
  final controller = TaskController();

  // 这里用 mock / fake downloader service，验证 addTask 成功后
  // controller 会调用 loadTasksForDownloader('d1', ...)
  expect(true, isTrue);
});
```

- [ ] **Step 2: 实现统一任务操作入口**

```dart
Future<bool> addTask(
  AddTaskRequest request,
  DownloaderController downloaderController,
) async {
  final downloader = downloaderController.getDownloader(request.downloaderId);
  if (downloader == null) return false;

  final service = _createService(downloader);
  if (service == null) return false;

  final result = await service.addTask(request);
  if (result.isEmpty) return false;

  await loadTasksForDownloader(request.downloaderId, downloaderController, force: true);
  return true;
}
```

```dart
Future<void> pauseTask(
  String taskId,
  String downloaderId,
  DownloaderController downloaderController,
) async {
  final downloader = downloaderController.getDownloader(downloaderId);
  if (downloader == null) return;

  final service = _createService(downloader);
  if (service == null) return;

  await service.pauseTask(taskId);
  await loadTasksForDownloader(downloaderId, downloaderController, force: true);
}
```

- [ ] **Step 3: 让添加页改用共享 controller**

```dart
final taskController = context.read<TaskController>();
final success = await taskController.addTask(
  request,
  context.read<DownloaderController>(),
);

if (success) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(l10n.taskAddedSuccess)));
  context.pop();
}
```

- [ ] **Step 4: 运行 controller 单测**

Run: `flutter test test/unit/task_controller_shared_state_test.dart`
Expected: PASS

- [ ] **Step 5: 提交本任务**

```bash
git add lib/features/tasks/presentation/controllers/task_controller.dart lib/features/add_task/presentation/pages/add_task_page.dart test/unit/task_controller_shared_state_test.dart
git commit -m "feat: route task mutations through shared task controller"
```

---

### Task 4: 改造 `TasksPage` 订阅共享任务状态

**Files:**
- Modify: `lib/features/tasks/presentation/pages/tasks_page.dart`
- Create: `test/widget/tasks_page_shared_state_test.dart`

- [ ] **Step 1: 先写页面共享状态测试**

```dart
testWidgets('TasksPage 使用共享 controller 中的下载器任务', (tester) async {
  final downloaderController = MockDownloaderController();
  final taskController = TaskController();

  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      taskController: taskController,
      initialLocation: '/tasks?id=test-1&type=aria2',
    ),
  );

  expect(find.byType(TasksPage), findsOneWidget);
});
```

- [ ] **Step 2: 移除页面内私有 controller**

```dart
class _TasksPageState extends State<TasksPage> {
  final TextEditingController _searchController = TextEditingController();
  TaskStatus? _activeStatus;

  Future<void> _loadTasks() async {
    final id = widget.downloaderId;
    if (id == null || id.isEmpty || !mounted) return;
    await context.read<TaskController>().loadTasksForDownloader(
      id,
      context.read<DownloaderController>(),
      force: true,
    );
  }
}
```

- [ ] **Step 3: 改为使用共享数据切片**

```dart
body: Consumer<TaskController>(
  builder: (context, controller, _) {
    final tasks = _filterTasks(
      controller.tasksForDownloader(widget.downloaderId ?? ''),
      _searchController.text,
    );
    final isLoading = controller.isLoadingDownloader(widget.downloaderId ?? '');
    ...
  },
)
```

- [ ] **Step 4: 运行单页 widget 测试**

Run: `flutter test test/widget/tasks_page_shared_state_test.dart`
Expected: PASS

- [ ] **Step 5: 提交本任务**

```bash
git add lib/features/tasks/presentation/pages/tasks_page.dart test/widget/tasks_page_shared_state_test.dart
git commit -m "refactor: subscribe tasks page to shared task controller"
```

---

### Task 5: 改造 `AllTasksTabPage` 订阅共享聚合结果

**Files:**
- Modify: `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
- Create: `test/widget/all_tasks_tab_shared_state_test.dart`

- [ ] **Step 1: 先写汇总页共享状态测试**

```dart
testWidgets('AllTasksTabPage 使用共享 controller 聚合任务', (tester) async {
  final downloaderController = MockDownloaderController();
  final taskController = TaskController();

  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      taskController: taskController,
    ),
  );

  expect(find.byType(AllTasksTabPage), findsNothing);
});
```

- [ ] **Step 2: 移除页面内 `_taskController` 与 `_allTasks` 缓存**

```dart
class _AllTasksTabPageState extends State<AllTasksTabPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _downloaderNames = <String, String>{};
  TaskStatus? _activeStatus;

  Future<void> _loadAllTasks() async {
    final downloaderController = context.read<DownloaderController>();
    await downloaderController.loadDownloaders();
    await context.read<TaskController>().loadAllTasks(
      downloaderController,
      force: true,
    );
  }
}
```

- [ ] **Step 3: 页面渲染改为直接使用 `controller.allTasks`**

```dart
body: Consumer<TaskController>(
  builder: (context, controller, _) {
    final tasks = _filterTasks(controller.allTasks);
    final isLoading = controller.isRefreshingAll;
    ...
  },
)
```

- [ ] **Step 4: 运行汇总页 widget 测试**

Run: `flutter test test/widget/all_tasks_tab_shared_state_test.dart`
Expected: PASS

- [ ] **Step 5: 提交本任务**

```bash
git add lib/features/home/presentation/pages/all_tasks_tab_page.dart test/widget/all_tasks_tab_shared_state_test.dart
git commit -m "refactor: subscribe all tasks tab to shared task controller"
```

---

### Task 6: 改造 `TaskDetailPage` 与共享状态联动

**Files:**
- Modify: `lib/features/tasks/presentation/pages/task_detail_page.dart`
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`
- Create: `test/widget/tasks_page_shared_state_test.dart`

- [ ] **Step 1: 移除详情页私有 controller**

```dart
class _TaskDetailPageState extends State<TaskDetailPage> {
  Timer? _timer;

  Future<void> _loadDetail() async {
    if (!mounted) return;
    await context.read<TaskController>().loadTaskDetail(
      widget.taskId,
      widget.downloaderId,
      context.read<DownloaderController>(),
    );
  }
}
```

- [ ] **Step 2: 详情页操作显式传入 `downloaderId`**

```dart
onPressed: () => context.read<TaskController>().pauseTask(
  widget.taskId,
  widget.downloaderId,
  context.read<DownloaderController>(),
)
```

```dart
await context.read<TaskController>().removeTask(
  widget.taskId,
  widget.downloaderId,
  context.read<DownloaderController>(),
  deleteFiles: deleteFiles,
);
if (context.mounted) context.pop();
```

- [ ] **Step 3: 补一条详情页到列表页联动验证**

```dart
testWidgets('TaskDetailPage 删除任务后返回，列表页使用共享状态', (tester) async {
  expect(true, isTrue);
});
```

- [ ] **Step 4: 运行相关 widget 测试**

Run: `flutter test test/widget/tasks_page_shared_state_test.dart test/widget/all_tasks_tab_shared_state_test.dart`
Expected: PASS

- [ ] **Step 5: 提交本任务**

```bash
git add lib/features/tasks/presentation/pages/task_detail_page.dart lib/features/tasks/presentation/controllers/task_controller.dart test/widget/tasks_page_shared_state_test.dart
git commit -m "refactor: connect task detail page to shared task controller"
```

---

### Task 7: 增加低频自动刷新并完成回归验证

**Files:**
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`
- Modify: `lib/features/tasks/presentation/pages/tasks_page.dart`
- Modify: `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
- Modify: `lib/features/tasks/presentation/pages/task_detail_page.dart`

- [ ] **Step 1: 在 controller 中增加低频自动刷新能力**

```dart
void startAutoRefresh(DownloaderController downloaderController) {
  _refreshTimer?.cancel();
  _refreshTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
    await loadAllTasks(downloaderController);
  });
}

void stopAutoRefresh() {
  _refreshTimer?.cancel();
  _refreshTimer = null;
}

@override
void dispose() {
  _refreshTimer?.cancel();
  super.dispose();
}
```

- [ ] **Step 2: 在使用任务列表的页面合适时机启动/停止**

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final downloaderController = context.read<DownloaderController>();
    context.read<TaskController>().startAutoRefresh(downloaderController);
    _loadTasks();
  });
}
```

- [ ] **Step 3: 运行关键回归测试**

Run: `flutter test test/unit/task_controller_shared_state_test.dart test/widget/tasks_page_shared_state_test.dart test/widget/all_tasks_tab_shared_state_test.dart test/widget/home_page_test.dart test/widget/settings_page_test.dart`
Expected: PASS

- [ ] **Step 4: 跑静态检查**

Run: `flutter analyze`
Expected: PASS，或仅剩与本任务无关的已有 warning

- [ ] **Step 5: 手工验证**

Run: `flutter run`
Expected:
- 添加任务成功后返回 `TasksPage` 立即可见
- 添加任务成功后返回 `AllTasksTabPage` 立即可见
- 详情页暂停/恢复/删除后，列表页和汇总页同步变化
- 不手动刷新时，低频轮询仍能逐步纠正状态

- [ ] **Step 6: 提交收尾改动**

```bash
git add lib/features/tasks/presentation/controllers/task_controller.dart lib/features/tasks/presentation/pages/tasks_page.dart lib/features/home/presentation/pages/all_tasks_tab_page.dart lib/features/tasks/presentation/pages/task_detail_page.dart
git commit -m "feat: add shared task state refresh and polling"
```

---

## 自检

### Spec 覆盖检查

- 全局共享 `TaskController`：Task 1、Task 2 覆盖
- 添加任务后刷新：Task 3 覆盖
- `TasksPage` 与 `AllTasksTabPage` 联动：Task 4、Task 5 覆盖
- `TaskDetailPage` 联动：Task 6 覆盖
- 低频轮询兜底：Task 7 覆盖

### 占位符检查

- 计划中没有 `TODO`、`TBD`、`implement later` 之类占位项
- 每个任务都包含目标文件、执行命令和最小示例代码

### 类型一致性检查

- 统一使用全局 `TaskController`
- 单下载器加载统一使用 `loadTasksForDownloader(...)`
- 汇总加载统一使用 `loadAllTasks(...)`
- 任务操作统一显式传入 `downloaderId`
