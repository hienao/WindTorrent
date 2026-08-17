# Downloaders Tab Neumorphism Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 `design/v2/downloaders-tab-neumorphism-ui-mockup.html` 替换首页下载器 tab，并将首页公共 FAB 升级为 per-tab 可配置动作。

**Architecture:** `HomeTabContainer` 继续持有 tab index、初始化下载器和更新检查，新增当前 tab 的 `NeoHomeFabConfig` 映射。`NeoHomeShell` 只负责展示公共背景、底部 tab 和当前 FAB。`ManagementTab` 去掉独立 `Scaffold/AppBar/FAB`，只负责读取 `DownloaderController`、渲染拟物化下载器列表、触发现有路由和删除逻辑。

**Tech Stack:** Flutter 3.24.5, Material 3, Provider, go_router, flutter_test, existing `NeoThemeTokens` / `NeoCard` / `NeoSurface` primitives.

---

## File Structure

- Modify: `lib/features/home/presentation/widgets/neo_home_shell.dart`
  - 新增 `NeoHomeFabConfig`，把 `NeoHomeShell` 的 FAB 从 `showFab + onFabPressed` 改为 `fabConfig`。
- Modify: `lib/features/home/presentation/pages/home_tab_container.dart`
  - 根据 `_currentIndex` 提供总览/下载器不同 FAB 配置。
- Create: `lib/features/home/presentation/widgets/neo_downloader_widgets.dart`
  - 下载器 tab 专用拟物化组件：卡片、图标、badge、pill、更多菜单、删除弹窗、空态、加载态。
- Modify: `lib/features/home/presentation/pages/management_tab.dart`
  - 移除独立 `Scaffold/AppBar/FAB`，替换为拟物化页面内容。
- Modify: `test/widget/home/neo_home_shell_test.dart`
  - 更新公共 FAB 配置测试。
- Modify: `test/widget/home_page_test.dart`
  - 验证首页启动、总览 FAB、切到下载器后显示添加下载器 FAB。
- Modify: `test/widget/management_tab_version_badge_test.dart`
  - 适配新卡片，继续验证版本号与 `—`。
- Create: `test/widget/home/management_tab_neumorphism_test.dart`
  - 覆盖下载器 tab 标题、卡片字段、无速度/任务数、更多菜单、删除确认。
- Modify: `test/widget/test_helpers.dart`
  - 补充可记录 `removeDownloader` 调用的 mock controller。

## Public Interfaces

新增公共 FAB 配置：

```dart
@immutable
class NeoHomeFabConfig {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const NeoHomeFabConfig({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
}
```

`NeoHomeShell` 构造参数调整为：

```dart
class NeoHomeShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<NeoHomeTabItem> tabs;
  final List<Widget> children;
  final NeoHomeFabConfig? fabConfig;

  const NeoHomeShell({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.tabs,
    required this.children,
    this.fabConfig,
  });
}
```

`NeoHomeTabItem.showFab` 不再使用。第一阶段可以直接删除该字段并更新测试/调用点。

新增下载器卡片接口：

```dart
class NeoDownloaderCard extends StatelessWidget {
  final Downloader downloader;
  final String statusLabel;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenConfig;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NeoDownloaderCard({
    super.key,
    required this.downloader,
    required this.statusLabel,
    required this.onOpenTasks,
    required this.onOpenConfig,
    required this.onEdit,
    required this.onDelete,
  });
}
```

---

### Task 1: Test Per-Tab FAB Contract

**Files:**
- Modify: `test/widget/home/neo_home_shell_test.dart`

- [ ] **Step 1: Update the failing shell tests**

Replace the current `tabs` list in `test/widget/home/neo_home_shell_test.dart` with:

```dart
const tabs = [
  NeoHomeTabItem(
    label: '总览',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    semanticsLabel: '总览',
  ),
  NeoHomeTabItem(
    label: '下载器',
    icon: Icons.storage_outlined,
    selectedIcon: Icons.storage,
    semanticsLabel: '下载器',
  ),
];
```

Replace `buildSubject` with:

