# 全局下载器轮询迁移到任务域单一数据源 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保留当前已工作的全局轮询能力前提下，把 qBittorrent / Transmission 从“`RealtimeSyncController` 直接回写 `TaskController` / `DownloaderController`”迁移为“`RealtimeSyncController -> TaskDomainStore -> 页面/Controller`”的单一数据源架构。

**Architecture:** 这不是从零重建计划，而是一个增量迁移计划。当前代码里 typed snapshot、全局轮询、列表页与部分详情页实时展示已经落地；本计划以这些现状为基线，引入 `TaskDomainStore` 作为任务域唯一事实来源，让 `TaskController` / `DownloaderController` 从“实时数据接收器”迁移成“动作入口 / 兼容 facade”，最终删除 `RealtimeSyncController._propagateQBit/_propagateTransmission` 对 controller 的直推逻辑。

**Tech Stack:** Flutter 3.24.5、Provider、ChangeNotifier、go_router、flutter_test、widget test

---

## Current Code Baseline

### 已经完成的能力

- `lib/models/qbit_realtime_snapshot.dart`
  - qBit `sync/maindata` typed 快照与增量合并已存在。
- `lib/models/transmission_realtime_snapshot.dart`
  - Transmission 全量轮询 typed 快照已存在。
- `lib/features/realtime/presentation/controllers/realtime_sync_controller.dart`
  - App 启动后的 qBit / Transmission 全局轮询已存在。
  - 内部已经保存 `qbitSnapshot(...)`、`transmissionSnapshot(...)`、`transmissionDetail(...)`、`qbitTorrent(...)` 选择器。
- `lib/features/tasks/presentation/controllers/task_controller.dart`
  - 已有 per-downloader 任务缓存。
  - 已有 `applyPolledTasks(...)` 作为全局轮询写入口。
- `lib/features/downloaders/presentation/controllers/downloader_controller.dart`
  - 已有 `applyRealtimeSnapshot(...)` 作为全局轮询写入口。
- 列表页 / 详情页现状
  - `TaskDetailShell` 已移除 timer，直接读 `TaskController.taskForDownloader(...)`
  - `TasksPage` / `AllTasksTabPage` 已依赖 `RealtimeSyncController.refreshNow(...)`
  - `QBitTaskOptionsPage` 已从全局 qBit 首次快照读取 `categories` / `tags`

### 当前架构缺口

- `RealtimeSyncController` 仍直接调用：
  - `TaskController.applyPolledTasks(...)`
  - `DownloaderController.applyRealtimeSnapshot(...)`
- 这导致当前“实时真相”分散在三处：
  - `RealtimeSyncController` 内部 snapshot map
  - `TaskController` 任务缓存
  - `DownloaderController` 下载器实时状态
- 这与目标规则冲突：
  - 任务域共享数据必须以 `TaskDomainStore` 为唯一事实来源
  - 页面和 controller 不应该各自再保存第二份实时任务态

### 本次迁移的决定

- 保留当前 typed snapshot 与全局轮询，不推倒重来。
- 新增 `TaskDomainStore`，先承接实时真相，再迁移消费方。
- 第一阶段**不强制引入独立 `TaskListViewModel` / `TaskDetailViewModel` 文件**。
  - 当前项目体量下，优先用 `TaskDomainStore` selector 直接供页面消费。
  - 如果后续页面派生逻辑明显变复杂，再拆 selector VM。
- `TaskController` 继续保留：
  - 任务操作入口（暂停 / 恢复 / 删除 / 添加）
  - Aria2 非全局轮询加载路径
  - 过渡期兼容 facade
- `DownloaderController` 继续保留：
  - 下载器 CRUD
  - Aria2 状态探测
  - 过渡期兼容 facade

---

## Target Architecture

### Layer 1: Polling

- `RealtimeSyncController`
  - 唯一允许持有 timer 的层。
  - 只负责轮询、失败计数、rid 维护、离线判定。
  - 不再直接修改 `TaskController` / `DownloaderController` 内部状态。

### Layer 2: Single Source of Truth

