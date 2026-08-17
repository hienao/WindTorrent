# 总览页任务状态点击跳转实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 DataTab（总览页）的任务状态矩阵中，点击任意状态 item 后，切换到任务列表 tab 并自动选中对应的筛选项。

**Architecture:** 通过扩展 onShowTasks 回调参数类型，将 TaskStatus 从 DataTab 传递到 HomeTabContainer，再传递给 TasksTab 和 AllTasksTabPage。修改 NeoStatusMatrix 和 _StatusTile 添加点击交互。

**Tech Stack:** Flutter, Provider, go_router

## Global Constraints

- 遵循项目现有的 Provider + ChangeNotifier 状态管理模式
- 使用 go_router 进行路由管理
- 遵循 DESIGN.md 中的视觉规范
- 遵循 CLAUDE.md 中的编码规范（禁止防御性编程）

---

### Task 1: 修改 NeoStatusMatrix 添加点击回调

**Files:**
- Modify: `lib/features/home/presentation/widgets/neo_overview_widgets.dart:349-473`

**Interfaces:**
- Produces: `NeoStatusMatrix.onStatusTap` 回调，参数类型 `void Function(TaskStatus)?`

- [ ] **Step 1: 添加 TaskStatus import**

在文件顶部添加 import：
```dart
import 'package:windwalker/models/download_task.dart';
```

- [ ] **Step 2: 添加状态字符串到枚举的映射函数**

在 NeoStatusMatrix 类之前添加：
```dart
/// 将状态字符串映射到 TaskStatus 枚举
TaskStatus? _statusFromString(String status) {
  switch (status) {
    case 'downloading':
      return TaskStatus.downloading;
    case 'waiting':
      return TaskStatus.waiting;
    case 'paused':
      return TaskStatus.paused;
    case 'seeding':
      return TaskStatus.seeding;
    case 'completed':
      return TaskStatus.completed;
    case 'error':
      return TaskStatus.error;
    default:
      return null;
  }
}
```

- [ ] **Step 3: 修改 NeoStatusMatrix 类**

添加 `onStatusTap` 参数：
```dart
class NeoStatusMatrix extends StatelessWidget {
  final Map<String, int> stats;
  final void Function(TaskStatus)? onStatusTap;

  const NeoStatusMatrix({
    super.key,
    required this.stats,
    this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      _StatusItem(
        Icons.arrow_downward_rounded,
        l10n.downloading,
        stats['downloading'] ?? 0,
        AppColors.primary,
        'downloading',
      ),
      _StatusItem(
        Icons.schedule_rounded,
        l10n.waiting,
        stats['waiting'] ?? 0,
        AppColors.warning,
        'waiting',
      ),
      _StatusItem(
        Icons.pause_rounded,
        l10n.paused,
        stats['paused'] ?? 0,
        AppColors.textTertiaryLight,
        'paused',
      ),
      _StatusItem(
        Icons.upload_rounded,
        l10n.seeding,
        stats['seeding'] ?? 0,
        AppColors.success,
        'seeding',
      ),
      _StatusItem(
        Icons.task_alt_rounded,
        l10n.completed,
        stats['completed'] ?? 0,
        AppColors.success,
        'completed',
      ),
      _StatusItem(
        Icons.error_outline_rounded,
        l10n.error,
        stats['error'] ?? 0,
        AppColors.error,
        'error',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 104,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _StatusTile(
        item: items[index],
        onTap: () {
          final status = _statusFromString(items[index].statusKey);
          if (status != null) {
            onStatusTap?.call(status);
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 4: 修改 _StatusItem 类**

添加 `statusKey` 字段：
```dart
class _StatusItem {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String statusKey;

  const _StatusItem(this.icon, this.label, this.value, this.color, this.statusKey);
}
```

- [ ] **Step 5: 修改 _StatusTile 类**

添加 InkWell 包装和 onTap 回调：
```dart
class _StatusTile extends StatelessWidget {
  final _StatusItem item;
  final VoidCallback? onTap;