```dart
Widget buildSubject({
  int selectedIndex = 0,
  required ValueChanged<int> onTabSelected,
  NeoHomeFabConfig? fabConfig,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    home: NeoHomeShell(
      selectedIndex: selectedIndex,
      onTabSelected: onTabSelected,
      tabs: tabs,
      fabConfig: fabConfig,
      children: const [
        Center(child: Text('Overview body')),
        Center(child: Text('Downloaders body')),
      ],
    ),
  );
}
```

Replace the existing FAB test with:

```dart
testWidgets('uses the provided FAB config for tooltip, icon and tap', (
  tester,
) async {
  var tapped = false;
  await tester.pumpWidget(
    buildSubject(
      onTabSelected: (_) {},
      fabConfig: NeoHomeFabConfig(
        tooltip: '添加下载器',
        icon: Icons.add_rounded,
        onPressed: () => tapped = true,
      ),
    ),
  );

  expect(find.byTooltip('添加下载器'), findsOneWidget);
  expect(find.byIcon(Icons.add_rounded), findsOneWidget);

  await tester.tap(find.byTooltip('添加下载器'));
  expect(tapped, isTrue);
});

testWidgets('hides FAB when fabConfig is null', (tester) async {
  await tester.pumpWidget(
    buildSubject(
      selectedIndex: 1,
      onTabSelected: (_) {},
    ),
  );

  expect(find.byTooltip('添加下载器'), findsNothing);
  expect(find.byIcon(Icons.add_rounded), findsNothing);
});
```

- [ ] **Step 2: Run the shell test to verify it fails**

Run:

```bash
flutter test test/widget/home/neo_home_shell_test.dart
```

Expected: FAIL because `NeoHomeFabConfig` does not exist and `NeoHomeShell` does not accept `fabConfig`.

- [ ] **Step 3: Commit the failing test**

```bash
git add test/widget/home/neo_home_shell_test.dart
git commit -m "test: define per-tab home fab contract"
```

---

### Task 2: Implement Per-Tab FAB Config

**Files:**
- Modify: `lib/features/home/presentation/widgets/neo_home_shell.dart`
- Modify: `lib/features/home/presentation/pages/home_tab_container.dart`
- Modify: `test/widget/home_page_test.dart`

- [ ] **Step 1: Add `NeoHomeFabConfig` and update `NeoHomeShell`**

In `lib/features/home/presentation/widgets/neo_home_shell.dart`, add after imports:

```dart
@immutable
class NeoHomeFabConfig {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const NeoHomeFabConfig({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
}
```

Remove `showFab` from `NeoHomeTabItem`:

```dart
@immutable
class NeoHomeTabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String semanticsLabel;

  const NeoHomeTabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.semanticsLabel,
  });
}
```

Replace `NeoHomeShell` fields:

```dart
final NeoHomeFabConfig? fabConfig;
```

Replace constructor parameters:

```dart
this.fabConfig,
```

Remove:

```dart
final VoidCallback? onFabPressed;
final String? fabTooltip;
```

Replace the `floatingActionButton` expression with:

```dart
floatingActionButton: fabConfig == null
    ? null
    : NeoHomeFab(
        onPressed: fabConfig!.onPressed,
        tooltip: fabConfig!.tooltip,
        icon: fabConfig!.icon,
      ),
```

Remove the unused `currentTab` local variable.

- [ ] **Step 2: Update `NeoHomeFab` to accept an icon**

Change `NeoHomeFab`:

```dart
class NeoHomeFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  const NeoHomeFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.icon,
  });
```

Replace:

```dart
final message = tooltip ?? '添加任务';
```

with:

```dart
final message = tooltip;
```

Replace the child icon:

```dart
child: Icon(icon, color: Colors.white, size: 32),
```

- [ ] **Step 3: Add a FAB config resolver in HomeTabContainer**

In `lib/features/home/presentation/pages/home_tab_container.dart`, add a private method inside `_HomeTabContainerState`:

```dart
NeoHomeFabConfig? _fabConfigForIndex(
  BuildContext context,
  AppLocalizations l10n,
) {
  switch (_currentIndex) {
    case 0:
      return NeoHomeFabConfig(
        tooltip: l10n.addTaskButton,
        icon: Icons.add_rounded,
        onPressed: () => context.push(AppConstants.addTaskRoute),
      );
    case 1:
      return NeoHomeFabConfig(
        tooltip: l10n.addDownloader,
        icon: Icons.add_rounded,
        onPressed: () => context.push('/downloaders/new'),
      );
    default:
      return null;
  }
}
```

Update `NeoHomeShell` call:

```dart
fabConfig: _fabConfigForIndex(context, l10n),
```

Remove:

```dart
onFabPressed: () => context.push(AppConstants.addTaskRoute),
fabTooltip: l10n.addTaskButton,
```

Remove `showFab: true` from the overview tab item.

- [ ] **Step 4: Update home page test for downloader FAB**

In `test/widget/home_page_test.dart`, add a test:

```dart
testWidgets('shows add downloader FAB on downloaders tab', (tester) async {
  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      taskController: taskController,
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));

  final l10n = AppLocalizations.of(
    tester.element(find.byType(Scaffold).first),
  )!;

  await tester.tap(find.text(l10n.downloadersTab));
  await tester.pumpAndSettle();

  expect(find.byTooltip(l10n.addDownloader), findsOneWidget);
  expect(find.byTooltip(l10n.addTaskButton), findsNothing);

  await tester.pump(const Duration(milliseconds: 300));
  taskController.stopAutoRefresh();
});
```

- [ ] **Step 5: Run shell and home tests**

Run:

```bash
flutter test test/widget/home/neo_home_shell_test.dart test/widget/home_page_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit per-tab FAB implementation**

```bash
git add lib/features/home/presentation/widgets/neo_home_shell.dart lib/features/home/presentation/pages/home_tab_container.dart test/widget/home/neo_home_shell_test.dart test/widget/home_page_test.dart
git commit -m "feat: support per-tab home fab actions"
```

---

### Task 3: Test Downloader Neumorphism Widgets

**Files:**
- Create: `test/widget/home/management_tab_neumorphism_test.dart`
- Modify: `test/widget/test_helpers.dart`

- [ ] **Step 1: Add delete tracking to mock controller**

In `test/widget/test_helpers.dart`, inside `MockDownloaderController`, add:

```dart
String? removedDownloaderId;
```

Replace:

```dart
@override
Future<void> removeDownloader(String id) async {}
```

with:

```dart
@override
Future<void> removeDownloader(String id) async {
  removedDownloaderId = id;
}
```

- [ ] **Step 2: Write management tab neumorphism tests**

Create `test/widget/home/management_tab_neumorphism_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_downloader_widgets.dart';
import 'package:windwalker/features/tasks/presentation/pages/tasks_page.dart';

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

  group('Neumorphic ManagementTab', () {
    late MockDownloaderController downloaderController;

    setUp(() {
      downloaderController = MockDownloaderController();
      downloaderController.testDownloaders = [
        createTestDownloader(
          id: 'aria',
          name: 'NAS Aria2',
          type: DownloaderType.aria2,
          host: '192.168.1.8',
          port: 6800,
          status: DownloaderStatus.online,
          version: '1.37.0',
          taskCount: 9,
          downloadSpeed: 1048576,
        ),
      ];
    });

    testWidgets('renders neumorphic downloader page without internal scaffold chrome', (tester) async {
      await tester.pumpWidget(
        createTestApp(downloaderController: downloaderController),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Downloaders'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('下载器'), findsOneWidget);
      expect(find.text('管理已配置的下载器'), findsOneWidget);
      expect(find.text('已配置下载器'), findsOneWidget);
      expect(find.byType(NeoDownloaderCard), findsOneWidget);
    });

    testWidgets('card shows identity metadata and hides speed and task count', (tester) async {
      await tester.pumpWidget(
        createTestApp(downloaderController: downloaderController),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Downloaders'));
      await tester.pumpAndSettle();

      expect(find.text('NAS Aria2'), findsOneWidget);
      expect(find.text('192.168.1.8:6800'), findsOneWidget);
      expect(find.text('Aria2'), findsOneWidget);
      expect(find.text('1.37.0'), findsOneWidget);
      expect(find.text('HTTP'), findsOneWidget);
      expect(find.text('online'), findsNothing);
      expect(find.text('9 个任务'), findsNothing);
      expect(find.text('1.0 MB/s'), findsNothing);
    });

    testWidgets('more menu exposes edit and delete actions', (tester) async {
      await tester.pumpWidget(
        createTestApp(downloaderController: downloaderController),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Downloaders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();

      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('delete confirmation calls removeDownloader', (tester) async {
      await tester.pumpWidget(
        createTestApp(downloaderController: downloaderController),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Downloaders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.byType(NeoDownloaderDeleteDialog), findsOneWidget);

      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(downloaderController.removedDownloaderId, 'aria');
    });

    testWidgets('tasks action opens downloader scoped tasks page', (tester) async {
      await tester.pumpWidget(
        createTestApp(downloaderController: downloaderController),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Downloaders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('任务'));
      await tester.pumpAndSettle();

      expect(find.byType(TasksPage), findsOneWidget);
    });
  });
}
```

- [ ] **Step 3: Run new downloader test to verify it fails**

Run:

```bash
flutter test test/widget/home/management_tab_neumorphism_test.dart
```

Expected: FAIL because `neo_downloader_widgets.dart`, `NeoDownloaderCard`, and `NeoDownloaderDeleteDialog` do not exist, and `ManagementTab` still uses the old UI.

- [ ] **Step 4: Commit failing downloader tests**

```bash
git add test/widget/test_helpers.dart test/widget/home/management_tab_neumorphism_test.dart
git commit -m "test: define neumorphic downloader tab contract"
```

---

### Task 4: Implement Downloader Widgets

**Files:**
- Create: `lib/features/home/presentation/widgets/neo_downloader_widgets.dart`

- [ ] **Step 1: Create widget file imports and helpers**

Create `lib/features/home/presentation/widgets/neo_downloader_widgets.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/core/theme/neo_theme_extension.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/models/downloader.dart';
```

Add helper functions:

```dart
String downloaderProtocolLabel(Downloader downloader) {
  return downloader.useHttps ? 'HTTPS' : 'HTTP';
}

String downloaderVersionLabel(Downloader downloader) {
  final version = downloader.version;
  return version == null || version.isEmpty ? '—' : version;
}

Color downloaderStatusColor(DownloaderStatus status) {
  switch (status) {
    case DownloaderStatus.online:
      return AppColors.success;
    case DownloaderStatus.error:
      return AppColors.error;
    case DownloaderStatus.offline:
      return AppColors.offline;
  }
}
```

- [ ] **Step 2: Add type icon, status badge, and info pill**

Add:

```dart
class NeoDownloaderTypeIcon extends StatelessWidget {
  final DownloaderType type;
  final double size;

  const NeoDownloaderTypeIcon({
    super.key,
    required this.type,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.38;
    final colors = switch (type) {
      DownloaderType.aria2 => const [Color(0xFFF39A33), Color(0xFFFFBE67)],
      DownloaderType.qbittorrent => const [Color(0xFF3DBB52), Color(0xFF72DC82)],
      DownloaderType.transmission => const [Color(0xFFD9413F), Color(0xFFFF746F)],
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(child: _DownloaderTypeGlyph(type: type, size: size)),
    );
  }
}
```

Add `_DownloaderTypeGlyph` as a private widget:

```dart
class _DownloaderTypeGlyph extends StatelessWidget {
  final DownloaderType type;
  final double size;

  const _DownloaderTypeGlyph({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case DownloaderType.aria2:
        return Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'a²',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            Positioned(
              bottom: size * 0.18,
              left: size * 0.2,
              right: size * 0.2,
              child: Column(
                children: [
                  Container(height: 3, decoration: _whiteLineDecoration(0.52)),
                  const SizedBox(height: 5),
                  Container(height: 3, decoration: _whiteLineDecoration(0.72)),
                ],
              ),
            ),
          ],
        );
      case DownloaderType.qbittorrent:
        return Container(
          width: size * 0.58,
          height: size * 0.58,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            'q',
            style: TextStyle(
              color: const Color(0xFF319D43),
              fontSize: size * 0.4,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        );
      case DownloaderType.transmission:
        return CustomPaint(
          size: Size.square(size * 0.58),
          painter: _TransmissionGlyphPainter(),
        );
    }
  }

  BoxDecoration _whiteLineDecoration(double alpha) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(999),
    );
  }
}
```

Add `_TransmissionGlyphPainter`:

```dart
class _TransmissionGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.1, 0)
      ..lineTo(size.width * 0.9, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

Add `NeoDownloaderStatusBadge` and `NeoDownloaderInfoPill`:

```dart
class NeoDownloaderStatusBadge extends StatelessWidget {
  final String label;
  final DownloaderStatus status;

  const NeoDownloaderStatusBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = downloaderStatusColor(status);
    return NeoBadge(
      label: label,
      backgroundColor: color.withValues(alpha: 0.12),
      foregroundColor: color,
    );
  }
}

class NeoDownloaderInfoPill extends StatelessWidget {
  final String label;

  const NeoDownloaderInfoPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.recessedSurface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowColor.withValues(alpha: tokens.isDark ? 0.32 : 0.18),
            offset: const Offset(3, 3),
            blurRadius: 7,
          ),
          BoxShadow(
            color: tokens.highlightColor.withValues(alpha: tokens.isDark ? 0.035 : 0.72),
            offset: const Offset(-3, -3),
            blurRadius: 7,
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add card, menu, dialog, empty and loading widgets**

Add `NeoDownloaderCard`:

```dart
class NeoDownloaderCard extends StatelessWidget {
  final Downloader downloader;
  final String statusLabel;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenConfig;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NeoDownloaderCard({
    super.key,
    required this.downloader,
    required this.statusLabel,
    required this.onOpenTasks,
    required this.onOpenConfig,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return NeoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeoDownloaderTypeIcon(type: downloader.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      downloader.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${downloader.host}:${downloader.port}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              NeoDownloaderStatusBadge(
                label: statusLabel,
                status: downloader.status,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NeoDownloaderInfoPill(label: downloader.type.label),
              NeoDownloaderInfoPill(label: downloaderVersionLabel(downloader)),
              NeoDownloaderInfoPill(label: downloaderProtocolLabel(downloader)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _NeoDownloaderActionButton(
                  label: '任务',
                  isPrimary: true,
                  onTap: onOpenTasks,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _NeoDownloaderActionButton(
                  label: l10n.config,
                  onTap: onOpenConfig,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: NeoDownloaderMoreMenu(
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

Add `_NeoDownloaderActionButton` and `NeoDownloaderMoreMenu`:

```dart
class _NeoDownloaderActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _NeoDownloaderActionButton({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NeoThemeTokens>()!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.raisedSurface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: tokens.highlightColor.withValues(alpha: tokens.isDark ? 0.04 : 0.75),
              offset: const Offset(-3, -3),
              blurRadius: 8,
            ),
            BoxShadow(
              color: tokens.shadowColor.withValues(alpha: tokens.isDark ? 0.28 : 0.24),
              offset: const Offset(4, 4),
              blurRadius: 9,
            ),
          ],
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isPrimary ? tokens.primaryAccent : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class NeoDownloaderMoreMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NeoDownloaderMoreMenu({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      tooltip: '更多',
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
        PopupMenuItem(
          value: 'delete',
          child: Text(l10n.delete, style: const TextStyle(color: AppColors.error)),
        ),
      ],
      child: _NeoDownloaderActionButton(
        label: '更多',
        onTap: () {},
      ),
    );
  }
}
```

Note: If `PopupMenuButton` child swallows tap because `_NeoDownloaderActionButton` has its own `GestureDetector`, replace the child with a non-gestural `Container` using the same decoration. The visible label must remain `更多`.

Add delete dialog:

```dart
class NeoDownloaderDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelLabel;
  final String deleteLabel;

  const NeoDownloaderDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: NeoSurface(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(cancelLabel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(deleteLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Add empty and loading states:

```dart
class NeoDownloaderEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const NeoDownloaderEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return NeoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class NeoDownloaderLoadingState extends StatelessWidget {
  const NeoDownloaderLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.xxxl),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
```

- [ ] **Step 4: Format and analyze the widget file**

Run:

```bash
dart format lib/features/home/presentation/widgets/neo_downloader_widgets.dart
flutter analyze
```

Expected: no analyzer errors introduced by the new widget file.

- [ ] **Step 5: Commit downloader widgets**

```bash
git add lib/features/home/presentation/widgets/neo_downloader_widgets.dart
git commit -m "feat: add neumorphic downloader widgets"
```

---

### Task 5: Replace ManagementTab Layout

**Files:**
- Modify: `lib/features/home/presentation/pages/management_tab.dart`
- Modify: `test/widget/management_tab_version_badge_test.dart`

- [ ] **Step 1: Replace ManagementTab imports**

In `lib/features/home/presentation/pages/management_tab.dart`, remove:

```dart
import 'package:windwalker/core/theme/app_theme.dart';
```

Add:

```dart
import 'package:windwalker/core/theme/neo_components.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_downloader_widgets.dart';
```

- [ ] **Step 2: Replace `build` with embedded page content**

Replace the current `return Scaffold(...)` in `build` with:

```dart
return Consumer<DownloaderController>(
  builder: (context, controller, _) {
    return RefreshIndicator(
      onRefresh: controller.loadDownloaders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          ResponsiveLayout.getPadding(context).left,
          MediaQuery.paddingOf(context).top + AppSpacing.lg,
          ResponsiveLayout.getPadding(context).right,
          120,
        ),
        children: [
          _Header(title: l10n.downloadersTab, subtitle: '管理已配置的下载器'),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(label: '已配置下载器'),
          const SizedBox(height: AppSpacing.md),
          if (controller.isLoading)
            const NeoDownloaderLoadingState()
          else if (controller.downloaders.isEmpty)
            NeoDownloaderEmptyState(
              title: l10n.noDownloadersYet,
              subtitle: l10n.addDownloaderHint,
            )
          else
            ...controller.downloaders.map(
              (downloader) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: NeoDownloaderCard(
                  downloader: downloader,
                  statusLabel: downloader.status.localizedLabel(context),
                  onOpenTasks: () => context.push(
                    '/tasks?id=${downloader.id}&type=${downloader.type.name}',
                  ),
                  onOpenConfig: () =>
                      context.push('/downloaders/${downloader.id}/config'),
                  onEdit: () =>
                      context.push('/downloaders/${downloader.id}/edit'),
                  onDelete: () => _confirmDelete(context, downloader),
                ),
              ),
            ),
        ],
      ),
    );
  },
);
```

- [ ] **Step 3: Add private header and section title widgets**

Add below `_ManagementTabState`:

```dart
class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
```

- [ ] **Step 4: Replace delete dialog**

Replace `_confirmDelete` with:

```dart
Future<void> _confirmDelete(
  BuildContext context,
  Downloader downloader,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => NeoDownloaderDeleteDialog(
      title: l10n.deleteDownloader,
      message: l10n.confirmDeleteDownloader,
      cancelLabel: l10n.cancel,
      deleteLabel: l10n.delete,
    ),
  );

  if (confirmed != true || !context.mounted) return;
  await context.read<DownloaderController>().removeDownloader(downloader.id);
}
```

- [ ] **Step 5: Remove old private card/badge widgets**

Delete these private classes from `management_tab.dart`:

```dart
_DownloaderCard
_StatusBadge
_VersionBadge
```

Delete `_statusColor`, because status color now lives in `neo_downloader_widgets.dart`.

- [ ] **Step 6: Update version badge test harness theme**

In `test/widget/management_tab_version_badge_test.dart`, add:

```dart
import 'package:windwalker/core/theme/app_theme.dart';
```

In `MaterialApp`, add:

```dart
theme: AppTheme.lightTheme,
darkTheme: AppTheme.darkTheme,
```

Keep the existing expectations:

```dart
expect(find.text('1.36.0'), findsOneWidget);
expect(find.text('—'), findsOneWidget);
```

- [ ] **Step 7: Run management tests**

Run:

```bash
flutter test test/widget/management_tab_version_badge_test.dart test/widget/home/management_tab_neumorphism_test.dart
```

Expected: PASS. If the new test that asserts `'online'` fails due to localized text, remove that assertion and instead assert the localized status text appears once.

- [ ] **Step 8: Commit management tab replacement**

```bash
git add lib/features/home/presentation/pages/management_tab.dart test/widget/management_tab_version_badge_test.dart test/widget/home/management_tab_neumorphism_test.dart test/widget/test_helpers.dart
git commit -m "feat: replace downloader tab with neumorphic layout"
```

---

### Task 6: Route and FAB Regression Tests

**Files:**
- Modify: `test/widget/test_helpers.dart`
- Modify: `test/widget/home_page_test.dart`
- Modify: `test/widget/home/management_tab_neumorphism_test.dart`

- [ ] **Step 1: Add missing routes to `createTestApp` if route assertions need them**

In `test/widget/test_helpers.dart`, add imports if absent:

```dart
import 'package:windwalker/features/downloaders/presentation/pages/downloader_config_page.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_editor_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/tasks_page.dart';
```

Add routes to the test router:

```dart
GoRoute(
  path: '/tasks',
  name: 'tasks',
  builder: (context, state) {
    final downloaderId = state.uri.queryParameters['id'];
    final downloaderTypeStr = state.uri.queryParameters['type'];
    final downloaderType = downloaderTypeStr != null
        ? DownloaderType.values.firstWhere(
            (e) => e.name == downloaderTypeStr,
            orElse: () => DownloaderType.aria2,
          )
        : null;
    return TasksPage(
      downloaderId: downloaderId,
      downloaderType: downloaderType,
    );
  },
),
GoRoute(
  path: '/downloaders/new',
  name: 'downloader-create',
  builder: (context, state) => const DownloaderEditorPage(),
),
GoRoute(
  path: '/downloaders/:id/edit',
  name: 'downloader-edit',
  builder: (context, state) =>
      DownloaderEditorPage(downloaderId: state.pathParameters['id']),
),
GoRoute(
  path: '/downloaders/:id/config',
  name: 'downloader-config',
  builder: (context, state) =>
      DownloaderConfigPage(downloaderId: state.pathParameters['id']!),
),
```

Do not duplicate a route if it already exists.

- [ ] **Step 2: Add add-downloader FAB navigation test**

In `test/widget/home_page_test.dart`, add:

```dart
testWidgets('add downloader FAB opens downloader editor from downloaders tab', (
  tester,
) async {
  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      taskController: taskController,
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));

  final l10n = AppLocalizations.of(
    tester.element(find.byType(Scaffold).first),
  )!;

  await tester.tap(find.text(l10n.downloadersTab));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip(l10n.addDownloader));
  await tester.pumpAndSettle();

  expect(find.text(l10n.addDownloaderTitle), findsOneWidget);

  await tester.pump(const Duration(milliseconds: 300));
  taskController.stopAutoRefresh();
});
```

- [ ] **Step 3: Add config/edit route tests if not covered**

In `test/widget/home/management_tab_neumorphism_test.dart`, add:

```dart
testWidgets('config action opens downloader config page', (tester) async {
  await tester.pumpWidget(
    createTestApp(downloaderController: downloaderController),
  );
  await tester.pump(const Duration(milliseconds: 300));

  await tester.tap(find.text('Downloaders'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('配置'));
  await tester.pumpAndSettle();

  expect(find.text('NAS Aria2'), findsWidgets);
});

testWidgets('edit action from more menu opens downloader editor', (tester) async {
  await tester.pumpWidget(
    createTestApp(downloaderController: downloaderController),
  );
  await tester.pump(const Duration(milliseconds: 300));

  await tester.tap(find.text('Downloaders'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('更多'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('编辑'));
  await tester.pumpAndSettle();

  expect(find.text('Edit Downloader'), findsOneWidget);
});
```

If localized locale is English in `createTestApp`, use English assertions as above. If tests use Chinese locale, assert `编辑下载器`.

- [ ] **Step 4: Run route regression tests**

Run:

```bash
flutter test test/widget/home_page_test.dart test/widget/home/management_tab_neumorphism_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit regression coverage**

```bash
git add test/widget/test_helpers.dart test/widget/home_page_test.dart test/widget/home/management_tab_neumorphism_test.dart
git commit -m "test: cover downloader tab fab and routes"
```

---

### Task 7: Final Verification

**Files:**
- Modify as needed: files changed by Tasks 1-6

- [ ] **Step 1: Format changed Dart files**

Run:

```bash
dart format lib/features/home/presentation/widgets/neo_home_shell.dart lib/features/home/presentation/pages/home_tab_container.dart lib/features/home/presentation/widgets/neo_downloader_widgets.dart lib/features/home/presentation/pages/management_tab.dart test/widget/home/neo_home_shell_test.dart test/widget/home_page_test.dart test/widget/home/management_tab_neumorphism_test.dart test/widget/management_tab_version_badge_test.dart test/widget/test_helpers.dart
```

Expected: formatter exits with code 0.

- [ ] **Step 2: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Run focused widget tests**

Run:

```bash
flutter test test/widget/home/neo_home_shell_test.dart test/widget/home_page_test.dart test/widget/management_tab_version_badge_test.dart test/widget/home/management_tab_neumorphism_test.dart test/widget/home/data_tab_neumorphism_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run broader widget tests**

Run:

```bash
flutter test test/widget
```

Expected: PASS. If unrelated pre-existing failures appear, record failing test names and confirm they do not touch changed files.

- [ ] **Step 5: Manual visual check**

Run the app and verify:

```text
1. 首页切到“下载器”tab 后，底部 tab 和总览页保持同一公共样式。
2. 下载器 tab 的 FAB tooltip/语义是“添加下载器”，点击进入添加下载器页。
3. 下载器 tab 顶部不显示右上角添加按钮。
4. 下载器卡片不展示下载速度、上传速度、任务数量。
5. 下载器卡片展示名称、host:port、状态、类型、版本、HTTP/HTTPS。
6. “任务 / 配置 / 更多”三个操作存在。
7. 更多菜单显示“编辑 / 删除”，删除为危险色。
8. 删除确认弹窗使用拟物化样式，确认后删除下载器。
9. 下拉刷新仍可触发 loadDownloaders。
10. 浅色和深色主题下卡片、菜单、弹窗可读。
```

- [ ] **Step 6: Final commit if polish changed files**

If Task 7 introduced any changes:

```bash
git add lib/features/home/presentation/widgets/neo_home_shell.dart lib/features/home/presentation/pages/home_tab_container.dart lib/features/home/presentation/widgets/neo_downloader_widgets.dart lib/features/home/presentation/pages/management_tab.dart test/widget/home/neo_home_shell_test.dart test/widget/home_page_test.dart test/widget/home/management_tab_neumorphism_test.dart test/widget/management_tab_version_badge_test.dart test/widget/test_helpers.dart
git commit -m "test: verify downloader tab neumorphism replacement"
```

If Task 7 only ran verification and no files changed, do not create an empty commit.

---

## Self-Review

**Spec coverage:**  
The plan covers the confirmed scope: per-tab FAB in `NeoHomeShell`, downloader tab replacement, no internal add button, no speed/task count on cards, `任务 / 配置 / 更多`, more menu with edit/delete, neumorphic delete dialog, retained routes, retained pull-to-refresh, missing-version display, empty/loading states, and regression tests.

**Placeholder scan:**  
The plan avoids vague work items. Commands, file paths, public interfaces, test snippets, and implementation snippets are explicit. One conditional note is included for `PopupMenuButton` tap handling because Flutter child gesture interaction can vary; it gives a concrete fallback and preserves the visible contract.

**Type consistency:**  
`NeoHomeFabConfig`, `NeoHomeShell.fabConfig`, `NeoHomeFab.icon`, `NeoDownloaderCard`, `NeoDownloaderTypeIcon`, `NeoDownloaderStatusBadge`, `NeoDownloaderInfoPill`, `NeoDownloaderMoreMenu`, `NeoDownloaderDeleteDialog`, `NeoDownloaderEmptyState`, and `NeoDownloaderLoadingState` are used consistently across tasks.