- `TaskDomainStore`
  - 保存 qBit / Transmission 的原始 snapshot。
  - 保存标准化后的共享任务对象。
  - 保存下载器维度实时摘要：
    - 在线状态
    - download / upload speed
    - taskCount / taskStats
  - 保存详情页共享摘要：
    - Transmission detail summary
    - qBit 动态字段 summary
  - 保存 qBit 元数据：
    - `categories`
    - `tags`

### Layer 3: Consumers

- 列表页 / 详情页 / 详情子页头部摘要
  - 统一订阅 `TaskDomainStore`
- `TaskController`
  - 发起任务动作后触发 `TaskDomainStore` 局部刷新或回写
- `DownloaderController`
  - 下载器列表展示实时状态时，读取 `TaskDomainStore`

---

## Single Source of Truth Rules

- `TaskDomainStore` 是 qBit / Transmission 任务主数据唯一事实来源。
- 任何页面不得自行持有第二份实时任务副本。
- 页面级 controller 只允许维护：
  - UI 状态
  - 编辑草稿
  - 非实时静态补充数据
- 用户动作完成后必须满足二选一：
  - 直接回写 `TaskDomainStore`
  - 触发 `TaskDomainStore.refreshDownloader(...)` / `refreshTask(...)`
- 迁移完成后的删除目标：
  - `RealtimeSyncController._propagateQBit(...)`
  - `RealtimeSyncController._propagateTransmission(...)`
  - `TaskController.applyPolledTasks(...)`
  - `DownloaderController.applyRealtimeSnapshot(...)`

---

## Shared Task Scope

### 必须进入共享 Store 的字段

- `taskId`
- `downloaderId`
- `name`
- `status`
- `progress`
- `eta`
- `downloadSpeed`
- `uploadSpeed`
- `downloaded`
- `uploaded`
- `ratio`
- `savePath`
- `category`
- `tags`
- `queuePosition`
- `peerCount`
- `trackerCount`
- `sourceCount`
- 下载器级连接状态与总速率

### 允许继续页面独占加载的字段

- qBit files tree 明细
- qBit peers 明细
- qBit HTTP sources 明细
- Transmission files 明细
- Transmission peers 明细
- Transmission trackers 明细

### 共享后的体验要求

- 列表页改动后，详情页同步变化
- 详情主页改动后，子页头部摘要同步变化
- 分类 / 标签 / 队列优先级改动后，其他关于该任务的页面同步变化

---

## File Structure

### Create

- `lib/features/tasks/presentation/controllers/task_domain_store.dart`
  - 任务域共享 Store，保存 snapshot、标准化任务对象、下载器摘要与 selector。
- `test/unit/task_domain_store_test.dart`
  - Store 写入、selector、任务联动、qBit metadata 测试。
- `test/widget/task_domain_store_integration_test.dart`
  - 页面联动验证：一处更新后其他页面一起变化。

### Modify

- `lib/features/realtime/presentation/controllers/realtime_sync_controller.dart`
  - 改为写 `TaskDomainStore`，删除对 controller 的直推。
- `lib/app.dart`
  - 注册 `TaskDomainStore` Provider，并把它注入 `RealtimeSyncController` / `TaskController` / `DownloaderController`。
- `lib/features/tasks/presentation/controllers/task_controller.dart`
  - 过渡成动作入口与 Aria2 facade；qBit / Transmission 共享态改为读 Store。
- `lib/features/downloaders/presentation/controllers/downloader_controller.dart`
  - 下载器实时摘要改为读 Store；保留 Aria2 自有逻辑。
- `lib/features/tasks/presentation/widgets/task_detail_shell.dart`
  - 改为优先读 `TaskDomainStore.task(...)`。
- `lib/features/tasks/presentation/pages/tasks_page.dart`
  - 改为读 `TaskDomainStore.tasksForDownloader(...)`。
