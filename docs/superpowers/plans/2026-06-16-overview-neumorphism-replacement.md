# Overview Neumorphism Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 `design/v2/overview-neumorphism-ui-mockup.html` 替换首页总览页，并把首页公共壳、底部 tab、公共 FAB 抽成后续 tab 改造可复用的拟物化组件。

**Architecture:** `HomeTabContainer` 继续负责 tab 状态、下载器初始化、更新检查；新增 `NeoHomeShell` / `NeoHomeTabBar` 负责公共视觉壳层。`DataTab` 保留 `Consumer<DownloaderController>`、下拉刷新和现有数据来源，页面内容拆到 home feature 内的拟物化展示组件。

**Tech Stack:** Flutter 3.24.5, Material 3, Provider, go_router, flutter_test, existing `NeoThemeTokens` / `NeoCard` / `NeoSurface` primitives.

---

## File Structure

- Create: `lib/features/home/presentation/widgets/neo_home_shell.dart`
  - 首页公共壳：背景、`IndexedStack`、底部拟物化 tab、公共 FAB 显隐。
- Create: `lib/features/home/presentation/widgets/neo_overview_widgets.dart`
  - 总览页专用展示组件：品牌 header、运行概览面板、任务状态矩阵、下载器分布。
- Modify: `lib/features/home/presentation/pages/home_tab_container.dart`
  - 保留业务初始化和更新检查，替换为 `NeoHomeShell`，把 tab 切换回调传给 `DataTab`。
- Modify: `lib/features/home/presentation/pages/data_tab.dart`
  - 移除内部 `Scaffold` 和 FAB，改成只渲染总览内容；保留 `RefreshIndicator` 和数据读取。
- Modify: `test/widget/test_helpers.dart`
  - 给 `MockDownloaderController` 增加可注入 `globalStats` 的测试接口，并给测试路由补 `/add-task`。
- Modify: `test/widget/home_page_test.dart`
  - 更新首页壳回归测试，不再查找 Material `NavigationBar`。
- Create: `test/widget/home/neo_home_shell_test.dart`
  - 覆盖 `NeoHomeTabBar` 选择态、tab 回调、FAB 显隐和点击路由。
- Create: `test/widget/home/data_tab_neumorphism_test.dart`
  - 覆盖总览 header、任务状态矩阵、下载器分布、下拉刷新入口。

## Public Interfaces

新增首页 tab 配置对象：

```dart
@immutable
class NeoHomeTabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String semanticsLabel;
  final bool showFab;

  const NeoHomeTabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.semanticsLabel,
    this.showFab = false,
  });
}
```

新增公共壳：

```dart
class NeoHomeShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<NeoHomeTabItem> tabs;
  final List<Widget> children;
  final VoidCallback? onFabPressed;
  final String? fabTooltip;

  const NeoHomeShell({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.tabs,
    required this.children,
    this.onFabPressed,
    this.fabTooltip,
  });
}
```

`DataTab` 新构造参数：

```dart
class DataTab extends StatelessWidget {
  final VoidCallback? onShowDownloaders;
  final VoidCallback? onShowTasks;

  const DataTab({
    super.key,
    this.onShowDownloaders,
    this.onShowTasks,
  });
}
```

---

### Task 1: Test Home Shell Contract

**Files:**
- Create: `test/widget/home/neo_home_shell_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Create `test/widget/home/neo_home_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_home_shell.dart';

