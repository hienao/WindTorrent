# WindWalker Neumorphism UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 WindWalker 落地一套覆盖浅色与深色主题的拟物化 UI 系统，并按页面级重构核心页面与共享组件。

**Architecture:** 以 `ThemeData + 统一设计 token + Neo 基础组件层 + 页面级重绘` 为主线推进。先补主题模式与 token 基础，再建立共享组件与风格说明文件，随后分批重构任务列表、添加任务、设置与下载器配置等核心页面，最后统一收口剩余页面和验证。

**Tech Stack:** Flutter 3.24、Dart、Provider、go_router、Material 3、flutter_test、GetStorage

---

## 文件结构与职责

### 计划新增文件

- `lib/core/theme/neo_theme_extension.dart`
  - 承载浅色/深色 Neumorphism 主题 token，例如背景层级、表面层级、高光、阴影、状态底色、控件尺寸。
- `lib/core/theme/neo_components.dart`
  - 承载 `NeoSurface`、`NeoCard`、`NeoButton`、`NeoInputShell`、`NeoChip`、`NeoSection`、`NeoActionBar` 等共享 UI 原语。
- `docs/design/neumorphism-style-guide.md`
  - 后续 UI 生成使用的统一风格描述文件。
- `test/widget/theme/neumorphism_theme_test.dart`
  - 主题模式与 token 可访问性的测试。
- `test/widget/theme/neo_components_test.dart`
  - 核心 Neo 组件在浅/深色模式下的结构与关键视觉参数测试。

### 计划修改文件

- `lib/core/theme/app_theme.dart`
  - 重建浅色/深色主题工厂，挂接 `ThemeExtension` 与共享组件主题配置。
- `lib/app.dart`
  - 为 `MaterialApp.router` 同时接入 `theme`、`darkTheme`、`themeMode`。
- `test/widget/test_helpers.dart`
  - 为测试环境同步接入新主题与主题模式。
- `lib/features/settings/presentation/controllers/settings_controller.dart`
  - 增加主题模式持久化读写。
- `lib/features/settings/presentation/pages/settings_page.dart`
  - 增加主题模式设置入口，并重构为拟物化设置页面。
- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_ja.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_zh.dart`
- `lib/l10n/app_localizations_ja.dart`
  - 增加主题模式相关文案。
- `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
  - 重构全部任务页。
- `lib/features/tasks/presentation/pages/tasks_page.dart`
  - 重构单下载器任务页。
- `lib/features/add_task/presentation/pages/add_task_page.dart`
  - 重构添加任务页。
- `lib/features/downloaders/presentation/pages/downloader_config_page.dart`
  - 重构下载器配置页。
- `lib/features/downloaders/presentation/pages/downloader_editor_page.dart`
  - 重构下载器编辑页。
- `lib/features/settings/presentation/pages/about_page.dart`
  - 对齐新视觉语言。
- `lib/features/tasks/presentation/widgets/delete_task_dialog.dart`
  - 改为统一 NeoDialog 风格。
- `lib/features/tasks/presentation/pages/task_detail_page.dart`
  - 清理明显风格漂移。
- `lib/features/auth/presentation/pages/login_page.dart`
  - 清理明显风格漂移。
- `lib/features/startup/presentation/pages/startup_page.dart`
  - 清理明显风格漂移。
- `test/widget/settings_page_test.dart`
- `test/widget/add_task_page_test.dart`
- `test/widget/tasks_page_shared_state_test.dart`
- `test/widget/all_tasks_tab_shared_state_test.dart`
- `test/widget/about_page_update_test.dart`
  - 按照新结构与新文案更新测试。

### 不建议在本次改造中做的事

- 不拆 Provider 架构。
- 不改 Router。
- 不混入业务逻辑重构。
- 不引入新的状态管理库或第三方 UI 皮肤库。

## Task 1: 建立主题模式与拟物化 Token 基础