- `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
  - 改为读 `TaskDomainStore.allTasks`。
- `lib/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart`
  - 动态字段从 `TaskDomainStore` 读。
- `lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart`
  - 详情摘要从 `TaskDomainStore` 读。
- `lib/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart`
  - 改为从 `TaskDomainStore` 读 qBit categories / tags。
- `test/unit/realtime_sync_controller_test.dart`
  - 改写断言：验证写 Store，不再验证写 controller。
- `test/unit/task_controller_shared_state_test.dart`
  - 改写为 facade / Aria2 兼容测试。
- `test/unit/downloader_controller_gate_test.dart`
  - 改写为 Store 读取和 Aria2 兼容测试。
- `test/widget/all_tasks_tab_shared_state_test.dart`
- `test/widget/tasks_page_shared_state_test.dart`
- `test/widget/qbit_task_detail_page_test.dart`
- `test/widget/transmission_task_detail_page_test.dart`
- `test/widget/qbit_task_options_page_test.dart`
  - 改为基于 `TaskDomainStore` 的共享态断言。

---

### Task 1: 锁定当前行为，补上“迁移不回退”测试基线

**Files:**
- Modify: `test/unit/realtime_sync_controller_test.dart`
- Modify: `test/widget/tasks_page_shared_state_test.dart`
- Modify: `test/widget/all_tasks_tab_shared_state_test.dart`
- Create: `test/widget/task_domain_store_integration_test.dart`

- [ ] **Step 1: 先写 Store 驱动的联动失败测试**

```dart
testWidgets('同一任务在列表页和详情页共享同一份状态', (tester) async {
  final store = TaskDomainStore();

  store.debugApplyQBitSnapshot(
    QBitRealtimeSnapshot.fromJson(
      downloaderId: 'q1',
      json: {
        'rid': 1,
        'full_update': true,
        'server_state': {'dl_info_speed': 100, 'up_info_speed': 20},
        'torrents': {
          'abc': {
            'name': 'demo',
            'state': 'downloading',
            'progress': 0.2,
            'dlspeed': 100,
            'upspeed': 20,
            'total_size': 1000,
            'downloaded': 200,
            'uploaded': 50,
            'save_path': '/ptd',
          }
        },
      },
    ),
  );

  expect(store.task('q1', 'abc')!.progress, 0.2);

  store.debugApplyQBitSnapshot(
    store.qbitSnapshot('q1')!.mergeJson({
      'rid': 2,
      'torrents': {
        'abc': {'progress': 0.5, 'dlspeed': 200},
      },
    }),
  );

  expect(store.task('q1', 'abc')!.progress, 0.5);
  expect(store.tasksForDownloader('q1').single.progress, 0.5);
});
```

- [ ] **Step 2: 改写 RealtimeSyncController 单测目标，先让它失败**

```dart
test('qBit poll 成功后写入 TaskDomainStore，而不是直接写 TaskController', () async {
  final store = TaskDomainStore();
  final controller = RealtimeSyncController(
    qbitPollerFactory: (downloader, rid) async => {
      'rid': 1,
      'full_update': true,
      'server_state': {'dl_info_speed': 100, 'up_info_speed': 20},
      'torrents': {
        'abc': {
          'name': 'demo',
          'state': 'downloading',
          'progress': 0.2,
          'dlspeed': 100,
          'upspeed': 20,
          'total_size': 1000,
          'downloaded': 200,
          'uploaded': 50,
          'save_path': '/ptd',
        }
      },
    },
  )..attachStore(store);

  await controller.debugPollOnce(fakeQBitDownloader);

  expect(store.qbitSnapshot('q1')?.rid, 1);
  expect(store.task('q1', 'abc')?.name, 'demo');
});
```

- [ ] **Step 3: 运行测试确认失败**

Run:
```bash
flutter test test/unit/realtime_sync_controller_test.dart
flutter test test/widget/task_domain_store_integration_test.dart
```

Expected:
- `TaskDomainStore` 未定义
- `attachStore(...)` 未定义
- 旧测试仍在假设 controller 直推

- [ ] **Step 4: 提交测试基线**

```bash
git add \
  test/unit/realtime_sync_controller_test.dart \
  test/widget/tasks_page_shared_state_test.dart \
  test/widget/all_tasks_tab_shared_state_test.dart \
  test/widget/task_domain_store_integration_test.dart
