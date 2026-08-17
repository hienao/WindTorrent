# Remaining Neumorphism UI Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the remaining 10 non-startup, non-overview, non-downloaders-tab pages to match the `design/v2` Neumorphism mockups while preserving existing behavior.

**Architecture:** Keep Provider controllers, go_router routes, service calls, and fail-fast behavior unchanged. Add a small set of reusable Neo UI widgets, then migrate pages in three batches: task flow, downloader configuration flow, and account/settings flow.

**Tech Stack:** Flutter 3.24.5, Material 3, Provider, go_router, flutter_test, existing `NeoThemeTokens`, `NeoCard`, `NeoInputShell`, `NeoActionBar`, and `NeoSection`.

---

## File Structure

- Modify: `lib/core/theme/neo_components.dart`
  - Add reusable page header, setting row, choice pill/filter strip, form field shell, status hero card, modal sheet primitives, and empty/error surface.
- Modify: `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
  - Replace traditional app bar/chips/task tiles with v2 task tab layout.
- Modify: `lib/features/tasks/presentation/pages/tasks_page.dart`
  - Replace traditional single-downloader task page layout and task tile actions with v2 layout.
- Modify: `lib/features/add_task/presentation/pages/add_task_page.dart`
  - Replace current NeoSection-heavy form with v2 add-task layout, source cards, bottom sheet, and conflict dialog styling.
- Modify: `lib/features/tasks/presentation/pages/task_detail_page.dart`
  - Replace detail sections with status hero, KV groups, and fixed Neo action bar.
- Modify: `lib/features/downloaders/presentation/pages/downloader_editor_page.dart`
  - Replace dropdown/list form with downloader type cards, recessed fields, and fixed save/test action.
- Modify: `lib/features/downloaders/presentation/pages/downloader_config_page.dart`
  - Replace config form sections with identity card, Neo speed panels, unsupported state, and fixed save action.
- Modify: `lib/features/home/presentation/pages/profile_tab.dart`
  - Replace Material Card/ListTile layout with v2 account card and setting rows.
- Modify: `lib/features/auth/presentation/pages/login_page.dart`
  - Replace app-bar-centered login layout with v2 brand login card.
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
  - Replace ListTile settings and default bottom sheets/dialogs with Neo rows, sheets, and dialog.
- Modify: `lib/features/settings/presentation/pages/about_page.dart`
  - Replace about ListTile section and update dialog with brand card, Neo rows, and Neo update dialog.
- Modify: `test/widget/test_helpers.dart`
  - Extend fakes only where needed to observe update/auth/config behavior without network calls.
- Modify: `test/widget/add_task_page_test.dart`
  - Update selectors to the new v2 add-task UI while keeping behavior assertions.
- Modify: `test/widget/all_tasks_tab_shared_state_test.dart`
  - Add task tab Neumorphism contract assertions.
- Modify: `test/widget/tasks_page_shared_state_test.dart`
  - Add single-downloader identity card and action assertions.
- Create: `test/widget/task_detail_neumorphism_test.dart`
  - Cover task detail hero, action availability, and delete callback behavior.
- Create: `test/widget/downloader_editor_neumorphism_test.dart`
  - Cover type card selection, port update, auth field switching, and save validation.
- Create: `test/widget/downloader_config_neumorphism_test.dart`
  - Cover config support/unsupported states, filled speed fields, validation, and save.
- Modify: `test/widget/profile_tab_update_badge_test.dart`
  - Update assertions for v2 account card and update badge.
- Create: `test/widget/login_page_test.dart`
  - Cover Google sign-in, loading/error states, and authenticated redirect.
- Modify: `test/widget/settings_page_test.dart`
  - Update assertions for Neo rows and bottom sheet choices.
- Modify: `test/widget/about_page_update_test.dart`
  - Update assertions for brand card, update row, update dialog, and unavailable state.

## Shared Conventions

Use these conventions across tasks:

```dart
final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
final textTheme = Theme.of(context).textTheme;
```

Use existing `AppSpacing` constants when pages already import `app_theme.dart`. Prefer:

- Page padding: `EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 20, 16, 120)` for standalone pages with a fixed bottom action.
- Home tab padding: `ResponsiveLayout.getPadding(context)` left/right and bottom `120` where the bottom tab bar may overlap.
- Status colors: `AppColors.success`, `AppColors.warning`, `AppColors.error`, `AppColors.offline`, `tokens.primaryAccent`.

Do not change controller method names, route strings, or model fields unless a test in this plan explicitly requires it.

---

### Task 1: Add Shared Neo Page Primitives

**Files:**
- Modify: `lib/core/theme/neo_components.dart`
- Create: `test/widget/theme/neo_page_primitives_test.dart`

- [ ] **Step 1: Write failing tests for the new primitives**

Create `test/widget/theme/neo_page_primitives_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';