**Files:**
- Create: `lib/core/theme/neo_theme_extension.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Modify: `test/widget/test_helpers.dart`
- Modify: `lib/features/settings/presentation/controllers/settings_controller.dart`
- Modify: `lib/app.dart`
- Test: `test/widget/theme/neumorphism_theme_test.dart`

- [ ] **Step 1: 先写失败测试，约束主题模式和 ThemeExtension 暴露**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/app.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await GetStorage.init();
  });

  test('AppThemeMode.fromCode resolves persisted values', () {
    expect(AppThemeMode.fromCode('system'), AppThemeMode.system);
    expect(AppThemeMode.fromCode('light'), AppThemeMode.light);
    expect(AppThemeMode.fromCode('dark'), AppThemeMode.dark);
  });

  testWidgets('WindWalkerApp exposes NeoThemeTokens in light theme', (tester) async {
    await tester.pumpWidget(const WindWalkerApp());
    final BuildContext context = tester.element(find.byType(MaterialApp));
    final extension = Theme.of(context).extension<NeoThemeTokens>();

    expect(extension, isNotNull);
    expect(extension!.isDark, isFalse);
  });
}
```

- [ ] **Step 2: 运行测试，确认当前实现确实失败**

Run: `flutter test test/widget/theme/neumorphism_theme_test.dart -r expanded`

Expected: FAIL，提示 `AppThemeMode` 或 `NeoThemeTokens` 未定义，且 `MaterialApp.router` 未提供 `darkTheme/themeMode`。

- [ ] **Step 3: 新增 ThemeExtension，承载拟物化 token**

```dart
import 'package:flutter/material.dart';

@immutable
class NeoThemeTokens extends ThemeExtension<NeoThemeTokens> {
  final bool isDark;
  final Color baseBackground;
  final Color raisedSurface;
  final Color recessedSurface;
  final Color highlightColor;
  final Color shadowColor;
  final Color primaryAccent;
  final Color successTint;
  final Color warningTint;
  final Color errorTint;

  const NeoThemeTokens({
    required this.isDark,
    required this.baseBackground,
    required this.raisedSurface,
    required this.recessedSurface,
    required this.highlightColor,
    required this.shadowColor,
    required this.primaryAccent,
    required this.successTint,
    required this.warningTint,
    required this.errorTint,
  });

  @override
  NeoThemeTokens copyWith({
    bool? isDark,
    Color? baseBackground,
    Color? raisedSurface,
    Color? recessedSurface,
    Color? highlightColor,
    Color? shadowColor,
    Color? primaryAccent,
    Color? successTint,
    Color? warningTint,
    Color? errorTint,
  }) {
    return NeoThemeTokens(
      isDark: isDark ?? this.isDark,
      baseBackground: baseBackground ?? this.baseBackground,
      raisedSurface: raisedSurface ?? this.raisedSurface,
      recessedSurface: recessedSurface ?? this.recessedSurface,
      highlightColor: highlightColor ?? this.highlightColor,
      shadowColor: shadowColor ?? this.shadowColor,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      successTint: successTint ?? this.successTint,
      warningTint: warningTint ?? this.warningTint,
      errorTint: errorTint ?? this.errorTint,
    );
  }

  @override
  NeoThemeTokens lerp(ThemeExtension<NeoThemeTokens>? other, double t) {
    if (other is! NeoThemeTokens) return this;
    return NeoThemeTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      baseBackground: Color.lerp(baseBackground, other.baseBackground, t)!,
      raisedSurface: Color.lerp(raisedSurface, other.raisedSurface, t)!,
      recessedSurface: Color.lerp(recessedSurface, other.recessedSurface, t)!,
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      warningTint: Color.lerp(warningTint, other.warningTint, t)!,
      errorTint: Color.lerp(errorTint, other.errorTint, t)!,
    );
  }
}
```

- [ ] **Step 4: 在设置控制器与 App 根部接入主题模式**

```dart
enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  final String code;
  const AppThemeMode(this.code);

  static AppThemeMode fromCode(String? code) {
    return AppThemeMode.values.where((e) => e.code == code).firstOrNull
        ?? AppThemeMode.system;
  }
}

ThemeMode get effectiveThemeMode {
  switch (_appThemeMode) {
    case AppThemeMode.system:
      return ThemeMode.system;
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
  }
}
```

```dart
return MaterialApp.router(
  title: AppConstants.appName,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: settings.effectiveThemeMode,
  routerConfig: appRouter,
  debugShowCheckedModeBanner: false,
);
```

- [ ] **Step 5: 在 `app_theme.dart` 中重建浅色/深色主题工厂**

