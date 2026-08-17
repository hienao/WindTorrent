# 总览页任务状态点击跳转设计

**日期:** 2026-06-27
**状态:** 已确认

## 1. 需求概述

在 DataTab（总览页）的任务状态矩阵中，点击任意状态 item 后，切换到任务列表 tab 并自动选中对应的筛选项。

## 2. 用户选择

- **跳转方式**: Tab 内切换（通过回调）
- **技术方案**: 扩展 onShowTasks 回调参数
- **边界处理**: 即使数量为 0 也始终可点击

## 3. 技术设计

### 3.1 修改 HomeTabContainer

**文件:** `lib/features/home/presentation/pages/home_tab_container.dart`

将 `onShowTasks` 从 `VoidCallback` 改为 `void Function(TaskStatus?)?`：

```dart
DataTab(
  onShowDownloaders: () => setState(() => _currentIndex = 1),
  onShowTasks: (status) => setState(() {
    _pendingTaskStatus = status;
    _currentIndex = 2;
  }),
),
```

添加 `_pendingTaskStatus` 状态字段，在 tab 切换后传递给 TasksTab。

### 3.2 修改 DataTab

**文件:** `lib/features/home/presentation/pages/data_tab.dart`

- 修改 `onShowTasks` 类型为 `void Function(TaskStatus?)?`
- 传递给 NeoStatusMatrix

### 3.3 修改 NeoStatusMatrix 和 _StatusTile

**文件:** `lib/features/home/presentation/widgets/neo_overview_widgets.dart`

NeoStatusMatrix 添加回调参数：

```dart
class NeoStatusMatrix extends StatelessWidget {
  final Map<String, int> stats;
  final void Function(TaskStatus)? onStatusTap;

  const NeoStatusMatrix({
    super.key,
    required this.stats,
    this.onStatusTap,
  });
  // ...
}
```

_StatusTile 添加 InkWell 包装：

```dart
class _StatusTile extends StatelessWidget {
  final _StatusItem item;
  final VoidCallback? onTap;

  const _StatusTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: NeoSurface(
        // ... 原有内容
      ),
    );
  }
}
```

需要将状态字符串映射到 TaskStatus 枚举：

```dart
TaskStatus? _statusFromString(String status) {
  switch (status) {
    case 'downloading': return TaskStatus.downloading;
    case 'waiting': return TaskStatus.waiting;
    case 'paused': return TaskStatus.paused;
    case 'seeding': return TaskStatus.seeding;
    case 'completed': return TaskStatus.completed;
    case 'error': return TaskStatus.error;
    default: return null;
  }
}
```

### 3.4 修改 TasksTab 和 AllTasksTabPage

**文件:** `lib/features/home/presentation/pages/tasks_tab.dart`

```dart
class TasksTab extends StatelessWidget {
  final TaskStatus? initialStatus;

  const TasksTab({super.key, this.initialStatus});

  @override
  Widget build(BuildContext context) {
    return AllTasksTabPage(initialStatus: initialStatus);
  }
}
```

**文件:** `lib/features/home/presentation/pages/all_tasks_tab_page.dart`

```dart
class AllTasksTabPage extends StatefulWidget {
  final TaskStatus? initialStatus;

  const AllTasksTabPage({super.key, this.initialStatus});

  // ...
}

class _AllTasksTabPageState extends State<AllTasksTabPage> {
  TaskStatus? _activeStatus;

  @override
  void initState() {
    super.initState();
    _activeStatus = widget.initialStatus; // 设置初始筛选状态
    // ...
  }
}
```

### 3.5 处理状态重置

当用户手动切换到任务列表 tab（不是通过点击状态）时，应重置筛选状态为 null（显示全部）。

在 HomeTabContainer 中：

```dart
onTap: () {
  if (_currentIndex != 2) {
    _pendingTaskStatus = null; // 手动切换时重置
  }
  setState(() => _currentIndex = 2);
},
```

## 4. 数据流

```
用户点击 StatusTile
    ↓
NeoStatusMatrix.onStatusTap(TaskStatus)
    ↓
DataTab.onShowTasks(TaskStatus)
    ↓
HomeTabContainer._pendingTaskStatus = status
HomeTabContainer._currentIndex = 2
    ↓
TasksTab(initialStatus: _pendingTaskStatus)
    ↓
AllTasksTabPage._activeStatus = initialStatus
    ↓
NeoFilterStrip 显示对应选中状态
_filteredTasks 按状态筛选
```

## 5. 涉及文件

| 文件 | 修改内容 |
|------|----------|
| `lib/features/home/presentation/pages/home_tab_container.dart` | 修改 onShowTasks 类型，添加 _pendingTaskStatus |
| `lib/features/home/presentation/pages/data_tab.dart` | 修改 onShowTasks 类型，传递给 NeoStatusMatrix |
| `lib/features/home/presentation/widgets/neo_overview_widgets.dart` | NeoStatusMatrix 添加 onStatusTap，_StatusTile 添加 InkWell |
| `lib/features/home/presentation/pages/tasks_tab.dart` | 添加 initialStatus 参数 |
| `lib/features/home/presentation/pages/all_tasks_tab_page.dart` | 接收 initialStatus 并设置初始筛选 |

## 6. 视觉反馈

- InkWell 提供 Material Design 的 splash 效果
- borderRadius: 20 与 NeoSurface 一致
- cursor: pointer（Web 平台自动支持）

## 7. 边界情况

- 数量为 0 时仍然可点击，显示空列表
- 手动切换到任务列表 tab 时，筛选状态重置为"全部"
- TaskStatus.removed 和 TaskStatus.unknown 不在矩阵中显示