git commit -m "test: lock shared task state migration behavior"
```

---

### Task 2: 新增 TaskDomainStore，承接 snapshot 与标准化任务真相

**Files:**
- Create: `lib/features/tasks/presentation/controllers/task_domain_store.dart`
- Create: `test/unit/task_domain_store_test.dart`

- [ ] **Step 1: 先写 TaskDomainStore 核心失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';

void main() {
  test('applyQBitSnapshot 会同步更新 snapshot、任务列表、qBit categories 与 tags', () {
    final store = TaskDomainStore();

    store.applyQBitSnapshot(
      QBitRealtimeSnapshot.fromJson(
        downloaderId: 'q1',
        json: {
          'rid': 1,
          'full_update': true,
          'categories': {
            'radarr': {'name': 'radarr', 'savePath': ''},
          },
          'tags': ['RENAME'],
          'server_state': {'dl_info_speed': 100, 'up_info_speed': 20},
          'torrents': {
            'abc': {
              'name': 'demo',
              'state': 'downloading',
              'progress': 0.2,
              'dlspeed': 100,
              'upspeed': 20,
              'total_size': 1000,
              'downloaded': 200,
              'uploaded': 50,
              'save_path': '/ptd',
              'category': 'radarr',
              'tags': 'RENAME',
            },
          },
        },
      ),
    );

    expect(store.qbitSnapshot('q1')?.rid, 1);
    expect(store.tasksForDownloader('q1').single.name, 'demo');
    expect(store.qbitCategories('q1'), ['radarr']);
    expect(store.qbitTags('q1'), ['RENAME']);
  });
}
```

- [ ] **Step 2: 写最小 Store 实现**

`lib/features/tasks/presentation/controllers/task_domain_store.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';
import 'package:windwalker/models/transmission_realtime_snapshot.dart';
import 'package:windwalker/models/transmission_task_detail.dart';

class DownloaderRealtimeSummary {
  const DownloaderRealtimeSummary({
    required this.status,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.taskCount,
    required this.taskStats,
  });

  final DownloaderStatus status;
  final int downloadSpeed;
  final int uploadSpeed;
  final int taskCount;
  final Map<String, int> taskStats;
}

class TaskDomainStore extends ChangeNotifier {
  final Map<String, QBitRealtimeSnapshot> _qbitSnapshots = {};
  final Map<String, TransmissionRealtimeSnapshot> _transmissionSnapshots = {};
  final Map<String, List<DownloadTask>> _tasksByDownloader = {};
  final Map<String, DownloaderRealtimeSummary> _summaries = {};

  QBitRealtimeSnapshot? qbitSnapshot(String downloaderId) =>
      _qbitSnapshots[downloaderId];

  TransmissionRealtimeSnapshot? transmissionSnapshot(String downloaderId) =>
      _transmissionSnapshots[downloaderId];

  List<DownloadTask> tasksForDownloader(String downloaderId) =>
      List.unmodifiable(_tasksByDownloader[downloaderId] ?? const []);

  List<DownloadTask> get allTasks {
    final tasks = _tasksByDownloader.values.expand((e) => e).toList();
    tasks.sort((a, b) => b.downloadSpeed.compareTo(a.downloadSpeed));
    return tasks;
  }

  DownloadTask? task(String downloaderId, String taskId) {
    for (final task in _tasksByDownloader[downloaderId] ?? const <DownloadTask>[]) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  List<String> qbitCategories(String downloaderId) =>
      qbitSnapshot(downloaderId)?.categories.values.toList() ?? const [];

  List<String> qbitTags(String downloaderId) =>
      qbitSnapshot(downloaderId)?.tags ?? const [];

  DownloaderRealtimeSummary? summary(String downloaderId) =>
      _summaries[downloaderId];

  void applyQBitSnapshot(QBitRealtimeSnapshot snapshot) {
    final tasks = snapshot.tasks;
    _qbitSnapshots[snapshot.downloaderId] = snapshot;
    _tasksByDownloader[snapshot.downloaderId] = List<DownloadTask>.from(tasks);
    _summaries[snapshot.downloaderId] = DownloaderRealtimeSummary(
      status: DownloaderStatus.online,
      downloadSpeed: snapshot.serverState.downloadSpeed,
      uploadSpeed: snapshot.serverState.uploadSpeed,
      taskCount: tasks.length,
      taskStats: _aggregate(tasks),
    );
    notifyListeners();
  }

  void applyTransmissionSnapshot(TransmissionRealtimeSnapshot snapshot) {
    final tasks = snapshot.tasks;
    _transmissionSnapshots[snapshot.downloaderId] = snapshot;
    _tasksByDownloader[snapshot.downloaderId] = List<DownloadTask>.from(tasks);
    _summaries[snapshot.downloaderId] = DownloaderRealtimeSummary(
      status: DownloaderStatus.online,
      downloadSpeed: snapshot.totalDownloadSpeed,
      uploadSpeed: snapshot.totalUploadSpeed,
      taskCount: tasks.length,
      taskStats: _aggregate(tasks),
    );
    notifyListeners();
  }

  void markDownloaderOffline(String downloaderId) {
    _summaries[downloaderId] = const DownloaderRealtimeSummary(
      status: DownloaderStatus.offline,
      downloadSpeed: 0,
      uploadSpeed: 0,
      taskCount: 0,
      taskStats: {},
    );
    notifyListeners();
  }

  Map<String, int> _aggregate(List<DownloadTask> tasks) {
    final stats = <String, int>{
      'downloading': 0,
      'waiting': 0,
      'paused': 0,
      'seeding': 0,
      'completed': 0,
      'error': 0,
    };
    for (final task in tasks) {
      switch (task.status) {
        case TaskStatus.downloading:
          stats['downloading'] = stats['downloading']! + 1;
          break;
        case TaskStatus.waiting:
          stats['waiting'] = stats['waiting']! + 1;
          break;
        case TaskStatus.paused:
          stats['paused'] = stats['paused']! + 1;
          break;
        case TaskStatus.seeding:
          stats['seeding'] = stats['seeding']! + 1;
          break;
        case TaskStatus.completed:
        case TaskStatus.removed:
          stats['completed'] = stats['completed']! + 1;
          break;
        case TaskStatus.error:
          stats['error'] = stats['error']! + 1;
          break;
        case TaskStatus.unknown:
          break;
      }
    }
    return stats;
  }
}
```