```dart
static ThemeData get lightTheme {
  const tokens = NeoThemeTokens(
    isDark: false,
    baseBackground: Color(0xFFE9EEF5),
    raisedSurface: Color(0xFFF1F4F8),
    recessedSurface: Color(0xFFE3E8F0),
    highlightColor: Color(0xFFFFFFFF),
    shadowColor: Color(0xFFA8B5C7),
    primaryAccent: Color(0xFF2A7FFF),
    successTint: Color(0xFFDBF5EE),
    warningTint: Color(0xFFFFF1D6),
    errorTint: Color(0xFFFDE3E5),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: tokens.baseBackground,
    extensions: const [tokens],
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.primaryAccent,
      brightness: Brightness.light,
    ),
  );
}
```

```dart
child: MaterialApp.router(
  routerConfig: router,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.light,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
)
```

- [ ] **Step 6: 重新运行测试，确认主题基础通过**

Run: `flutter test test/widget/theme/neumorphism_theme_test.dart -r expanded`

Expected: PASS，能读取 `NeoThemeTokens`，并且 `AppThemeMode` 正常解析。

- [ ] **Step 7: 提交主题基础改造**

```bash
git add lib/core/theme/neo_theme_extension.dart lib/core/theme/app_theme.dart lib/features/settings/presentation/controllers/settings_controller.dart lib/app.dart test/widget/test_helpers.dart test/widget/theme/neumorphism_theme_test.dart
git commit -m "feat: add neumorphism theme foundation"
```

## Task 2: 建立共享 Neo 组件与风格描述文件

**Files:**
- Create: `lib/core/theme/neo_components.dart`
- Create: `docs/design/neumorphism-style-guide.md`
- Test: `test/widget/theme/neo_components_test.dart`
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: 写失败测试，约束核心组件结构**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';

void main() {
  testWidgets('NeoCard renders child and decoration shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: NeoCard(
            child: Text('card-body'),
          ),
        ),
      ),
    );

    expect(find.text('card-body'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });
}
```

- [ ] **Step 2: 运行测试确认组件尚不存在**

Run: `flutter test test/widget/theme/neo_components_test.dart -r expanded`

Expected: FAIL，提示 `NeoCard` 或 `neo_components.dart` 不存在。

- [ ] **Step 3: 创建共享组件文件，先落基础原语**

```dart
class NeoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const NeoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.raisedSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tokens.highlightColor.withValues(alpha: tokens.isDark ? 0.05 : 0.95),
            offset: const Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: tokens.shadowColor.withValues(alpha: tokens.isDark ? 0.24 : 0.30),
            offset: const Offset(8, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: child,
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
```

- [ ] **Step 4: 补 `NeoSurface`、`NeoButton`、`NeoInputShell`、`NeoSection` 的最小实现**

```dart
class NeoInputShell extends StatelessWidget {
  final Widget child;

  const NeoInputShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.recessedSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowColor.withValues(alpha: tokens.isDark ? 0.26 : 0.18),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: tokens.highlightColor.withValues(alpha: tokens.isDark ? 0.04 : 0.78),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: tokens.highlightColor.withValues(alpha: tokens.isDark ? 0.08 : 0.65),
          ),
        ),
        child: child,
      ),
    );
  }
}
```

```dart
class NeoBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const NeoBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w600)),
    );
  }
}

class NeoProgress extends StatelessWidget {
  final double value;

  const NeoProgress({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(value: value, minHeight: 10),
    );
  }
}

class NeoActionBar extends StatelessWidget {
  final Widget child;

  const NeoActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: NeoCard(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

class NeoButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget label;
  final bool isPrimary;

  const NeoButton.primary({
    super.key,
    required this.onPressed,
    required this.label,
  }) : isPrimary = true;

  const NeoButton.secondary({
    super.key,
    required this.onPressed,
    required this.label,
  }) : isPrimary = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isPrimary
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          foregroundColor: isPrimary
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
        ),
        child: label,
      ),
    );
  }
}
```

- [ ] **Step 5: 写风格说明文件，固定后续生成规则**

```md
# WindWalker Neumorphism Style Guide

## 风格摘要
- 功能平衡型拟物化
- 低饱和雾灰蓝 / 深石墨双主题
- 外凸卡片、内凹输入、强语义状态

## 浅色调色板
- 背景：`#E9EEF5`
- 表面：`#F1F4F8`
- 内凹面：`#E3E8F0`
- 主色：`#2A7FFF`