void main() {
  const tabs = [
    NeoHomeTabItem(
      label: '总览',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      semanticsLabel: '总览',
      showFab: true,
    ),
    NeoHomeTabItem(
      label: '下载器',
      icon: Icons.storage_outlined,
      selectedIcon: Icons.storage,
      semanticsLabel: '下载器',
    ),
  ];

  Widget buildSubject({
    int selectedIndex = 0,
    required ValueChanged<int> onTabSelected,
    VoidCallback? onFabPressed,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: NeoHomeShell(
        selectedIndex: selectedIndex,
        onTabSelected: onTabSelected,
        tabs: tabs,
        onFabPressed: onFabPressed,
        fabTooltip: '添加任务',
        children: const [
          Center(child: Text('Overview body')),
          Center(child: Text('Downloaders body')),
        ],
      ),
    );
  }

  testWidgets('renders custom neumorphic tab bar instead of Material NavigationBar', (tester) async {
    await tester.pumpWidget(buildSubject(onTabSelected: (_) {}));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NeoHomeTabBar), findsOneWidget);
    expect(find.text('总览'), findsOneWidget);
    expect(find.text('下载器'), findsOneWidget);
  });

  testWidgets('selecting a tab calls onTabSelected', (tester) async {
    int? selected;
    await tester.pumpWidget(buildSubject(onTabSelected: (index) => selected = index));

    await tester.tap(find.text('下载器'));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

  testWidgets('shows public FAB only when current tab config enables it', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildSubject(onTabSelected: (_) {}, onFabPressed: () => tapped = true),
    );

    expect(find.byTooltip('添加任务'), findsOneWidget);
    await tester.tap(find.byTooltip('添加任务'));
    expect(tapped, isTrue);

    await tester.pumpWidget(
      buildSubject(selectedIndex: 1, onTabSelected: (_) {}, onFabPressed: () {}),
    );
    expect(find.byTooltip('添加任务'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the new test to verify it fails**

Run:

```bash
flutter test test/widget/home/neo_home_shell_test.dart
```

Expected: FAIL because `neo_home_shell.dart`, `NeoHomeTabItem`, `NeoHomeShell`, and `NeoHomeTabBar` do not exist.

- [ ] **Step 3: Commit the failing test**

```bash
git add test/widget/home/neo_home_shell_test.dart
git commit -m "test: define neumorphic home shell contract"
```

---

### Task 2: Implement Reusable Home Shell

**Files:**
- Create: `lib/features/home/presentation/widgets/neo_home_shell.dart`
- Modify: `lib/features/home/presentation/pages/home_tab_container.dart`
- Modify: `test/widget/home_page_test.dart`

- [ ] **Step 1: Add the home shell widget file**

Create `lib/features/home/presentation/widgets/neo_home_shell.dart` with this structure and public API:

```dart
import 'package:flutter/material.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';

@immutable
class NeoHomeTabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String semanticsLabel;
  final bool showFab;

  const NeoHomeTabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.semanticsLabel,
    this.showFab = false,
  });
}

class NeoHomeShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<NeoHomeTabItem> tabs;
  final List<Widget> children;
  final VoidCallback? onFabPressed;
  final String? fabTooltip;

  const NeoHomeShell({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.tabs,
    required this.children,
    this.onFabPressed,
    this.fabTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final currentTab = tabs[selectedIndex];

    return Scaffold(
      backgroundColor: tokens.baseBackground,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.baseBackground,
              tokens.raisedSurface.withValues(alpha: tokens.isDark ? 0.72 : 0.92),
            ],
          ),
        ),
        child: IndexedStack(index: selectedIndex, children: children),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: currentTab.showFab && onFabPressed != null
          ? NeoHomeFab(onPressed: onFabPressed!, tooltip: fabTooltip)
          : null,
      bottomNavigationBar: NeoHomeTabBar(
        tabs: tabs,
        selectedIndex: selectedIndex,
        onSelected: onTabSelected,
      ),
    );
  }
}
```

Continue the same file with `NeoHomeTabBar`, `_NeoHomeTabButton`, and `NeoHomeFab`. Use these exact behaviours:

```dart
class NeoHomeTabBar extends StatelessWidget {
  final List<NeoHomeTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const NeoHomeTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.raisedSurface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: _raisedShadow(tokens),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _NeoHomeTabButton(
                    item: tabs[i],
                    selected: selectedIndex == i,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

The selected tab button must use inset shadows, unselected buttons must have no extra surface. `NeoHomeFab` must be a circular raised button using `tokens.primaryAccent`, white icon, `Icons.add_rounded`, `Semantics(button: true, label: tooltip ?? '添加任务')`, and `Tooltip(message: tooltip ?? '添加任务')`.

- [ ] **Step 2: Replace Material NavigationBar in HomeTabContainer**

Modify `lib/features/home/presentation/pages/home_tab_container.dart`:

```dart
import 'package:go_router/go_router.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_home_shell.dart';
```

Replace the current `Scaffold` return with:

```dart
return NeoHomeShell(
  selectedIndex: _currentIndex,
  onTabSelected: (value) => setState(() => _currentIndex = value),
  onFabPressed: () => context.push(AppConstants.addTaskRoute),
  fabTooltip: l10n.addTaskButton,
  tabs: [
    NeoHomeTabItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: l10n.data,
      semanticsLabel: l10n.data,
      showFab: true,
    ),
    NeoHomeTabItem(
      icon: Icons.storage_outlined,
      selectedIcon: Icons.storage_rounded,
      label: l10n.downloadersTab,
      semanticsLabel: l10n.downloadersTab,
    ),
    NeoHomeTabItem(
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt_rounded,
      label: l10n.taskList,
      semanticsLabel: l10n.taskList,
    ),
    NeoHomeTabItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      label: l10n.my,
      semanticsLabel: l10n.my,
    ),
  ],
  children: [
    DataTab(
      onShowDownloaders: () => setState(() => _currentIndex = 1),
      onShowTasks: () => setState(() => _currentIndex = 2),
    ),
    const ManagementTab(),
    const TasksTab(),
    const ProfileTab(),
  ],
);
```

- [ ] **Step 3: Update existing home page regression test**

In `test/widget/home_page_test.dart`, replace:

```dart
expect(find.byType(NavigationBar), findsOneWidget);
```

with:

```dart
expect(find.byType(NavigationBar), findsNothing);
expect(find.byTooltip(AppLocalizations.of(tester.element(find.byType(Scaffold).first))!.addTaskButton), findsOneWidget);
```

Add import:

```dart
import 'package:windwalker/features/home/presentation/widgets/neo_home_shell.dart';
```

Then also assert:

```dart
expect(find.byType(NeoHomeTabBar), findsOneWidget);
```

- [ ] **Step 4: Run shell tests**

Run:

```bash
flutter test test/widget/home/neo_home_shell_test.dart test/widget/home_page_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the shell implementation**

```bash
git add lib/features/home/presentation/widgets/neo_home_shell.dart lib/features/home/presentation/pages/home_tab_container.dart test/widget/home_page_test.dart
git commit -m "feat: add neumorphic home shell"
```

---

### Task 3: Test Overview Page Content

**Files:**
- Create: `test/widget/home/data_tab_neumorphism_test.dart`
- Modify: `test/widget/test_helpers.dart`

- [ ] **Step 1: Extend mock controller with injectable global stats**

Modify `MockDownloaderController` in `test/widget/test_helpers.dart`:

```dart
final Map<String, int> _testGlobalStats = {
  'downloading': 0,
  'waiting': 0,
  'paused': 0,
  'completed': 0,
  'error': 0,
  'seeding': 0,
  'totalSpeed': 0,
  'uploadSpeed': 0,
  'downloaderCount': 0,
  'onlineCount': 0,
};

set testGlobalStats(Map<String, int> stats) {
  _testGlobalStats
    ..clear()
    ..addAll(stats);
  notifyListeners();
}

@override
Map<String, int> get globalStats => Map.unmodifiable(_testGlobalStats);
```

Add `/add-task` to the test router routes in `createTestApp`:

```dart
GoRoute(
  path: AppConstants.addTaskRoute,
  name: 'addTask',
  builder: (context, state) => const AddTaskPage(),
),
```

- [ ] **Step 2: Write overview widget tests**

Create `test/widget/home/data_tab_neumorphism_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/add_task/presentation/pages/add_task_page.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_overview_widgets.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '/tmp/test_windwalker',
    );
    await GetStorage.init();
  });

  group('Neumorphic DataTab', () {
    late MockDownloaderController downloaderController;
    late TaskController taskController;

    setUp(() {
      downloaderController = MockDownloaderController();
      taskController = TaskController();
      downloaderController.testDownloaders = [
        createTestDownloader(
          id: 'aria',
          name: 'NAS Aria2',
          type: DownloaderType.aria2,
          status: DownloaderStatus.online,
          taskCount: 7,
          downloadSpeed: 1048576,
          uploadSpeed: 262144,
          taskStats: {'downloading': 3, 'completed': 4},
        ),
        createTestDownloader(
          id: 'qbit',
          name: 'SeedBox qBit',
          type: DownloaderType.qbittorrent,
          status: DownloaderStatus.error,
          taskCount: 2,
          downloadSpeed: 0,
          uploadSpeed: 131072,
        ),
      ];
      downloaderController.testGlobalStats = {
        'downloading': 3,
        'waiting': 2,
        'paused': 1,
        'seeding': 4,
        'completed': 9,
        'error': 1,
        'totalSpeed': 1048576,
        'uploadSpeed': 393216,
        'downloaderCount': 2,
        'onlineCount': 1,
      };
    });

    tearDown(() {
      taskController.stopAutoRefresh();
      taskController.dispose();
    });

    testWidgets('renders brand header, overview panel, status matrix and distribution', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byType(NeoOverviewHeader), findsOneWidget);
      expect(find.byType(NeoOverviewSummaryPanel), findsOneWidget);
      expect(find.byType(NeoStatusMatrix), findsOneWidget);
      expect(find.byType(NeoDownloaderDistribution), findsOneWidget);
      expect(find.text(l10n.data), findsWidgets);
      expect(find.text('WindWalker 控制台'), findsOneWidget);
      expect(find.text('NAS Aria2'), findsOneWidget);
      expect(find.text('SeedBox qBit'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      expect(find.text('9'), findsWidgets);
    });

    testWidgets('quick actions switch to downloaders and tasks tabs', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('下载器'));
      await tester.pumpAndSettle();
      expect(find.text('NAS Aria2'), findsWidgets);

      await tester.tap(find.text('查看任务'));
      await tester.pumpAndSettle();
      expect(find.text('任务列表'), findsWidgets);
    });

    testWidgets('public FAB opens add task route', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          downloaderController: downloaderController,
          taskController: taskController,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byTooltip('Add Task'));
      await tester.pumpAndSettle();

      expect(find.byType(AddTaskPage), findsOneWidget);
    });
  });
}
```

- [ ] **Step 3: Run the overview tests to verify they fail**

Run:

```bash
flutter test test/widget/home/data_tab_neumorphism_test.dart
```

Expected: FAIL because `neo_overview_widgets.dart` and the new `DataTab` layout do not exist yet.

- [ ] **Step 4: Commit the failing overview tests**

```bash
git add test/widget/test_helpers.dart test/widget/home/data_tab_neumorphism_test.dart
git commit -m "test: define neumorphic overview contract"
```

---

### Task 4: Implement Overview Widgets

**Files:**
- Create: `lib/features/home/presentation/widgets/neo_overview_widgets.dart`

- [ ] **Step 1: Add immutable view models and helpers**

Create `lib/features/home/presentation/widgets/neo_overview_widgets.dart` with imports:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/extensions/l10n_extensions.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';
```

Add these helpers:

```dart
String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 KB/s';
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var value = bytesPerSecond.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final fractionDigits = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}

int activeTaskCount(Map<String, int> stats) {
  return (stats['downloading'] ?? 0) +
      (stats['waiting'] ?? 0) +
      (stats['seeding'] ?? 0);
}

Color statusColor(DownloaderStatus status) {
  switch (status) {
    case DownloaderStatus.online:
      return AppColors.success;
    case DownloaderStatus.offline:
      return AppColors.textTertiaryLight;
    case DownloaderStatus.error:
      return AppColors.error;
  }
}
```

- [ ] **Step 2: Add brand header**

Add:

```dart
class NeoOverviewHeader extends StatelessWidget {
  final String title;
  final int onlineCount;
  final int totalCount;

  const NeoOverviewHeader({
    super.key,
    required this.title,
    required this.onlineCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: tokens.raisedSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: tokens.highlightColor.withValues(alpha: tokens.isDark ? 0.05 : 0.9),
                offset: const Offset(-5, -5),
                blurRadius: 12,
              ),
              BoxShadow(
                color: tokens.shadowColor.withValues(alpha: tokens.isDark ? 0.26 : 0.22),
                offset: const Offset(7, 7),
                blurRadius: 16,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset('assets/branding/app_icon_master.png'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('WindWalker 控制台', style: textTheme.bodyMedium),
              const SizedBox(height: 8),
              NeoBadge(
                label: onlineCount > 0 ? '$onlineCount/$totalCount 下载器在线' : '等待下载器连接',
                backgroundColor: onlineCount > 0 ? tokens.successTint : tokens.warningTint,
                foregroundColor: onlineCount > 0 ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Add overview summary panel and quick actions**

Add `NeoOverviewSummaryPanel` with constructor:

```dart
class NeoOverviewSummaryPanel extends StatelessWidget {
  final Map<String, int> stats;
  final List<Downloader> downloaders;
  final VoidCallback? onAddTask;
  final VoidCallback? onShowDownloaders;
  final VoidCallback? onShowTasks;

  const NeoOverviewSummaryPanel({
    super.key,
    required this.stats,
    required this.downloaders,
    this.onAddTask,
    this.onShowDownloaders,
    this.onShowTasks,
  });
}
```

Its build method must use:

```dart
final totalDownloadSpeed = downloaders.fold<int>(0, (sum, d) => sum + d.downloadSpeed);
final totalUploadSpeed = downloaders.fold<int>(0, (sum, d) => sum + d.uploadSpeed);
```

Render a `NeoSurface` containing:

```dart
_MetricPill(label: '总下载速度', value: formatSpeed(totalDownloadSpeed), icon: Icons.south_rounded);
_MetricPill(label: '活跃任务', value: '${activeTaskCount(stats)}', icon: Icons.bolt_rounded);
_MetricPill(label: '总上传速度', value: formatSpeed(totalUploadSpeed), icon: Icons.north_rounded);
```

Render quick action buttons with exact visible labels:

```dart
_QuickAction(label: '添加任务', icon: Icons.add_rounded, onTap: onAddTask);
_QuickAction(label: '下载器', icon: Icons.storage_rounded, onTap: onShowDownloaders);
_QuickAction(label: '查看任务', icon: Icons.task_alt_rounded, onTap: onShowTasks);
```

- [ ] **Step 4: Add task status matrix**

Add `NeoStatusMatrix`:

```dart
class NeoStatusMatrix extends StatelessWidget {
  final Map<String, int> stats;

  const NeoStatusMatrix({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      _StatusItem(Icons.arrow_downward_rounded, l10n.downloading, stats['downloading'] ?? 0, AppColors.primary),
      _StatusItem(Icons.schedule_rounded, l10n.waiting, stats['waiting'] ?? 0, AppColors.warning),
      _StatusItem(Icons.pause_rounded, l10n.paused, stats['paused'] ?? 0, AppColors.textTertiaryLight),
      _StatusItem(Icons.upload_rounded, l10n.seeding, stats['seeding'] ?? 0, AppColors.success),
      _StatusItem(Icons.task_alt_rounded, l10n.completed, stats['completed'] ?? 0, AppColors.success),
      _StatusItem(Icons.error_outline_rounded, l10n.error, stats['error'] ?? 0, AppColors.error),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: [for (final item in items) _StatusTile(item: item)],
    );
  }
}
```

- [ ] **Step 5: Add downloader distribution with ring chart and rows**

Add `NeoDownloaderDistribution`:

```dart
class NeoDownloaderDistribution extends StatelessWidget {
  final List<Downloader> downloaders;

  const NeoDownloaderDistribution({super.key, required this.downloaders});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (downloaders.isEmpty) {
      return NeoSurface(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(l10n.noDownloadersYet),
        ),
      );
    }

    return NeoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.downloaderDistribution, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(width: 104, height: 104, child: CustomPaint(painter: _DownloaderRingPainter(downloaders))),
              const SizedBox(width: 16),
              Expanded(child: _DownloaderTypeSummary(downloaders: downloaders)),
            ],
          ),
          const SizedBox(height: 16),
          for (final downloader in downloaders) _DownloaderDistributionRow(downloader: downloader),
        ],
      ),
    );
  }
}
```

`_DownloaderDistributionRow` must navigate with:

```dart
context.push(
  '${AppConstants.tasksRoute}?id=${downloader.id}&type=${downloader.type.name}',
);
```

- [ ] **Step 6: Run focused analyzer on the new file**

Run:

```bash
dart format lib/features/home/presentation/widgets/neo_overview_widgets.dart
flutter analyze
```

Expected: analyzer does not report errors introduced by the new file.

- [ ] **Step 7: Commit overview widgets**

```bash
git add lib/features/home/presentation/widgets/neo_overview_widgets.dart
git commit -m "feat: add neumorphic overview widgets"
```

---

### Task 5: Replace DataTab Layout

**Files:**
- Modify: `lib/features/home/presentation/pages/data_tab.dart`

- [ ] **Step 1: Replace DataTab scaffold with scrollable content**

Change `DataTab` constructor to:

```dart
class DataTab extends StatelessWidget {
  final VoidCallback? onShowDownloaders;
  final VoidCallback? onShowTasks;

  const DataTab({
    super.key,
    this.onShowDownloaders,
    this.onShowTasks,
  });
}
```

Inside `build`, remove the nested `Scaffold`, `floatingActionButtonLocation`, and `floatingActionButton`. Keep:

```dart
return Consumer<DownloaderController>(
  builder: (context, controller, _) {
    final stats = controller.globalStats;
    final downloaders = controller.downloaders;
    final onlineCount = downloaders
        .where((downloader) => downloader.status == DownloaderStatus.online)
        .length;

    return RefreshIndicator(
      edgeOffset: 16,
      displacement: 28,
      onRefresh: () async {
        await controller.refreshAllStatus();
        await controller.refreshGlobalStats();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: ResponsiveContainer(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveLayout.getPadding(context).left,
                  AppSpacing.lg,
                  ResponsiveLayout.getPadding(context).right,
                  AppSpacing.md,
                ),
                child: NeoOverviewHeader(
                  title: l10n.data,
                  onlineCount: onlineCount,
                  totalCount: downloaders.length,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ResponsiveContainer(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.getPadding(context).left,
              ),
              child: NeoOverviewSummaryPanel(
                stats: stats,
                downloaders: downloaders,
                onAddTask: () => context.push(AppConstants.addTaskRoute),
                onShowDownloaders: onShowDownloaders,
                onShowTasks: onShowTasks,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ResponsiveContainer(
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.getPadding(context).left,
                AppSpacing.xl,
                ResponsiveLayout.getPadding(context).right,
                0,
              ),
              child: NeoSection(
                title: l10n.taskStatusOverview,
                child: NeoStatusMatrix(stats: stats),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ResponsiveContainer(
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.getPadding(context).left,
                AppSpacing.xl,
                ResponsiveLayout.getPadding(context).right,
                120,
              ),
              child: NeoDownloaderDistribution(downloaders: downloaders),
            ),
          ),
        ],
      ),
    );
  },
);
```

Add imports:

```dart
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_overview_widgets.dart';
```

Remove private classes that are no longer used: `_SectionTitle`, `_OverviewHeader`, `_OverviewHeaderPainter`, `_StatCard`, `_DownloaderDistributionCard`, `_DownloaderDistributionRow`, `_SurfaceCard`.

- [ ] **Step 2: Run the overview tests**

Run:

```bash
flutter test test/widget/home/data_tab_neumorphism_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run all affected widget tests**

Run:

```bash
flutter test test/widget/home_page_test.dart test/widget/home/neo_home_shell_test.dart test/widget/home/data_tab_neumorphism_test.dart test/widget/home_update_prompt_test.dart
```

Expected: PASS. `home_update_prompt_test.dart` verifies the update prompt remains unaffected by shell extraction.

- [ ] **Step 4: Commit DataTab replacement**

```bash
git add lib/features/home/presentation/pages/data_tab.dart test/widget/home/data_tab_neumorphism_test.dart test/widget/test_helpers.dart
git commit -m "feat: replace overview with neumorphic layout"
```

---

### Task 6: Final Verification and Polish

**Files:**
- Modify as needed: files changed by Tasks 1-5

- [ ] **Step 1: Format all changed Dart files**

Run:

```bash
dart format lib/features/home/presentation/pages/home_tab_container.dart lib/features/home/presentation/pages/data_tab.dart lib/features/home/presentation/widgets/neo_home_shell.dart lib/features/home/presentation/widgets/neo_overview_widgets.dart test/widget/home_page_test.dart test/widget/home/neo_home_shell_test.dart test/widget/home/data_tab_neumorphism_test.dart test/widget/test_helpers.dart
```

Expected: formatter exits with code 0.

- [ ] **Step 2: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Run focused tests**

Run:

```bash
flutter test test/widget/home_page_test.dart test/widget/home/neo_home_shell_test.dart test/widget/home/data_tab_neumorphism_test.dart test/widget/home_update_prompt_test.dart test/widget/theme/neo_components_test.dart test/widget/theme/neumorphism_theme_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run broad widget smoke tests**

Run:

```bash
flutter test test/widget
```

Expected: PASS. If unrelated pre-existing failures appear, record the failing test names and continue only after confirming they are unrelated to the changed files.

- [ ] **Step 5: Manual browser/device check**

Run the app with the existing local workflow, then verify:

```text
1. 首页默认进入“总览”。
2. 左上角显示 assets/branding/app_icon_master.png。
3. 页面没有右上角刷新按钮。
4. 下拉刷新仍能触发刷新动画。
5. 底部 tab 是拟物化样式，不是 Material NavigationBar。
6. 总览 tab 显示公共添加任务 FAB。
7. 切到下载器、任务列表、我的后，公共 FAB 隐藏。
8. “下载器”和“查看任务”快捷入口能切换对应 tab。
9. 下载器分布面板包含环形占比图、类型摘要和下载器列表。
10. 浅色和深色主题下文字对比度可读，凸起/内凹层次可见。
```

- [ ] **Step 6: Final commit**

If Task 6 introduced any polish changes:

```bash
git add lib/features/home/presentation/pages/home_tab_container.dart lib/features/home/presentation/pages/data_tab.dart lib/features/home/presentation/widgets/neo_home_shell.dart lib/features/home/presentation/widgets/neo_overview_widgets.dart test/widget/home_page_test.dart test/widget/home/neo_home_shell_test.dart test/widget/home/data_tab_neumorphism_test.dart test/widget/test_helpers.dart
git commit -m "test: verify neumorphic overview replacement"
```

If Task 6 only ran verification and no files changed, do not create an empty commit.

---

## Self-Review

**Spec coverage:**  
方案 B 的范围已覆盖：`HomeTabContainer` 公共壳、`DataTab` 总览内容、底部拟物化 tab、公共 FAB、真实应用图标、取消显式刷新按钮、保留下拉刷新、下载器分布 UI、后续 tab 可复用组件边界。

**Placeholder scan:**  
计划没有使用占位式待办语句。每个会改代码的步骤都给出了文件路径和关键代码。下载器任务跳转已核对 `lib/core/router/app_router.dart`，继续使用现有 `/tasks?id=<downloaderId>&type=<typeName>` 语义。

**Type consistency:**  
`NeoHomeTabItem`、`NeoHomeShell`、`NeoHomeTabBar`、`NeoOverviewHeader`、`NeoOverviewSummaryPanel`、`NeoStatusMatrix`、`NeoDownloaderDistribution` 在测试和实现步骤中保持同名同参。`DataTab` 的 `onShowDownloaders` / `onShowTasks` 由 `HomeTabContainer` 注入，避免 `DataTab` 直接管理 tab index。