- [ ] **Step 3: 运行 Store 单测确认通过**

Run:
```bash
flutter test test/unit/task_domain_store_test.dart
```

Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add \
  lib/features/tasks/presentation/controllers/task_domain_store.dart \
  test/unit/task_domain_store_test.dart
git commit -m "feat: add task domain store"
```

---

### Task 3: 让 RealtimeSyncController 改为只写 TaskDomainStore

**Files:**
- Modify: `lib/features/realtime/presentation/controllers/realtime_sync_controller.dart`
- Modify: `lib/app.dart`
- Modify: `test/unit/realtime_sync_controller_test.dart`

- [ ] **Step 1: 改写 attach 方式，先让测试失败**

```dart
test('轮询成功后只写 TaskDomainStore', () async {
  final store = TaskDomainStore();
  final controller = RealtimeSyncController(
    qbitPollerFactory: (downloader, rid) async => {
      'rid': 1,
      'full_update': true,
      'server_state': {'dl_info_speed': 100},
      'torrents': {
        'abc': {
          'name': 'demo',
          'state': 'downloading',
          'progress': 0.2,
          'dlspeed': 100,
          'save_path': '/ptd',
        }
      },
    },
  )..attachStore(store);

  await controller.debugPollOnce(fakeQBitDownloader);

  expect(store.task('q1', 'abc')?.name, 'demo');
});
```

- [ ] **Step 2: 修改 RealtimeSyncController 实现**

```dart
class RealtimeSyncController extends ChangeNotifier {
  TaskDomainStore? _taskDomainStore;

  void attachStore(TaskDomainStore store) {
    _taskDomainStore = store;
  }

  void _propagateQBit(Downloader downloader, QBitRealtimeSnapshot snapshot) {
    _taskDomainStore?.applyQBitSnapshot(snapshot);
  }

  void _propagateTransmission(
    Downloader downloader,
    TransmissionRealtimeSnapshot snapshot,
  ) {
    _taskDomainStore?.applyTransmissionSnapshot(snapshot);
  }