  const _StatusTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: NeoSurface(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${item.value}',
                maxLines: 1,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: 运行代码检查**

Run: `flutter analyze lib/features/home/presentation/widgets/neo_overview_widgets.dart`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/presentation/widgets/neo_overview_widgets.dart
git commit -m "feat: add onStatusTap callback to NeoStatusMatrix"
```

---

### Task 2: 修改 DataTab 传递状态回调

**Files:**
- Modify: `lib/features/home/presentation/pages/data_tab.dart:13-122`

**Interfaces:**
- Consumes: `NeoStatusMatrix.onStatusTap` (来自 Task 1)
- Produces: `DataTab.onShowTasks` 类型改为 `void Function(TaskStatus?)?`

- [ ] **Step 1: 添加 import**

在文件顶部添加：
```dart
import 'package:windwalker/models/download_task.dart';
```

- [ ] **Step 2: 修改 DataTab 类**

修改 `onShowTasks` 类型：
```dart
class DataTab extends StatelessWidget {
  final VoidCallback? onShowDownloaders;
  final void Function(TaskStatus?)? onShowTasks;

  const DataTab({super.key, this.onShowDownloaders, this.onShowTasks});
```

- [ ] **Step 3: 传递回调给 NeoStatusMatrix**

修改 NeoStatusMatrix 的调用：
```dart
child: NeoStatusMatrix(
  stats: stats,
  onStatusTap: onShowTasks,
),
```

- [ ] **Step 4: 运行代码检查**

Run: `flutter analyze lib/features/home/presentation/pages/data_tab.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/pages/data_tab.dart
git commit -m "feat: change onShowTasks type to accept TaskStatus parameter"
```

---

### Task 3: 修改 HomeTabContainer 处理状态传递

**Files:**
- Modify: `lib/features/home/presentation/pages/home_tab_container.dart:15-139`

**Interfaces:**
- Consumes: `DataTab.onShowTasks` (来自 Task 2)
- Produces: `TasksTab.initialStatus` 参数

- [ ] **Step 1: 添加 import**

在文件顶部添加：
```dart
import 'package:windwalker/models/download_task.dart';
```

- [ ] **Step 2: 添加状态字段**

在 `_HomeTabContainerState` 中添加：
```dart
class _HomeTabContainerState extends State<HomeTabContainer> {
  int _currentIndex = 0;
  TaskStatus? _pendingTaskStatus;
```

- [ ] **Step 3: 修改 DataTab 的 onShowTasks 回调**

```dart
DataTab(
  onShowDownloaders: () => setState(() => _currentIndex = 1),
  onShowTasks: (status) => setState(() {
    _pendingTaskStatus = status;
    _currentIndex = 2;
  }),
),
```

- [ ] **Step 4: 修改 TasksTab 传递 initialStatus**

```dart
TasksTab(initialStatus: _pendingTaskStatus),
```

- [ ] **Step 5: 处理手动切换 tab 时的状态重置**

修改 `onTabSelected` 回调：
```dart
NeoHomeShell(
  selectedIndex: _currentIndex,
  onTabSelected: (value) => setState(() {
    if (value != 2) {
      _pendingTaskStatus = null;
    }
    _currentIndex = value;
  }),
```

- [ ] **Step 6: 运行代码检查**

Run: `flutter analyze lib/features/home/presentation/pages/home_tab_container.dart`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/presentation/pages/home_tab_container.dart
git commit -m "feat: pass TaskStatus to TasksTab via pendingTaskStatus"
```

---

### Task 4: 修改 TasksTab 和 AllTasksTabPage 接收初始状态

**Files:**
- Modify: `lib/features/home/presentation/pages/tasks_tab.dart:1-12`
- Modify: `lib/features/home/presentation/pages/all_tasks_tab_page.dart:17-178`

**Interfaces:**
- Consumes: `HomeTabContainer._pendingTaskStatus` (来自 Task 3)
- Produces: `AllTasksTabPage.initialStatus` 参数，设置 `_activeStatus` 初始值

- [ ] **Step 1: 修改 TasksTab**

```dart
import 'package:flutter/material.dart';
import 'package:windwalker/features/home/presentation/pages/all_tasks_tab_page.dart';
import 'package:windwalker/models/download_task.dart';

class TasksTab extends StatelessWidget {
  final TaskStatus? initialStatus;

  const TasksTab({super.key, this.initialStatus});

  @override
  Widget build(BuildContext context) {
    return AllTasksTabPage(initialStatus: initialStatus);
  }
}
```

- [ ] **Step 2: 修改 AllTasksTabPage 添加 initialStatus 参数**

```dart
class AllTasksTabPage extends StatefulWidget {
  final TaskStatus? initialStatus;

  const AllTasksTabPage({super.key, this.initialStatus});

  @override
  State<AllTasksTabPage> createState() => _AllTasksTabPageState();
}
```

- [ ] **Step 3: 在 initState 中设置初始状态**

```dart
class _AllTasksTabPageState extends State<AllTasksTabPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _downloaderNames = <String, String>{};
  TaskStatus? _activeStatus;

  @override
  void initState() {
    super.initState();
    _activeStatus = widget.initialStatus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllTasks();
    });
  }
```

- [ ] **Step 4: 运行代码检查**

Run: `flutter analyze lib/features/home/presentation/pages/tasks_tab.dart lib/features/home/presentation/pages/all_tasks_tab_page.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/pages/tasks_tab.dart lib/features/home/presentation/pages/all_tasks_tab_page.dart
git commit -m "feat: add initialStatus parameter to TasksTab and AllTasksTabPage"
```

---

### Task 5: 集成测试和最终验证

**Files:**
- None (手动测试)

- [ ] **Step 1: 运行 flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 2: 运行现有测试**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: 手动测试场景**

1. 启动应用，进入总览页
2. 点击"下载中"状态 item → 验证切换到任务列表 tab，筛选项显示"下载中"选中
3. 点击"等待中"状态 item → 验证筛选项显示"等待中"选中
4. 点击"已暂停"状态 item → 验证筛选项显示"已暂停"选中
5. 点击"做种中"状态 item → 验证筛选项显示"做种中"选中
6. 点击"已完成"状态 item → 验证筛选项显示"已完成"选中
7. 点击"错误"状态 item → 验证筛选项显示"错误"选中
8. 手动切换到任务列表 tab → 验证筛选项显示"全部"选中
9. 点击数量为 0 的状态 → 验证仍然可以跳转，显示空列表

- [ ] **Step 4: 最终 Commit**

```bash
git add -A
git commit -m "feat: complete overview status tap navigation feature"
```

---

## 实现顺序

1. Task 1: 修改 NeoStatusMatrix 添加点击回调
2. Task 2: 修改 DataTab 传递状态回调
3. Task 3: 修改 HomeTabContainer 处理状态传递
4. Task 4: 修改 TasksTab 和 AllTasksTabPage 接收初始状态
5. Task 5: 集成测试和最终验证

## 风险和注意事项

1. **类型安全**: 确保 TaskStatus 枚举映射正确，避免运行时错误
2. **状态重置**: 手动切换 tab 时需要重置 _pendingTaskStatus 为 null
3. **边界情况**: 数量为 0 的状态仍然可点击
4. **视觉反馈**: InkWell 提供 Material Design 的 splash 效果
5. **代码规范**: 遵循项目现有的命名和结构规范