## 深色调色板
- 背景：`#111827`
- 表面：`#1A2332`
- 内凹面：`#0D1522`
- 主色：`#5B9CFF`
```

- [ ] **Step 6: 运行组件测试，确认基础原语通过**

Run: `flutter test test/widget/theme/neo_components_test.dart -r expanded`

Expected: PASS，`NeoCard` 可渲染，组件结构可被查找。

- [ ] **Step 7: 提交共享组件与风格文档**

```bash
git add lib/core/theme/neo_components.dart docs/design/neumorphism-style-guide.md test/widget/theme/neo_components_test.dart lib/core/theme/app_theme.dart
git commit -m "feat: add shared neumorphism components"
```

## Task 3: 重构任务列表相关页面

**Files:**
- Modify: `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
- Modify: `lib/features/tasks/presentation/pages/tasks_page.dart`
- Modify: `lib/features/tasks/presentation/pages/task_detail_page.dart`
- Modify: `lib/features/tasks/presentation/widgets/delete_task_dialog.dart`
- Test: `test/widget/all_tasks_tab_shared_state_test.dart`
- Test: `test/widget/tasks_page_shared_state_test.dart`

- [ ] **Step 1: 先补失败测试，锁定新结构中的关键元素**

```dart
testWidgets('AllTasksTabPage shows recessed search and raised task card', (tester) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [createTestDownloader()];

  await tester.pumpWidget(
    createTestApp(downloaderController: downloaderController),
  );
  await tester.pump();

  expect(find.byIcon(Icons.search), findsOneWidget);
  expect(find.byType(Scrollable), findsWidgets);
});
```

```dart
testWidgets('TasksPage keeps shared task data after UI refactor', (tester) async {
  taskController.debugSetTasksForTest('test-1', [
    DownloadTask(
      id: 'task-1',
      gid: 'task-1',
      name: 'Refactor Download',
      status: TaskStatus.downloading,
      downloaderId: 'test-1',
    ),
  ]);

  await tester.pumpWidget(createTestApp(
    downloaderController: downloaderController,
    taskController: taskController,
  ));
  await tester.pump();

  expect(find.text('Refactor Download'), findsOneWidget);
});
```

- [ ] **Step 2: 运行任务列表相关测试，确认在改造前会失败或需更新**

Run: `flutter test test/widget/all_tasks_tab_shared_state_test.dart test/widget/tasks_page_shared_state_test.dart -r expanded`

Expected: 至少有一项 FAIL，提示结构、文案或查找方式与新设计不匹配。

- [ ] **Step 3: 用 Neo 组件重写全部任务页**

```dart
return Scaffold(
  backgroundColor: tokens.baseBackground,
  appBar: AppBar(
    title: Text(l10n.taskList),
    centerTitle: true,
  ),
  body: Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: NeoInputShell(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchTasks,
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: ResponsiveLayout.getPadding(context),
          itemBuilder: (context, index) => NeoCard(
            child: _AllTaskCardBody(task: tasks[index]),
          ),
        ),
      ),
    ],
  ),
);
```

- [ ] **Step 4: 用相同视觉骨架重写单下载器任务页和删除弹窗**