void main() {
  Widget buildSubject(Widget child, {ThemeMode mode = ThemeMode.light}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: Scaffold(body: child),
    );
  }

  testWidgets('NeoPageHeader renders title, subtitle, back and trailing actions', (tester) async {
    var backTapped = false;
    var refreshTapped = false;

    await tester.pumpWidget(
      buildSubject(
        NeoPageHeader(
          title: 'Task Detail',
          subtitle: 'Auto refreshes',
          onBack: () => backTapped = true,
          trailing: NeoHeaderAction(
            tooltip: 'Refresh',
            icon: Icons.refresh,
            onPressed: () => refreshTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Task Detail'), findsOneWidget);
    expect(find.text('Auto refreshes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.tap(find.byTooltip('Refresh'));

    expect(backTapped, isTrue);
    expect(refreshTapped, isTrue);
  });

  testWidgets('NeoSettingRow exposes text, value, and danger styling hook', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      buildSubject(
        NeoSettingRow(
          icon: Icons.logout,
          title: 'Sign out',
          subtitle: 'Leave this account',
          trailingText: 'Danger',
          isDestructive: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Leave this account'), findsOneWidget);
    expect(find.text('Danger'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    expect(tapped, isTrue);
  });

  testWidgets('NeoFilterStrip calls selection callback with selected value', (tester) async {
    String? selected;

    await tester.pumpWidget(
      buildSubject(
        NeoFilterStrip<String>(
          selectedValue: 'all',
          options: const [
            NeoChoiceOption(value: 'all', label: 'All'),
            NeoChoiceOption(value: 'downloading', label: 'Downloading'),
          ],
          onSelected: (value) => selected = value,
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Downloading'), findsOneWidget);

    await tester.tap(find.text('Downloading'));
    expect(selected, 'downloading');
  });

  testWidgets('NeoFormFieldShell renders label, suffix, and child', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const NeoFormFieldShell(
          label: 'Download limit',
          suffix: 'KB/s',
          child: Text('4096'),
        ),
      ),
    );

    expect(find.text('Download limit'), findsOneWidget);
    expect(find.text('4096'), findsOneWidget);
    expect(find.text('KB/s'), findsOneWidget);
  });

  testWidgets('NeoStatusHeroCard renders badge, progress, and metadata', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        NeoStatusHeroCard(
          icon: Icons.download_rounded,
          title: 'ubuntu.iso',
          subtitle: 'NAS Aria2',
          badge: const NeoBadge(
            label: 'Downloading',
            backgroundColor: Color(0x222A7FFF),
            foregroundColor: Color(0xFF2A7FFF),
          ),
          progress: 0.72,
          leadingMeta: '72%',
          trailingMeta: '3.8 MB/s',
        ),
      ),
    );

    expect(find.text('ubuntu.iso'), findsOneWidget);
    expect(find.text('NAS Aria2'), findsOneWidget);
    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('3.8 MB/s'), findsOneWidget);
    expect(find.byType(NeoProgress), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the primitive tests and verify they fail**

Run:

```bash
flutter test test/widget/theme/neo_page_primitives_test.dart
```

Expected: FAIL with missing classes such as `NeoPageHeader`, `NeoSettingRow`, `NeoFilterStrip`, `NeoFormFieldShell`, and `NeoStatusHeroCard`.

- [ ] **Step 3: Add the shared primitive classes**

Append the following code to `lib/core/theme/neo_components.dart` above `_raisedShadow`:

```dart
@immutable
class NeoHeaderAction {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const NeoHeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
}

class NeoPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final NeoHeaderAction? trailing;

  const NeoPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        if (onBack != null) ...[
          _NeoIconDisc(
            icon: Icons.arrow_back_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: onBack!,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textTheme.headlineSmall?.color,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          _NeoIconDisc(
            icon: trailing!.icon,
            tooltip: trailing!.tooltip,
            onTap: trailing!.onPressed,
            color: tokens.primaryAccent,
          ),
        ],
      ],
    );
  }
}

class _NeoIconDisc extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _NeoIconDisc({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final iconColor = color ?? Theme.of(context).iconTheme.color;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tokens.raisedSurface,
              shape: BoxShape.circle,
              boxShadow: _raisedShadow(tokens),
            ),
            child: Icon(icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class NeoSettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const NeoSettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = isDestructive ? colorScheme.error : tokens.primaryAccent;
    final rowTrailing =
        trailing ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText!,
                style: textTheme.bodySmall?.copyWith(
                  color: textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: textTheme.bodySmall?.color?.withValues(alpha: 0.72),
            ),
          ],
        );

    return NeoCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: isDestructive ? colorScheme.error : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          rowTrailing,
        ],
      ),
    );
  }
}

@immutable
class NeoChoiceOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const NeoChoiceOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

class NeoFilterStrip<T> extends StatelessWidget {
  final T selectedValue;
  final List<NeoChoiceOption<T>> options;
  final ValueChanged<T> onSelected;

  const NeoFilterStrip({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: NeoChoicePill(
                label: option.label,
                icon: option.icon,
                selected: option.value == selectedValue,
                onTap: () => onSelected(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class NeoChoicePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const NeoChoicePill({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final color = selected ? tokens.primaryAccent : Theme.of(context).textTheme.bodySmall?.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryAccent.withValues(alpha: 0.12)
              : tokens.recessedSurface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: tokens.shadowColor.withValues(alpha: tokens.isDark ? 0.30 : 0.18),
              offset: const Offset(3, 3),
              blurRadius: 8,
            ),
            BoxShadow(
              color: tokens.highlightColor.withValues(alpha: tokens.isDark ? 0.035 : 0.72),
              offset: const Offset(-3, -3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class NeoFormFieldShell extends StatelessWidget {
  final String label;
  final Widget child;
  final String? suffix;
  final bool enabled;

  const NeoFormFieldShell({
    super.key,
    required this.label,
    required this.child,
    this.suffix,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: NeoInputShell(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: child),
                if (suffix != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    suffix!,
                    style: textTheme.bodySmall?.copyWith(
                      color: textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NeoStatusHeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? badge;
  final double? progress;
  final String? leadingMeta;
  final String? trailingMeta;
  final Color? iconColor;

  const NeoStatusHeroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.progress,
    this.leadingMeta,
    this.trailingMeta,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    final textTheme = Theme.of(context).textTheme;

    return NeoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconColor ?? tokens.primaryAccent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                badge!,
              ],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            NeoProgress(value: progress!),
          ],
          if (leadingMeta != null || trailingMeta != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    leadingMeta ?? '',
                    style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  trailingMeta ?? '',
                  style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class NeoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const NeoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run primitive tests**

Run:

```bash
flutter test test/widget/theme/neo_page_primitives_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit shared primitives**

```bash
git add lib/core/theme/neo_components.dart test/widget/theme/neo_page_primitives_test.dart
git commit -m "feat: add shared neumorphic page primitives"
```

---

### Task 2: Rewrite Task List Tab and Single-Downloader Tasks Page

**Files:**
- Modify: `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
- Modify: `lib/features/tasks/presentation/pages/tasks_page.dart`
- Modify: `test/widget/all_tasks_tab_shared_state_test.dart`
- Modify: `test/widget/tasks_page_shared_state_test.dart`

- [ ] **Step 1: Add failing task page visual contract assertions**

Update `test/widget/tasks_page_shared_state_test.dart` by extending the existing test named `TasksPage 在拟物化改造后保留共享任务数据并使用 Neo 组件` with these expectations after the existing `NeoInputShell` assertion:

```dart
      expect(find.text('Test Aria2'), findsOneWidget);
      expect(find.textContaining('192.168.1.100'), findsOneWidget);
      expect(find.text('Refactor Download'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byType(NeoStatusHeroCard), findsWidgets);
```

Add this import at the top if it is missing:

```dart
import 'package:windwalker/core/theme/neo_components.dart';
```

Update `test/widget/all_tasks_tab_shared_state_test.dart` by adding this test:

```dart
testWidgets('All tasks tab uses Neo filter strip and v2 task cards', (tester) async {
  final downloaderController = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(id: 'test-1', name: 'NAS Aria2'),
    ];
  final taskController = TaskController()
    ..debugSetTasksForTest('test-1', [
      DownloadTask(
        id: 'task-1',
        gid: 'task-1',
        name: 'Global Download',
        status: TaskStatus.downloading,
        downloadSpeed: 2048,
        downloaderId: 'test-1',
      ),
    ]);

  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      taskController: taskController,
    ),
  );
  await tester.pump();

  await tester.tap(find.text('Tasks'));
  await tester.pump();

  expect(find.text('Task List'), findsOneWidget);
  expect(find.text('Global Download'), findsOneWidget);
  expect(find.byType(NeoFilterStrip<TaskStatus?>), findsOneWidget);
  expect(find.byType(NeoStatusHeroCard), findsWidgets);

  taskController.stopAutoRefresh();
});
```

- [ ] **Step 2: Run task page tests and verify they fail**

Run:

```bash
flutter test test/widget/tasks_page_shared_state_test.dart test/widget/all_tasks_tab_shared_state_test.dart
```

Expected: FAIL because the pages still use the older layout.

- [ ] **Step 3: Add shared status helpers in task pages**

In both `all_tasks_tab_page.dart` and `tasks_page.dart`, use this status style helper if not already present:

```dart
class _TaskStatusVisual {
  final Color foreground;
  final Color background;
  final IconData icon;

  const _TaskStatusVisual({
    required this.foreground,
    required this.background,
    required this.icon,
  });
}

_TaskStatusVisual _visualForTaskStatus(TaskStatus status) {
  switch (status) {
    case TaskStatus.downloading:
      return _TaskStatusVisual(
        foreground: AppColors.warning,
        background: AppColors.warning.withValues(alpha: 0.16),
        icon: Icons.download_rounded,
      );
    case TaskStatus.waiting:
      return _TaskStatusVisual(
        foreground: AppColors.warning,
        background: AppColors.warning.withValues(alpha: 0.16),
        icon: Icons.more_horiz_rounded,
      );
    case TaskStatus.paused:
      return _TaskStatusVisual(
        foreground: AppColors.offline,
        background: AppColors.offline.withValues(alpha: 0.16),
        icon: Icons.pause_rounded,
      );
    case TaskStatus.seeding:
      return _TaskStatusVisual(
        foreground: AppColors.success,
        background: AppColors.success.withValues(alpha: 0.16),
        icon: Icons.upload_rounded,
      );
    case TaskStatus.completed:
      return _TaskStatusVisual(
        foreground: AppColors.success,
        background: AppColors.success.withValues(alpha: 0.16),
        icon: Icons.check_rounded,
      );
    case TaskStatus.error:
      return _TaskStatusVisual(
        foreground: AppColors.error,
        background: AppColors.error.withValues(alpha: 0.16),
        icon: Icons.priority_high_rounded,
      );
    case TaskStatus.removed:
    case TaskStatus.unknown:
      return _TaskStatusVisual(
        foreground: AppColors.offline,
        background: AppColors.offline.withValues(alpha: 0.16),
        icon: Icons.help_outline_rounded,
      );
  }
}
```

- [ ] **Step 4: Replace `AllTasksTabPage` body with the v2 layout**

In `lib/features/home/presentation/pages/all_tasks_tab_page.dart`:

1. Remove the internal `AppBar`.
2. Keep `Scaffold(backgroundColor: tokens.baseBackground)`.
3. Build a `RefreshIndicator` containing a `ListView`.
4. Place `NeoPageHeader`, `NeoInputShell`, `NeoFilterStrip<TaskStatus?>`, and task cards in the list.

Use this structure:

```dart
return Scaffold(
  backgroundColor: tokens.baseBackground,
  body: Consumer<TaskController>(
    builder: (context, controller, _) {
      final tasks = _filteredTasks(controller.allTasks);
      return RefreshIndicator(
        onRefresh: _loadAllTasks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.getPadding(context).left,
            MediaQuery.paddingOf(context).top + AppSpacing.lg,
            ResponsiveLayout.getPadding(context).right,
            120,
          ),
          children: [
            NeoPageHeader(
              title: l10n.taskList,
              subtitle: '跨下载器查看全部任务',
              trailing: NeoHeaderAction(
                tooltip: l10n.refresh,
                icon: Icons.refresh_rounded,
                onPressed: _loadAllTasks,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            NeoInputShell(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.searchTasks,
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            NeoFilterStrip<TaskStatus?>(
              selectedValue: _activeStatus,
              options: [
                NeoChoiceOption(value: null, label: l10n.all),
                NeoChoiceOption(value: TaskStatus.downloading, label: l10n.downloadingTab),
                NeoChoiceOption(value: TaskStatus.waiting, label: l10n.waiting),
                NeoChoiceOption(value: TaskStatus.paused, label: l10n.paused),
                NeoChoiceOption(value: TaskStatus.seeding, label: l10n.seeding),
                NeoChoiceOption(value: TaskStatus.completed, label: l10n.completedTab),
                NeoChoiceOption(value: TaskStatus.error, label: l10n.error),
              ],
              onSelected: (status) => setState(() => _activeStatus = status),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (controller.isRefreshingAll)
              const Padding(
                padding: EdgeInsets.only(top: 96),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (tasks.isEmpty)
              NeoEmptyState(
                icon: Icons.task_alt_rounded,
                title: l10n.noTasks,
                subtitle: l10n.searchTasks,
              )
            else
              ...tasks.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _AllTaskTile(
                    task: task,
                    downloaderName: _downloaderNames[task.downloaderId] ?? task.downloaderId,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  ),
);
```

Update `_AllTaskTile` to render `NeoStatusHeroCard` plus metadata:

```dart
final visual = _visualForTaskStatus(task.status);
return NeoStatusHeroCard(
  icon: visual.icon,
  iconColor: visual.foreground,
  title: task.name,
  subtitle: '$downloaderName · ${task.savePath}',
  badge: NeoBadge(
    label: task.status.localizedLabel(context),
    backgroundColor: visual.background,
    foregroundColor: visual.foreground,
  ),
  progress: task.progress,
  leadingMeta: '${(task.progress * 100).toStringAsFixed(1)}% · ${task.formattedSize}',
  trailingMeta: task.formattedSpeed,
);
```

Wrap it with `GestureDetector` or `NeoCard(onTap: ...)` only once. If using `NeoStatusHeroCard`, add an `onTap` parameter to `NeoStatusHeroCard` in Task 1 or wrap it in `InkWell` with transparent material. Prefer adding `onTap` to `NeoStatusHeroCard` if this page needs it:

```dart
final VoidCallback? onTap;
```

and pass it to the underlying `NeoCard(onTap: onTap, ...)`.

- [ ] **Step 5: Replace `TasksPage` body with downloader identity and v2 task cards**

In `lib/features/tasks/presentation/pages/tasks_page.dart`:

1. Remove the traditional `AppBar`.
2. Build `NeoPageHeader` with back and refresh actions controlled by existing `showBackButton` and `showRefreshButton`.
3. Add a `NeoStatusHeroCard` identity card using the current downloader from `DownloaderController`.
4. Replace `ChoiceChip` with `NeoFilterStrip<TaskStatus?>`.
5. Update `_TaskTile` to use `NeoStatusHeroCard` and bottom action buttons.

Use this header and identity card pattern:

```dart
final downloader = context
    .watch<DownloaderController>()
    .getDownloader(widget.downloaderId ?? '');
final title = widget.titleOverride ?? widget.downloaderType?.label ?? l10n.taskList;

NeoPageHeader(
  title: title,
  subtitle: downloader == null
      ? l10n.taskList
      : '${downloader.name} · ${downloader.host}:${downloader.port}',
  onBack: widget.showBackButton ? () => context.pop() : null,
  trailing: widget.showRefreshButton
      ? NeoHeaderAction(
          tooltip: l10n.refresh,
          icon: Icons.refresh_rounded,
          onPressed: _loadTasks,
        )
      : null,
),
```

Use this action row inside `_TaskTile`:

```dart
Row(
  children: [
    Expanded(
      child: NeoButton.secondary(
        onPressed: task.status == TaskStatus.downloading || task.status == TaskStatus.waiting
            ? onPause
            : null,
        label: Text(l10n.pause),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: NeoButton.secondary(
        onPressed: task.status == TaskStatus.paused ? onResume : null,
        label: Text(l10n.resume),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: NeoButton.secondary(
        onPressed: onDelete,
        label: Text(l10n.delete),
      ),
    ),
  ],
)
```

If `l10n.details` is unavailable, do not add a separate Details button; the card tap remains the details action. Keep tests aligned with actual localized strings already present.

- [ ] **Step 6: Run task flow list tests**

Run:

```bash
flutter test test/widget/tasks_page_shared_state_test.dart test/widget/all_tasks_tab_shared_state_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit task list page rewrites**

```bash
git add lib/features/home/presentation/pages/all_tasks_tab_page.dart lib/features/tasks/presentation/pages/tasks_page.dart test/widget/all_tasks_tab_shared_state_test.dart test/widget/tasks_page_shared_state_test.dart
git commit -m "feat: rewrite task list pages with neumorphic layout"
```

---

### Task 3: Rewrite Add Task Page

**Files:**
- Modify: `lib/features/add_task/presentation/pages/add_task_page.dart`
- Modify: `test/widget/add_task_page_test.dart`

- [ ] **Step 1: Update AddTaskPage tests for the v2 UI contract**

In `test/widget/add_task_page_test.dart`, add this test to the `AddTaskPage torrent flow` group:

```dart
testWidgets('renders v2 neumorphic add task structure', (tester) async {
  await tester.pumpWidget(
    createAddTaskTestApp(downloaderController: controller),
  );
  await tester.pumpAndSettle();

  expect(find.text('添加任务'), findsOneWidget);
  expect(find.text('选择下载器'), findsOneWidget);
  expect(find.text('下载来源'), findsOneWidget);
  expect(find.text('保存位置'), findsOneWidget);
  expect(find.byType(NeoPageHeader), findsOneWidget);
  expect(find.byType(NeoFormFieldShell), findsWidgets);
  expect(find.byType(NeoActionBar), findsOneWidget);
});
```

Add import:

```dart
import 'package:windwalker/core/theme/neo_components.dart';
```

- [ ] **Step 2: Run AddTaskPage tests and verify the new test fails**

Run:

```bash
flutter test test/widget/add_task_page_test.dart
```

Expected: FAIL because `AddTaskPage` still uses its previous structure.

- [ ] **Step 3: Replace the AddTaskPage app bar and main sections**

In `lib/features/add_task/presentation/pages/add_task_page.dart`:

1. Remove the traditional `AppBar`.
2. Put `NeoPageHeader(title: l10n.addTask, subtitle: l10n.addTaskSubtitle, onBack: () => context.pop())` at the top of the `ListView`.
3. Keep the `Form`, existing controllers, selected downloader state, torrent picker state, and submit method unchanged.
4. Render sections in this order:
   - downloader selection
   - source input and source cards
   - save path
5. Keep `NeoActionBar` bottom button.

Use this section skeleton:

```dart
ListView(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
  children: [
    NeoPageHeader(
      title: l10n.addTask,
      subtitle: l10n.addTaskSubtitle,
      onBack: () => context.pop(),
    ),
    const SizedBox(height: AppSpacing.lg),
    _SectionLabel(title: l10n.selectDownloaderStep, trailing: l10n.selectDownloaderDesc),
    const SizedBox(height: AppSpacing.sm),
    _DownloaderSelectionCard(...),
    const SizedBox(height: AppSpacing.lg),
    _SectionLabel(title: l10n.downloadLink, trailing: l10n.downloadLinkDesc),
    const SizedBox(height: AppSpacing.sm),
    _SourcePanel(...),
    const SizedBox(height: AppSpacing.lg),
    _SectionLabel(title: l10n.savePathStep, trailing: l10n.savePathDesc),
    const SizedBox(height: AppSpacing.sm),
    NeoFormFieldShell(
      label: l10n.savePath,
      child: TextFormField(
        controller: _savePathController,
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    ),
  ],
)
```

Create this private section label in the same file:

```dart
class _SectionLabel extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionLabel({
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            trailing,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                  height: 1.2,
                ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Convert downloader selection and source cards**

Keep the current downloader selection behavior, but render selected downloader as:

```dart
NeoStatusHeroCard(
  icon: Icons.storage_rounded,
  title: selectedDownloader.name,
  subtitle: '${selectedDownloader.host}:${selectedDownloader.port}',
  badge: NeoBadge(
    label: selectedDownloader.type.label,
    backgroundColor: tokens.primaryAccent.withValues(alpha: 0.12),
    foregroundColor: tokens.primaryAccent,
  ),
  onTap: _showDownloaderPicker,
)
```

Render no-selection as:

```dart
NeoEmptyState(
  icon: Icons.storage_rounded,
  title: l10n.selectDownloader,
  subtitle: l10n.addDownloaderHint,
)
```

Render source choices as two `NeoCard`s:

```dart
Row(
  children: [
    Expanded(
      child: _SourceCard(
        icon: Icons.link_rounded,
        title: l10n.pasteLink,
        subtitle: l10n.magnetOrHttpLink,
        selected: _torrentFile == null,
        onTap: () => setState(() => _torrentFile = null),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: _SourceCard(
        icon: Icons.description_rounded,
        title: l10n.selectTorrentFile,
        subtitle: _torrentFile?.fileName ?? '.torrent',
        selected: _torrentFile != null,
        onTap: _pickTorrentFile,
      ),
    ),
  ],
)
```

Again, use existing localized strings from the file where available.

- [ ] **Step 5: Style downloader picker and source conflict dialog**

Keep current picker/conflict behavior, but use:

- `showModalBottomSheet(showDragHandle: true, backgroundColor: Colors.transparent, builder: ...)`
- `NeoCard` as the sheet content.
- `NeoSettingRow` or `NeoStatusHeroCard` rows for downloader choices.
- `AlertDialog` replacement using `Dialog(backgroundColor: Colors.transparent, child: NeoCard(...))` for source conflict.

Do not change the boolean result semantics of the conflict dialog.

- [ ] **Step 6: Run AddTaskPage tests**

Run:

```bash
flutter test test/widget/add_task_page_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit AddTaskPage rewrite**

```bash
git add lib/features/add_task/presentation/pages/add_task_page.dart test/widget/add_task_page_test.dart
git commit -m "feat: rewrite add task page with neumorphic layout"
```

---

### Task 4: Rewrite Task Detail Page

**Files:**
- Modify: `lib/features/tasks/presentation/controllers/task_controller.dart`
- Modify: `lib/features/tasks/presentation/pages/task_detail_page.dart`
- Create: `test/widget/task_detail_neumorphism_test.dart`

- [ ] **Step 1: Add a test-only current task seeding helper**

In `lib/features/tasks/presentation/controllers/task_controller.dart`, add this method near the existing `debugSetTasksForTest` helper:

```dart
@visibleForTesting
void debugSetCurrentTaskForTest(DownloadTask? task) {
  _currentTask = task;
  notifyListeners();
}
```

Add this import at the top if it is missing:

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 2: Write failing task detail tests**

Create `test/widget/task_detail_neumorphism_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/task_detail_page.dart';
import 'package:windwalker/models/download_task.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('TaskDetailPage renders v2 hero and info sections', (tester) async {
    final taskController = TaskController()
      ..debugSetCurrentTaskForTest(
        DownloadTask(
          id: 'task-1',
          gid: 'task-1',
          name: 'ubuntu.iso',
          status: TaskStatus.downloading,
          progress: 0.72,
          downloadSpeed: 2048,
          uploadSpeed: 128,
          downloaderId: 'test-1',
        ),
      );

    final downloaderController = MockDownloaderController()
      ..testDownloaders = [createTestDownloader(id: 'test-1', name: 'NAS Aria2')];

    await tester.pumpWidget(
      createTestApp(
        downloaderController: downloaderController,
        taskController: taskController,
        child: const TaskDetailPage(
          taskId: 'task-1',
          downloaderId: 'test-1',
          taskName: 'ubuntu.iso',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Task Detail'), findsOneWidget);
    expect(find.text('ubuntu.iso'), findsOneWidget);
    expect(find.byType(NeoStatusHeroCard), findsOneWidget);
    expect(find.text('File Info'), findsOneWidget);
    expect(find.text('Download Info'), findsOneWidget);
    expect(find.text('Connection Info'), findsOneWidget);
    expect(find.byType(NeoActionBar), findsOneWidget);

    taskController.dispose();
  });

  testWidgets('TaskDetailPage keeps pause resume delete actions visible', (tester) async {
    final taskController = TaskController()
      ..debugSetCurrentTaskForTest(
        DownloadTask(
          id: 'task-1',
          gid: 'task-1',
          name: 'paused.iso',
          status: TaskStatus.paused,
          downloaderId: 'test-1',
        ),
      );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController()
          ..testDownloaders = [createTestDownloader(id: 'test-1')],
        taskController: taskController,
        child: const TaskDetailPage(
          taskId: 'task-1',
          downloaderId: 'test-1',
          taskName: 'paused.iso',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    taskController.dispose();
  });
}
```

- [ ] **Step 3: Run task detail tests and verify they fail**

Run:

```bash
flutter test test/widget/task_detail_neumorphism_test.dart
```

Expected: FAIL because the page does not yet render `NeoStatusHeroCard`.

- [ ] **Step 4: Replace `TaskDetailPage` top layout**

In `lib/features/tasks/presentation/pages/task_detail_page.dart`:

1. Remove traditional `AppBar`.
2. Use `NeoPageHeader(title: l10n.taskDetail, subtitle: '自动刷新任务状态', onBack: () => context.pop())`.
3. At the top of the list, render `_taskHero(context, task)`.

Implement:

```dart
Widget _taskHero(BuildContext context, DownloadTask? task) {
  final l10n = AppLocalizations.of(context)!;
  final displayName = task?.name.isNotEmpty == true ? task!.name : widget.taskName;
  final status = task?.status ?? TaskStatus.unknown;
  final visual = _statusVisual(status);
  final downloaderName =
      context.read<DownloaderController>().getDownloader(widget.downloaderId)?.name ?? '--';
  final progress = (task?.progress ?? 0).clamp(0, 1).toDouble();

  return NeoStatusHeroCard(
    icon: visual.icon,
    iconColor: visual.foreground,
    title: displayName,
    subtitle: '$downloaderName · ${widget.taskId}',
    badge: NeoBadge(
      label: task?.status.localizedLabel(context) ?? l10n.loading,
      backgroundColor: visual.background,
      foregroundColor: visual.foreground,
    ),
    progress: progress,
    leadingMeta: '${(progress * 100).toStringAsFixed(1)}%',
    trailingMeta: task?.formattedSpeed ?? '--',
  );
}
```

Reuse the `_TaskStatusVisual` helper from Task 2 or define a local equivalent.

- [ ] **Step 5: Convert detail sections to compact Neo KV sections**

Keep `_fileSection`, `_downloadSection`, and `_connectionSection`, but make their body use `_NeoKvSection`:

```dart
class _NeoKvSection extends StatelessWidget {
  final String title;
  final List<_NeoKvItem> items;

  const _NeoKvSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return NeoSection(
      title: title,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Text(
                    items[i].label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    items[i].value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NeoKvItem {
  final String label;
  final String value;

  const _NeoKvItem(this.label, this.value);
}
```

- [ ] **Step 6: Keep bottom actions but use the existing `NeoActionBar`**

The page already uses `NeoActionBar`. Keep the same enable/disable rules:

- Pause enabled for downloading/waiting.
- Resume enabled for paused.
- Delete always enabled when a task can be removed.

Style destructive delete by passing `destructive: true` to the existing `_actionButton` or adjust it to use `NeoButton.secondary` with red foreground if simpler.

- [ ] **Step 7: Run task detail tests**

Run:

```bash
flutter test test/widget/task_detail_neumorphism_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit task detail rewrite**

```bash
git add lib/features/tasks/presentation/pages/task_detail_page.dart test/widget/task_detail_neumorphism_test.dart
git commit -m "feat: rewrite task detail page with neumorphic layout"
```

---

### Task 5: Rewrite Downloader Editor and Config Pages

**Files:**
- Modify: `lib/features/downloaders/presentation/pages/downloader_editor_page.dart`
- Modify: `lib/features/downloaders/presentation/pages/downloader_config_page.dart`
- Modify: `test/widget/test_helpers.dart`
- Create: `test/widget/downloader_editor_neumorphism_test.dart`
- Create: `test/widget/downloader_config_neumorphism_test.dart`

- [ ] **Step 1: Extend test downloader controller for config page tests**

In `test/widget/test_helpers.dart`, update `MockDownloaderController` with fields and overrides:

```dart
SpeedConfigDescriptor? testSpeedConfigDescriptor;
DownloaderSpeedConfig? testSpeedConfig;
DownloaderSpeedConfig? savedSpeedConfig;
bool saveSpeedConfigResult = true;

@override
SpeedConfigDescriptor? getSpeedConfigDescriptor(String downloaderId) =>
    testSpeedConfigDescriptor;

@override
Future<DownloaderSpeedConfig?> getSpeedConfig(String downloaderId) async =>
    testSpeedConfig;

@override
Future<bool> setSpeedConfig(
  String downloaderId,
  DownloaderSpeedConfig config,
) async {
  savedSpeedConfig = config;
  return saveSpeedConfigResult;
}

Downloader? updatedDownloader;
Downloader? addedDownloader;

@override
Future<ConnectionResult> updateDownloader(Downloader downloader) async {
  updatedDownloader = downloader;
  return const ConnectionSuccess();
}

@override
Future<ConnectionResult> addDownloader(Downloader downloader) async {
  addedDownloader = downloader;
  _testDownloaders.add(downloader);
  notifyListeners();
  return const ConnectionSuccess();
}
```

If `DownloaderController.addDownloader` has a different signature, match the real signature from the controller and update the fake accordingly.

- [ ] **Step 2: Write failing downloader editor tests**

Create `test/widget/downloader_editor_neumorphism_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/models/downloader.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('DownloaderEditorPage renders type cards and v2 form fields', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        initialLocation: '/downloaders/new',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Downloader'), findsOneWidget);
    expect(find.text('Aria2'), findsOneWidget);
    expect(find.text('qBittorrent'), findsOneWidget);
    expect(find.text('Transmission'), findsOneWidget);
    expect(find.byType(NeoFormFieldShell), findsWidgets);
    expect(find.byType(NeoActionBar), findsOneWidget);
  });

  testWidgets('switching downloader type updates default port and auth fields', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        initialLocation: '/downloaders/new',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('qBittorrent'));
    await tester.pumpAndSettle();

    expect(find.text('8080'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('RPC Secret'), findsNothing);
  });

  testWidgets('editing downloader pre-fills existing values', (tester) async {
    final controller = MockDownloaderController()
      ..testDownloaders = [
        createTestDownloader(
          id: 'edit-1',
          name: 'Edit qBit',
          type: DownloaderType.qbittorrent,
          host: 'nas.local',
          port: 8080,
        ),
      ];

    await tester.pumpWidget(
      createTestApp(
        downloaderController: controller,
        initialLocation: '/downloaders/edit-1/edit',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Downloader'), findsOneWidget);
    expect(find.text('Edit qBit'), findsOneWidget);
    expect(find.text('nas.local'), findsOneWidget);
    expect(find.text('8080'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Write failing downloader config tests**

Create `test/widget/downloader_config_neumorphism_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/speed_config_descriptor.dart';

import 'test_helpers.dart';

void main() {
  SpeedConfigDescriptor descriptor() => const SpeedConfigDescriptor(
        sections: [
          ConfigSection(
            title: 'Speed Limit Mode',
            description: 'Apply normal speed limits',
            fields: [
              ConfigField(
                key: 'speedLimitModeEnabled',
                label: 'Enable speed limit mode',
                type: ConfigFieldType.toggle,
              ),
              ConfigField(
                key: 'downloadLimitKB',
                label: 'Download limit',
                type: ConfigFieldType.kbps,
                hint: '0 means unlimited',
              ),
              ConfigField(
                key: 'uploadLimitKB',
                label: 'Upload limit',
                type: ConfigFieldType.kbps,
                hint: '0 means unlimited',
              ),
            ],
          ),
        ],
      );

  testWidgets('DownloaderConfigPage renders identity card and speed fields', (tester) async {
    final controller = MockDownloaderController()
      ..testDownloaders = [createTestDownloader(id: 'test-1', name: 'qBit Home')]
      ..testSpeedConfigDescriptor = descriptor()
      ..testSpeedConfig = const DownloaderSpeedConfig(
        speedLimitModeEnabled: true,
        downloadLimitKB: 4096,
        uploadLimitKB: 1024,
        altDownloadLimitKB: 0,
        altUploadLimitKB: 0,
      );

    await tester.pumpWidget(
      createTestApp(
        downloaderController: controller,
        initialLocation: '/downloaders/test-1/config',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('qBit Home'), findsOneWidget);
    expect(find.byType(NeoStatusHeroCard), findsOneWidget);
    expect(find.byType(NeoFormFieldShell), findsWidgets);
    expect(find.text('4096'), findsOneWidget);
    expect(find.text('1024'), findsOneWidget);
    expect(find.byType(NeoActionBar), findsOneWidget);
  });

  testWidgets('DownloaderConfigPage shows unsupported state without save action', (tester) async {
    final controller = MockDownloaderController()
      ..testDownloaders = [createTestDownloader(id: 'test-1')]
      ..testSpeedConfigDescriptor = null;

    await tester.pumpWidget(
      createTestApp(
        downloaderController: controller,
        initialLocation: '/downloaders/test-1/config',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NeoEmptyState), findsOneWidget);
    expect(find.byType(NeoActionBar), findsNothing);
  });
}
```

- [ ] **Step 4: Run downloader flow tests and verify they fail**

Run:

```bash
flutter test test/widget/downloader_editor_neumorphism_test.dart test/widget/downloader_config_neumorphism_test.dart
```

Expected: FAIL because pages still use dropdown/list form and old config layout.

- [ ] **Step 5: Rewrite `DownloaderEditorPage` layout**

In `lib/features/downloaders/presentation/pages/downloader_editor_page.dart`:

1. Remove the traditional `AppBar`.
2. Add `NeoPageHeader`.
3. Replace `DropdownButtonFormField<DownloaderType>` with three `_DownloaderTypeCard`s.
4. Wrap text fields in `NeoFormFieldShell`.
5. Keep the same controllers, validators, `_save`, and `ConnectionResult` handling.

Implement `_DownloaderTypeCard`:

```dart
class _DownloaderTypeCard extends StatelessWidget {
  final DownloaderType type;
  final bool selected;
  final VoidCallback onTap;

  const _DownloaderTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;

    return Expanded(
      child: NeoCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        onTap: onTap,
        child: Column(
          children: [
            NeoDownloaderTypeIcon(type: type, size: 36),
            const SizedBox(height: 8),
            Text(
              type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? tokens.primaryAccent : null,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Import `neo_downloader_widgets.dart` for `NeoDownloaderTypeIcon`.

- [ ] **Step 6: Rewrite `DownloaderConfigPage` layout**

In `lib/features/downloaders/presentation/pages/downloader_config_page.dart`:

1. Remove traditional `AppBar`.
2. Add `NeoPageHeader`.
3. Add `NeoStatusHeroCard` for downloader identity.
4. For `_error != null` and unsupported descriptor, display `NeoEmptyState`.
5. Render toggle fields with a compact custom row or `SwitchListTile` inside Neo card only if styling is acceptable.
6. Render kbps fields with `NeoFormFieldShell(label: field.label, suffix: 'KB/s', enabled: enabled, child: TextFormField(...))`.
7. Keep validators and `_save` unchanged.

Use this unsupported body:

```dart
NeoEmptyState(
  icon: Icons.tune_rounded,
  title: l10n.downloaderNotSupportConfig,
  subtitle: downloader == null
      ? l10n.downloader
      : '${downloader.host}:${downloader.port}',
)
```

- [ ] **Step 7: Run downloader flow tests**

Run:

```bash
flutter test test/widget/downloader_editor_neumorphism_test.dart test/widget/downloader_config_neumorphism_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit downloader config flow rewrite**

```bash
git add lib/features/downloaders/presentation/pages/downloader_editor_page.dart lib/features/downloaders/presentation/pages/downloader_config_page.dart test/widget/test_helpers.dart test/widget/downloader_editor_neumorphism_test.dart test/widget/downloader_config_neumorphism_test.dart
git commit -m "feat: rewrite downloader config flow with neumorphic layout"
```

---

### Task 6: Rewrite Profile, Login, Settings, and About Pages

**Files:**
- Modify: `lib/features/home/presentation/pages/profile_tab.dart`
- Modify: `lib/features/auth/presentation/pages/login_page.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `lib/features/settings/presentation/pages/about_page.dart`
- Modify: `test/widget/profile_tab_update_badge_test.dart`
- Create: `test/widget/login_page_test.dart`
- Modify: `test/widget/settings_page_test.dart`
- Modify: `test/widget/about_page_update_test.dart`

- [ ] **Step 1: Update profile tab test for v2 account card**

In `test/widget/profile_tab_update_badge_test.dart`, add these expectations after tapping `Mine`:

```dart
    expect(find.byType(NeoSettingRow), findsWidgets);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
```

Add import:

```dart
import 'package:windwalker/core/theme/neo_components.dart';
```

- [ ] **Step 2: Add login page tests**

Create `test/widget/login_page_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/auth/presentation/pages/login_page.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('LoginPage renders v2 brand card and Google action', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        downloaderController: MockDownloaderController(),
        child: const LoginPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WindWalker'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byType(NeoPageHeader), findsOneWidget);
    expect(find.byType(NeoCard), findsWidgets);
  });
}
```

- [ ] **Step 3: Update settings tests for Neo rows and sheet**

In `test/widget/settings_page_test.dart`:

1. Import `neo_components.dart`.
2. Replace icon-only assertions with `NeoSettingRow` assertions.
3. Keep language/theme picker tests.

Use this new test:

```dart
testWidgets('settings page uses Neo rows for theme and language', (tester) async {
  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      settingsController: settingsController,
      initialLocation: '/settings',
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Settings'), findsOneWidget);
  expect(find.byType(NeoPageHeader), findsOneWidget);
  expect(find.byType(NeoSettingRow), findsWidgets);
  expect(find.text('Theme Mode'), findsOneWidget);
  expect(find.text('Language'), findsOneWidget);
});
```

Keep the existing bottom-sheet tests but update the expected opening action to tap `find.text('Language')` or `find.text('Theme Mode')`.

- [ ] **Step 4: Update about page tests for brand card and dialog**

In `test/widget/about_page_update_test.dart`:

1. Import `neo_components.dart`.
2. Add expectations:

```dart
expect(find.text('WindWalker'), findsOneWidget);
expect(find.byType(NeoSettingRow), findsWidgets);
expect(find.byType(NeoCard), findsWidgets);
```

Add a dialog test:

```dart
testWidgets('About page shows Neo update dialog when update is available', (tester) async {
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

  await tester.tap(find.text('Check for Updates'));
  await tester.pumpAndSettle();

  expect(find.text('Update Available'), findsOneWidget);
  expect(find.byType(NeoCard), findsWidgets);
});
```

- [ ] **Step 5: Run account/settings tests and verify they fail**

Run:

```bash
flutter test test/widget/profile_tab_update_badge_test.dart test/widget/login_page_test.dart test/widget/settings_page_test.dart test/widget/about_page_update_test.dart
```

Expected: FAIL because the pages still use old layouts.

- [ ] **Step 6: Rewrite `ProfileTab`**

In `lib/features/home/presentation/pages/profile_tab.dart`:

1. Remove `AppBar`.
2. Use `ListView` with top safe-area padding.
3. Render `NeoPageHeader(title: l10n.my, subtitle: ...)`.
4. Render a `NeoCard` account card with avatar, display name/email, and version/update meta.
5. Replace support/app `Card/ListTile` groups with `NeoSettingRow`.
6. Keep `_openPrivacyPolicy`, `_contactDeveloper`, `_shareApp`, settings route, and about route unchanged.

Use `FutureBuilder<String>(future: AppVersion.displayVersion(), ...)` inside the account meta or about row as it currently does.

- [ ] **Step 7: Rewrite `LoginPage`**

In `lib/features/auth/presentation/pages/login_page.dart`:

1. Remove the traditional `AppBar`.
2. Use `NeoPageHeader` with back action.
3. Render centered `NeoCard` brand login panel.
4. Keep authenticated redirect post-frame behavior.
5. Keep `auth.signInWithGoogle()` call.
6. Render `auth.errorMessage` in a soft error card above the Google button.
7. Keep terms notice text.

Use `NeoButton.primary` for Google login. If an icon is needed, pass a `Row(mainAxisSize: MainAxisSize.min, children: [...])` as the label.

- [ ] **Step 8: Rewrite `SettingsPage`**

In `lib/features/settings/presentation/pages/settings_page.dart`:

1. Remove traditional `AppBar`.
2. Use `NeoPageHeader(title: l10n.settings, subtitle: l10n.generalSettings, onBack: () => context.pop())`.
3. Replace `ListTile`s with `NeoSettingRow`.
4. Replace default `showModalBottomSheet` contents with a `NeoCard` sheet and `NeoChoicePill`/`NeoSettingRow` choices.
5. Replace sign-out `AlertDialog` with `Dialog(backgroundColor: Colors.transparent, child: NeoCard(...))`.
6. Keep controller calls:
   - `settings.setAppThemeMode(value)`
   - `settings.setAppLocale(value)`
   - `auth.signOut()`

- [ ] **Step 9: Rewrite `AboutPage`**

In `lib/features/settings/presentation/pages/about_page.dart`:

1. Remove traditional `AppBar`.
2. Use `NeoPageHeader(title: l10n.aboutWindWalker, subtitle: AppConstants.appName, onBack: () => context.pop())`.
3. Add a brand `NeoCard` with app name and version.
4. Replace `ListTile`s with `NeoSettingRow`.
5. Replace update `AlertDialog` with `Dialog(backgroundColor: Colors.transparent, child: NeoCard(...))`.
6. Keep `_checkForUpdates`, `UpdateController`, `ReviewManager().openStoreListing()`, Snackbar behavior, and update status mapping.

- [ ] **Step 10: Run account/settings tests**

Run:

```bash
flutter test test/widget/profile_tab_update_badge_test.dart test/widget/login_page_test.dart test/widget/settings_page_test.dart test/widget/about_page_update_test.dart
```

Expected: PASS.

- [ ] **Step 11: Commit account/settings flow rewrite**

```bash
git add lib/features/home/presentation/pages/profile_tab.dart lib/features/auth/presentation/pages/login_page.dart lib/features/settings/presentation/pages/settings_page.dart lib/features/settings/presentation/pages/about_page.dart test/widget/profile_tab_update_badge_test.dart test/widget/login_page_test.dart test/widget/settings_page_test.dart test/widget/about_page_update_test.dart
git commit -m "feat: rewrite account settings flow with neumorphic layout"
```

---

### Task 7: Final Integration and Regression

**Files:**
- Potentially modify files touched by Tasks 1-6 only if regression fixes are required.

- [ ] **Step 1: Format changed Dart files**

Run:

```bash
dart format lib/core/theme/neo_components.dart lib/features/add_task/presentation/pages/add_task_page.dart lib/features/home/presentation/pages/all_tasks_tab_page.dart lib/features/tasks/presentation/pages/tasks_page.dart lib/features/tasks/presentation/pages/task_detail_page.dart lib/features/downloaders/presentation/pages/downloader_editor_page.dart lib/features/downloaders/presentation/pages/downloader_config_page.dart lib/features/home/presentation/pages/profile_tab.dart lib/features/auth/presentation/pages/login_page.dart lib/features/settings/presentation/pages/settings_page.dart lib/features/settings/presentation/pages/about_page.dart test/widget/theme/neo_page_primitives_test.dart test/widget/add_task_page_test.dart test/widget/all_tasks_tab_shared_state_test.dart test/widget/tasks_page_shared_state_test.dart test/widget/task_detail_neumorphism_test.dart test/widget/downloader_editor_neumorphism_test.dart test/widget/downloader_config_neumorphism_test.dart test/widget/profile_tab_update_badge_test.dart test/widget/login_page_test.dart test/widget/settings_page_test.dart test/widget/about_page_update_test.dart
```

Expected: all files formatted.

- [ ] **Step 2: Run focused widget tests**

Run:

```bash
flutter test test/widget/theme/neo_page_primitives_test.dart test/widget/add_task_page_test.dart test/widget/all_tasks_tab_shared_state_test.dart test/widget/tasks_page_shared_state_test.dart test/widget/task_detail_neumorphism_test.dart test/widget/downloader_editor_neumorphism_test.dart test/widget/downloader_config_neumorphism_test.dart test/widget/profile_tab_update_badge_test.dart test/widget/login_page_test.dart test/widget/settings_page_test.dart test/widget/about_page_update_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run broader tests likely affected by shared UI**

Run:

```bash
flutter test test/widget/home_page_test.dart test/widget/home/neo_home_shell_test.dart test/widget/home/data_tab_neumorphism_test.dart test/widget/home/management_tab_neumorphism_test.dart test/widget/theme/neo_components_test.dart test/widget/theme/neumorphism_theme_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: PASS with no new analyzer errors.

- [ ] **Step 5: Fix any regression using the narrowest possible change**

If a test fails, inspect the exact failure and only change files from Tasks 1-6. Do not alter controller behavior, routes, models, or service APIs to make visual tests pass.

- [ ] **Step 6: Commit final polish**

If Step 5 changed files:

```bash
git add lib test
git commit -m "test: stabilize neumorphic page rewrite"
```

If Step 5 changed nothing, do not create an empty commit.