  void _onPollFailure(Downloader downloader, Object e, StackTrace st) {
    final count = (_failureCounts[downloader.id] ?? 0) + 1;
    _failureCounts[downloader.id] = count;
    if (count >= _maxConsecutiveFailures) {
      _taskDomainStore?.markDownloaderOffline(downloader.id);
    }
  }
}
```

`lib/app.dart`

```dart
ChangeNotifierProvider(create: (_) => TaskDomainStore()),
ChangeNotifierProxyProvider2<
    DownloaderController,
    TaskDomainStore,
    RealtimeSyncController>(
  create: (_) => RealtimeSyncController(),
  update: (_, downloaderController, taskDomainStore, previous) {
    final controller = previous ?? RealtimeSyncController();
    controller.attach(
      downloaderController: downloaderController,
      taskController: null,
    );
    controller.attachStore(taskDomainStore);
    return controller;
  },
),
```

实现时同步把 `attach(...)` 从“强依赖 TaskController”改成只依赖下载器列表来源；不要再让 `TaskController` 参与全局实时链路。

- [ ] **Step 3: 运行单测确认通过**

Run:
```bash
flutter test test/unit/realtime_sync_controller_test.dart
```

Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add \
  lib/features/realtime/presentation/controllers/realtime_sync_controller.dart \
  lib/app.dart \
  test/unit/realtime_sync_controller_test.dart
git commit -m "refactor: route realtime polling through task domain store"
```

---

### Task 4: 把页面读取从 TaskController 迁到 TaskDomainStore

**Files:**
- Modify: `lib/features/tasks/presentation/widgets/task_detail_shell.dart`
- Modify: `lib/features/tasks/presentation/pages/tasks_page.dart`
- Modify: `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
- Modify: `lib/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart`
- Modify: `lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart`
- Modify: `lib/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart`
- Modify: `test/widget/tasks_page_shared_state_test.dart`
- Modify: `test/widget/all_tasks_tab_shared_state_test.dart`
- Modify: `test/widget/qbit_task_detail_page_test.dart`
- Modify: `test/widget/transmission_task_detail_page_test.dart`
- Modify: `test/widget/qbit_task_options_page_test.dart`

- [ ] **Step 1: 先改最小读取入口**

`lib/features/tasks/presentation/widgets/task_detail_shell.dart`

```dart
final task = context.watch<TaskDomainStore>().task(
  widget.downloaderId,
  widget.taskId,
);
```

`lib/features/tasks/presentation/pages/tasks_page.dart`

```dart
final tasks = _filterTasks(
  context.watch<TaskDomainStore>().tasksForDownloader(widget.downloaderId ?? ''),
  _searchController.text,
);
```

`lib/features/home/presentation/pages/all_tasks_tab_page.dart`

```dart
final tasks = _filteredTasks(context.watch<TaskDomainStore>().allTasks);
```

`lib/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart`

```dart
final store = context.read<TaskDomainStore>();
await _controller.load(
  taskId: widget.taskId,
  downloader: downloader,
  availableCategories: store.qbitCategories(widget.downloaderId),
  availableTags: store.qbitTags(widget.downloaderId),
);
```

- [ ] **Step 2: 跑 widget 测试并修复断言**

Run:
```bash
flutter test test/widget/tasks_page_shared_state_test.dart
flutter test test/widget/all_tasks_tab_shared_state_test.dart
flutter test test/widget/qbit_task_detail_page_test.dart
flutter test test/widget/transmission_task_detail_page_test.dart
flutter test test/widget/qbit_task_options_page_test.dart
```

Expected:
- 初始会失败，因为测试环境尚未提供 `TaskDomainStore`
- 修复后 PASS

- [ ] **Step 3: 提交**

```bash
git add \
  lib/features/tasks/presentation/widgets/task_detail_shell.dart \
  lib/features/tasks/presentation/pages/tasks_page.dart \
  lib/features/home/presentation/pages/all_tasks_tab_page.dart \
  lib/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart \
  lib/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart \
  lib/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart \
  test/widget/tasks_page_shared_state_test.dart \
  test/widget/all_tasks_tab_shared_state_test.dart \
  test/widget/qbit_task_detail_page_test.dart \
  test/widget/transmission_task_detail_page_test.dart \
  test/widget/qbit_task_options_page_test.dart