```dart
class _TaskTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NeoCard(
      onTap: () => context.push(
        '/tasks/detail/${task.id}?downloaderId=$downloaderId&taskName=${Uri.encodeComponent(task.name)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          NeoProgress(value: task.progress.clamp(0, 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              NeoBadge(
                label: task.status.localizedLabel(context),
                backgroundColor: AppColors.warning.withValues(alpha: 0.16),
                foregroundColor: AppColors.warning,
              ),
              const Spacer(),
              Text('${task.downloadSpeed} B/s'),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 重写详情页中明显旧风格区域，避免风格断层**

```dart
body: ListView(
  padding: ResponsiveLayout.getPadding(context),
  children: [
    NeoSection(
      title: taskName,
      subtitle: downloaderName,
      child: Column(
        children: [
          NeoProgress(value: task.progress.clamp(0, 1)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(task.formattedSpeed)),
              Expanded(child: Text(task.formattedUploadSpeed)),
            ],
          ),
        ],
      ),
    ),
  ],
)
```

- [ ] **Step 6: 重新运行任务列表测试**

Run: `flutter test test/widget/all_tasks_tab_shared_state_test.dart test/widget/tasks_page_shared_state_test.dart -r expanded`

Expected: PASS，任务共享状态仍正确，页面结构已切换但数据行为未回退。

- [ ] **Step 7: 提交任务页面重构**

```bash
git add lib/features/home/presentation/pages/all_tasks_tab_page.dart lib/features/tasks/presentation/pages/tasks_page.dart lib/features/tasks/presentation/pages/task_detail_page.dart lib/features/tasks/presentation/widgets/delete_task_dialog.dart test/widget/all_tasks_tab_shared_state_test.dart test/widget/tasks_page_shared_state_test.dart
git commit -m "feat: redesign task pages with neumorphism"
```

## Task 4: 重构添加任务页

**Files:**
- Modify: `lib/features/add_task/presentation/pages/add_task_page.dart`
- Test: `test/widget/add_task_page_test.dart`

- [ ] **Step 1: 先写失败测试，约束新页面骨架不破坏现有交互**

```dart
testWidgets('AddTaskPage keeps torrent picker and start action after redesign', (tester) async {
  await tester.pumpWidget(createAddTaskTestApp(
    downloaderController: controller,
  ));
  await tester.pumpAndSettle();

  expect(find.text('选择 torrent 文件'), findsOneWidget);
  expect(find.text('开始下载'), findsOneWidget);
});
```

- [ ] **Step 2: 运行现有添加任务测试，确认改造前基线稳定**

Run: `flutter test test/widget/add_task_page_test.dart -r expanded`

Expected: PASS，先拿到当前行为基线。

- [ ] **Step 3: 将页面改造为分段式拟物表单**

```dart
return Scaffold(
  backgroundColor: tokens.baseBackground,
  appBar: AppBar(title: Text(l10n.addTask)),
  body: Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          children: [
            NeoSection(
              title: l10n.selectDownloaderStep,
              subtitle: l10n.selectDownloaderDesc,
              child: _downloaderGrid(downloaders),
            ),
            const SizedBox(height: 16),
            NeoSection(
              title: l10n.downloadLinkStep,
              subtitle: l10n.downloadLinkDesc,
              child: Column(
                children: [
                  NeoInputShell(child: _urlInput(l10n)),
                  const SizedBox(height: 12),
                  NeoButton.secondary(
                    onPressed: _pickTorrentFile,
                    label: Text(l10n.selectTorrentFile),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      NeoActionBar(
        child: NeoButton.primary(
          onPressed: _submitting ? null : _submit,
          label: Text(l10n.startDownload),
        ),
      ),
    ],
  ),
);
```

- [ ] **Step 4: 保留 torrent 文件选择、移除、提交行为，不改业务逻辑**

```dart
if (_torrentFileName != null) ...[
  const SizedBox(height: 8),
  NeoCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        const Icon(Icons.description_outlined),
        const SizedBox(width: 8),
        Expanded(
          child: Text(l10n.selectedTorrentFile(_torrentFileName!)),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _torrentBytes = null;
              _torrentFileName = null;
            });
          },
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  ),
]
```

- [ ] **Step 5: 重新运行添加任务测试**

Run: `flutter test test/widget/add_task_page_test.dart -r expanded`

Expected: PASS，torrent 选择、移除、提交行为都保持正常。

- [ ] **Step 6: 提交添加任务页改造**

```bash
git add lib/features/add_task/presentation/pages/add_task_page.dart test/widget/add_task_page_test.dart
git commit -m "feat: redesign add task page"
```

## Task 5: 重构设置页、下载器配置页与编辑页

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `lib/features/downloaders/presentation/pages/downloader_config_page.dart`
- Modify: `lib/features/downloaders/presentation/pages/downloader_editor_page.dart`
- Modify: `lib/features/settings/presentation/pages/about_page.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_ja.arb`
- Modify: `lib/l10n/app_localizations.dart`
- Modify: `lib/l10n/app_localizations_en.dart`
- Modify: `lib/l10n/app_localizations_zh.dart`
- Modify: `lib/l10n/app_localizations_ja.dart`
- Test: `test/widget/settings_page_test.dart`
- Test: `test/widget/downloader_editor_gate_test.dart`
- Test: `test/widget/about_page_update_test.dart`

- [ ] **Step 1: 先补失败测试，锁定主题模式入口与页面关键结构**

```dart
testWidgets('SettingsPage exposes theme mode picker', (tester) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [createTestDownloader()];

  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      initialLocation: '/settings',
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
});
```

```dart
testWidgets('AboutPage keeps update card after redesign', (tester) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [createTestDownloader()];

  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      initialLocation: '/about',
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Check for Updates'), findsOneWidget);
});
```

- [ ] **Step 2: 运行相关测试，确认新入口尚未实现**

Run: `flutter test test/widget/settings_page_test.dart test/widget/downloader_editor_gate_test.dart test/widget/about_page_update_test.dart -r expanded`

Expected: 至少一项 FAIL，提示新入口或新结构不存在。

- [ ] **Step 3: 在设置页增加主题模式选择，并改为 NeoSection + NeoCard 结构**

```dart
String _themeModeLabel(BuildContext context, AppThemeMode mode) {
  final l10n = AppLocalizations.of(context)!;
  switch (mode) {
    case AppThemeMode.system:
      return l10n.themeModeSystem;
    case AppThemeMode.light:
      return l10n.themeModeLight;
    case AppThemeMode.dark:
      return l10n.themeModeDark;
  }
}

void _showThemeModePicker(BuildContext context, SettingsController settings) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: AppThemeMode.values.map((mode) {
          return RadioListTile<AppThemeMode>(
            value: mode,
            groupValue: settings.appThemeMode,
            title: Text(_themeModeLabel(ctx, mode)),
            onChanged: (value) {
              if (value == null) return;
              settings.setAppThemeMode(value);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    ),
  );
}
```

```dart
NeoSection(
  title: l10n.generalSettings,
  child: Column(
    children: [
      ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: Text(l10n.themeMode),
        subtitle: Text(_themeModeLabel(context, settings.appThemeMode)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showThemeModePicker(context, settings),
      ),
      ListTile(
        leading: const Icon(Icons.language),
        title: Text(l10n.language),
        subtitle: Text(_localeLabel(context, settings.appLocale)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showLanguagePicker(context, settings),
      ),
    ],
  ),
)
```

- [ ] **Step 4: 用拟物化表单重写下载器配置页和编辑页**

```dart
return Form(
  key: _formKey,
  child: ListView(
    padding: ResponsiveLayout.getPadding(context),
    children: [
      NeoSection(
        title: l10n.downloaderServiceSettings(downloader?.name ?? l10n.downloader),
        child: Column(
          children: [
            NeoCard(
              child: Row(
                children: [
                  const Icon(Icons.storage_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${downloader?.host ?? '--'}:${downloader?.port ?? '--'}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...?_descriptor?.sections.map(_buildSection),
          ],
        ),
      ),
      const SizedBox(height: 16),
      NeoActionBar(
        child: NeoButton.primary(
          onPressed: _saving ? null : _save,
          label: Text(l10n.saveConfig),
        ),
      ),
    ],
  ),
);
```

```json
{
  "themeMode": "Theme mode",
  "themeModeSystem": "Follow system",
  "themeModeLight": "Light",
  "themeModeDark": "Dark"
}
```

- [ ] **Step 5: 运行本地化生成，确保新增主题文案可用**

Run: `flutter gen-l10n`

Expected: PASS，`lib/l10n/app_localizations*.dart` 重新生成，包含 `themeMode*` 访问器。

- [ ] **Step 6: 将关于页对齐为同一风格，但保留版本更新信息逻辑**

```dart
body: ListView(
  padding: ResponsiveLayout.getPadding(context),
  children: [
    NeoSection(
      title: l10n.about,
      subtitle: AppConstants.appName,
      child: Column(
        children: [
          _buildVersionCard(context),
          const SizedBox(height: 16),
          _buildSupportLinks(context),
        ],
      ),
    ),
  ],
)
```

- [ ] **Step 7: 重新运行设置与下载器页面测试**

Run: `flutter test test/widget/settings_page_test.dart test/widget/downloader_editor_gate_test.dart test/widget/about_page_update_test.dart -r expanded`

Expected: PASS，主题入口存在，更新信息和编辑页行为仍然保留。

- [ ] **Step 8: 提交设置与下载器页面改造**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart lib/features/downloaders/presentation/pages/downloader_config_page.dart lib/features/downloaders/presentation/pages/downloader_editor_page.dart lib/features/settings/presentation/pages/about_page.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart test/widget/settings_page_test.dart test/widget/downloader_editor_gate_test.dart test/widget/about_page_update_test.dart
git commit -m "feat: redesign settings and downloader forms"
```

## Task 6: 收口剩余页面并完成全量验证

**Files:**
- Modify: `lib/features/auth/presentation/pages/login_page.dart`
- Modify: `lib/features/startup/presentation/pages/startup_page.dart`
- Modify: `lib/core/theme/uber_components.dart`
- Modify: `docs/design/neumorphism-style-guide.md`
- Test: `test/widget/home_page_test.dart`
- Test: `test/widget/management_tab_version_badge_test.dart`
- Test: `test/widget/profile_tab_update_badge_test.dart`

- [ ] **Step 1: 先补失败测试或更新断言，覆盖残余页面风格兼容**

```dart
testWidgets('Home shell still boots after neumorphism redesign', (tester) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [createTestDownloader()];

  await tester.pumpWidget(
    createTestApp(downloaderController: downloaderController),
  );
  await tester.pump();

  expect(find.byType(Scaffold), findsWidgets);
});
```

- [ ] **Step 2: 跑首页和管理页相关测试，拿到最终回归基线**

Run: `flutter test test/widget/home_page_test.dart test/widget/management_tab_version_badge_test.dart test/widget/profile_tab_update_badge_test.dart -r expanded`

Expected: PASS 或出现因样式结构调整导致的 FAIL，需要同步修正测试。

- [ ] **Step 3: 清理登录页、启动页和旧 Uber 组件的明显风格冲突**

```dart
@Deprecated('Use neo_components.dart instead')
export 'neo_components.dart';
```

```dart
return Scaffold(
  backgroundColor: tokens.baseBackground,
  body: Center(
    child: NeoCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_download_outlined, size: 42, color: tokens.primaryAccent),
          const SizedBox(height: 16),
          Text(AppConstants.appName),
        ],
      ),
    ),
  ),
);
```

- [ ] **Step 4: 执行格式化、针对性测试与全量测试**

Run: `dart format lib test`

Expected: 所有 Dart 修改文件被格式化完成。

Run: `flutter test test/widget/theme/neumorphism_theme_test.dart test/widget/theme/neo_components_test.dart test/widget/add_task_page_test.dart test/widget/tasks_page_shared_state_test.dart test/widget/all_tasks_tab_shared_state_test.dart test/widget/settings_page_test.dart test/widget/about_page_update_test.dart -r expanded`

Expected: PASS，核心页面和组件测试通过。

Run: `flutter test -r expanded`

Expected: PASS，全量 widget/unit 测试通过；若有失败，先修复再提交。

- [ ] **Step 5: 手动验证浅色 / 深色关键页面**

Run: `flutter run`

Expected: 手工检查以下页面在浅色与深色下都保持统一语言：

- 全部任务
- 单下载器任务
- 添加任务
- 设置
- 下载器配置 / 编辑
- 关于页

- [ ] **Step 6: 提交最终收口改造**

```bash
git add lib/features/auth/presentation/pages/login_page.dart lib/features/startup/presentation/pages/startup_page.dart lib/core/theme/uber_components.dart docs/design/neumorphism-style-guide.md test/widget/home_page_test.dart test/widget/management_tab_version_badge_test.dart test/widget/profile_tab_update_badge_test.dart
git commit -m "feat: finish neumorphism ui redesign"
```

## 自检结论

### Spec 覆盖检查

- 浅色与深色主题：Task 1 覆盖
- 共享 token 与组件层：Task 1、Task 2 覆盖
- 页面级全面重写：Task 3、Task 4、Task 5、Task 6 覆盖
- UI 风格描述文件：Task 2、Task 6 覆盖
- 状态可读性与任务效率：Task 3、Task 4、Task 5、Task 6 验证覆盖

### 占位符检查

- 本计划未使用 `TODO`、`TBD`、`implement later` 一类占位语。
- 每个任务都包含具体文件、示例代码、运行命令和预期结果。

### 类型与命名一致性检查

- 主题模式统一命名为 `AppThemeMode`
- 主题 token 统一命名为 `NeoThemeTokens`
- 共享组件统一前缀为 `Neo`
- 风格文档固定路径为 `docs/design/neumorphism-style-guide.md`