git commit -m "refactor: make task pages consume task domain store"
```

---

### Task 5: 让 TaskController / DownloaderController 退化为 facade，并清理旧写入口

**Files:**
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`
- Modify: `lib/features/downloaders/presentation/controllers/downloader_controller.dart`
- Modify: `test/unit/task_controller_shared_state_test.dart`
- Modify: `test/unit/downloader_controller_gate_test.dart`

- [ ] **Step 1: 先改写单测目标**

```dart
test('TaskController 对 qBit / Transmission 读取委托给 TaskDomainStore', () {
  final store = TaskDomainStore();
  final controller = TaskController(taskDomainStore: store);

  store.debugSetTasksForDownloader('q1', [
    DownloadTask(
      id: 'abc',
      gid: 'abc',
      name: 'demo',
      downloaderId: 'q1',
    ),
  ]);

  expect(controller.tasksForDownloader('q1').single.name, 'demo');
});
```

- [ ] **Step 2: 调整 controller 角色**

`lib/features/tasks/presentation/controllers/task_controller.dart`

```dart
class TaskController extends ChangeNotifier {
  TaskController({TaskDomainStore? taskDomainStore})
      : _taskDomainStore = taskDomainStore;

  TaskDomainStore? _taskDomainStore;

  void attachTaskDomainStore(TaskDomainStore store) {
    _taskDomainStore = store;
  }

  List<DownloadTask> tasksForDownloader(String downloaderId) {
    final store = _taskDomainStore;
    if (store != null) return store.tasksForDownloader(downloaderId);
    return List.unmodifiable(_tasksByDownloader[downloaderId] ?? const []);
  }

  DownloadTask? taskForDownloader(String downloaderId, String taskId) {
    final store = _taskDomainStore;
    if (store != null) return store.task(downloaderId, taskId);
    ...
  }
}
```

`lib/features/downloaders/presentation/controllers/downloader_controller.dart`

```dart
TaskDomainStore? _taskDomainStore;

void attachTaskDomainStore(TaskDomainStore store) {
  _taskDomainStore = store;
}

Downloader? getDownloader(String id) {
  return _downloaders.where((d) => d.id == id).firstOrNull;
}

DownloaderRealtimeSummary? realtimeSummary(String downloaderId) =>
    _taskDomainStore?.summary(downloaderId);
```

这个阶段先不要着急把所有旧字段删光；目标是“读路径切 Store，写路径只留 Aria2 / 本地管理逻辑”。

- [ ] **Step 3: 删除旧实时写入口**

删除：

```dart
void applyPolledTasks(String downloaderId, List<DownloadTask> tasks)
void applyRealtimeSnapshot(...)
```

同时清理所有调用点和相关测试。

- [ ] **Step 4: 运行 controller 单测**

Run:
```bash
flutter test test/unit/task_controller_shared_state_test.dart
flutter test test/unit/downloader_controller_gate_test.dart
```

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add \
  lib/features/tasks/presentation/controllers/task_controller.dart \
  lib/features/downloaders/presentation/controllers/downloader_controller.dart \
  test/unit/task_controller_shared_state_test.dart \
  test/unit/downloader_controller_gate_test.dart
git commit -m "refactor: make task and downloader controllers facades"
```

---

### Task 6: 任务动作后刷新共享 Store，保证跨页面同步

**Files:**
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`
- Modify: `lib/features/tasks/presentation/controllers/qbit_task_options_controller.dart`
- Modify: `lib/features/tasks/presentation/controllers/transmission_task_options_controller.dart`
- Modify: `test/unit/qbit_task_options_controller_test.dart`
- Modify: `test/widget/qbit_task_options_page_test.dart`

- [ ] **Step 1: 先写动作后联动失败测试**

```dart
test('qBit 队列优先级即时生效后会触发共享任务刷新', () async {
  final refreshed = <String>[];
  final store = FakeTaskDomainStore(
    onRefreshDownloader: (downloaderId) => refreshed.add(downloaderId),
  );
  final controller = QBitTaskOptionsController(
    serviceFactory: (_) => fakeService,
    taskDomainStore: store,
  );

  await controller.applyQueueActionNow(
    taskId: 'abc',
    downloader: fakeQBitDownloader,
    action: QBitQueuePriorityAction.top,
  );

  expect(refreshed, ['q1']);
});
```

- [ ] **Step 2: 为 TaskDomainStore 增加刷新钩子**

```dart
typedef RefreshDownloaderCallback = Future<void> Function(String downloaderId);

class TaskDomainStore extends ChangeNotifier {
  RefreshDownloaderCallback? refreshDownloader;
}
```

更实际的落地方式是由 `TaskController` / 页面动作完成后调用：

```dart
await context.read<RealtimeSyncController>().refreshNow(
  downloaderId: downloader.id,
);
```

但调用后，所有展示仍必须落回 `TaskDomainStore`。  
也就是说这里的规则不是“控制器不能主动 refresh”，而是“refresh 结果不能落在别处”。

- [ ] **Step 3: 运行相关测试**

Run:
```bash
flutter test test/unit/qbit_task_options_controller_test.dart
flutter test test/widget/qbit_task_options_page_test.dart
```

Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add \
  lib/features/tasks/presentation/controllers/task_controller.dart \
  lib/features/tasks/presentation/controllers/qbit_task_options_controller.dart \
  lib/features/tasks/presentation/controllers/transmission_task_options_controller.dart \
  test/unit/qbit_task_options_controller_test.dart \
  test/widget/qbit_task_options_page_test.dart
git commit -m "refactor: refresh shared task state after task actions"
```

---

### Task 7: 全量回归并删除迁移残留

**Files:**
- Modify: `lib/features/realtime/presentation/controllers/realtime_sync_controller.dart`
- Modify: `lib/app.dart`
- Modify: `test/...` 相关文件

- [ ] **Step 1: 搜索残留旧路径**

Run:
```bash
rg -n "applyPolledTasks|applyRealtimeSnapshot|taskController\\.|RealtimeStore|_propagateQBit|_propagateTransmission" lib test
```

Expected:
- 不再有 `applyPolledTasks`
- 不再有 `applyRealtimeSnapshot`
- `RealtimeSyncController` 不再直接依赖 `TaskController`

- [ ] **Step 2: 跑目标测试集**

Run:
```bash
flutter test \
  test/unit/realtime_sync_controller_test.dart \
  test/unit/task_domain_store_test.dart \
  test/unit/task_controller_shared_state_test.dart \
  test/unit/downloader_controller_gate_test.dart \
  test/unit/qbit_task_options_controller_test.dart \
  test/widget/tasks_page_shared_state_test.dart \
  test/widget/all_tasks_tab_shared_state_test.dart \
  test/widget/qbit_task_detail_page_test.dart \
  test/widget/transmission_task_detail_page_test.dart \
  test/widget/qbit_task_options_page_test.dart \
  test/widget/task_domain_store_integration_test.dart
```

Expected: PASS

- [ ] **Step 3: 跑一轮更广泛回归**

Run:
```bash
flutter test
```

Expected: PASS  
如果全量测试耗时太长，至少保留上一条目标测试集作为发布前门槛。

- [ ] **Step 4: 提交**

```bash
git add lib test
git commit -m "refactor: finish task domain store migration"
```

---

## Self-Review

### Spec coverage

- “当前计划必须基于现有代码重写”
  - 已覆盖：`Current Code Baseline`
- “不要让 subagent 重复实现已提交工作”
  - 已覆盖：Task 1 起点改为迁移测试基线，Task 2 起点改为新增 Store
- “任务相关页面共享同一份状态”
  - 已覆盖：Task 2 / Task 4 / Task 6
- “qBit categories / tags 来自首次全局轮询”
  - 已覆盖：Task 2 selector、Task 4 options page
- “最终删除 RealtimeSyncController 直推 controller 的快捷路径”
  - 已覆盖：Task 3 / Task 5 / Task 7

### Placeholder scan

- 已移除旧计划里从零实现 `RealtimeSyncController` / typed snapshot 的任务。
- 已移除 `RealtimeStore` 与未落地 page viewmodel 的误导性表述。

### Type consistency

- 单一事实来源统一命名为 `TaskDomainStore`
- 页面读取统一使用：
  - `task(...)`
  - `tasksForDownloader(...)`
  - `allTasks`
  - `qbitCategories(...)`
  - `qbitTags(...)`
  - `summary(...)`

---

Plan complete and saved to `docs/superpowers/plans/2026-06-26-global-downloader-polling.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
