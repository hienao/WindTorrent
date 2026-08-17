# 下载器类型图标统一 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把管理页卡片、添加任务页、概览列表中的下载器类型图标统一成同一套共享组件，并让 `qBittorrent`、`Transmission`、`Aria2` 分别符合已确认的识别方向。

**Architecture:** 新建一个共享的下载器类型图标组件，内部用向量绘制三种下载器图形，外层容器尺寸与留白统一。现有页面不再各自维护 `IconData` 映射，而是通过共享组件接入；为此扩展 `NeoStatusHeroCard` 和 `NeoSettingRow`，让它们既兼容旧的 `IconData` 用法，也能接收自定义 leading widget。

**Tech Stack:** Flutter、Provider、CustomPainter、flutter_test

---

## 文件结构

- 新建：`/Volumes/Data/Code/GitHub/WindWalker/lib/features/downloaders/presentation/widgets/downloader_type_icon.dart`
  - 统一承载三种下载器图标的容器、尺寸规则、向量绘制逻辑。
- 新建：`/Volumes/Data/Code/GitHub/WindWalker/test/widget/downloader_type_icon_test.dart`
  - 验证共享图标组件在三种类型、三种尺寸下都能正常渲染，并暴露稳定的 key 供页面级测试复用。

- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/core/theme/neo_components.dart`
  - 让 `NeoStatusHeroCard` 与 `NeoSettingRow` 支持自定义 `leading` widget，同时保留原有 `icon` 入参兼容现有调用方。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/test/widget/theme/neo_page_primitives_test.dart`
  - 为两个基础组件补“支持自定义 leading”的回归测试。

- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/features/home/presentation/widgets/neo_downloader_widgets.dart`
  - 删除旧的本地下载器图标绘制实现，改为复用共享图标组件。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/features/downloaders/presentation/pages/downloader_editor_page.dart`
  - 下载器类型选择项改为引用共享图标组件，避免未来再次分叉。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/test/widget/home/management_tab_neumorphism_test.dart`
  - 验证管理页卡片已经使用共享图标组件。

- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/features/add_task/presentation/pages/add_task_page.dart`
  - 已选下载器卡片与下载器选择列表都改用共享图标组件，移除本地 `IconData` 映射。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/features/home/presentation/widgets/neo_overview_widgets.dart`
  - 概览列表下载器行由通用 `storage` 图标切换到共享图标组件。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/test/widget/add_task_page_test.dart`
  - 验证添加任务页的已选卡片和选择列表使用的是共享图标，而不是通用 Material 图标。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/test/widget/home/data_tab_neumorphism_test.dart`
  - 验证概览列表中的下载器行已经切换为类型图标族。

## 任务 1：新建共享下载器图标组件

**Files:**
- Create: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/downloaders/presentation/widgets/downloader_type_icon.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/downloader_type_icon_test.dart`

- [ ] **Step 1: 先写失败的共享图标组件测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/downloaders/presentation/widgets/downloader_type_icon.dart';
import 'package:windwalker/models/downloader.dart';

void main() {
  testWidgets('renders all downloader type icons with stable keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            DownloaderTypeIcon(
              type: DownloaderType.aria2,
              size: DownloaderTypeIconSize.large,
            ),
            DownloaderTypeIcon(
              type: DownloaderType.qbittorrent,
              size: DownloaderTypeIconSize.medium,
            ),
            DownloaderTypeIcon(
              type: DownloaderType.transmission,
              size: DownloaderTypeIconSize.small,
            ),
          ],
        ),
      ),
    );

    expect(
      find.byKey(const Key('downloader-type-icon-aria2-large')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('downloader-type-icon-qbittorrent-medium')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('downloader-type-icon-transmission-small')),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: 运行测试，确认组件还不存在时先失败**

Run:

```bash
flutter test test/widget/downloader_type_icon_test.dart
```

Expected:

```text
Compilation failed because DownloaderTypeIcon / DownloaderTypeIconSize is undefined.
```

- [ ] **Step 3: 用最小实现补齐共享图标组件**

在 `downloader_type_icon.dart` 创建共享组件与尺寸枚举：

```dart
import 'package:flutter/material.dart';
import 'package:windwalker/models/downloader.dart';

enum DownloaderTypeIconSize { small, medium, large }

class DownloaderTypeIcon extends StatelessWidget {
  final DownloaderType type;
  final DownloaderTypeIconSize size;

  const DownloaderTypeIcon({
    super.key,
    required this.type,
    this.size = DownloaderTypeIconSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _IconMetrics.fromSize(size);
    return Container(
      key: Key('downloader-type-icon-${type.name}-${size.name}'),
      width: metrics.tile,
      height: metrics.tile,
      padding: EdgeInsets.all(metrics.padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(metrics.radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FBFD), Color(0xFFE2EAEE)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F6A7984),
            offset: Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: switch (type) {
        DownloaderType.aria2 => CustomPaint(painter: Aria2GlyphPainter()),
        DownloaderType.qbittorrent =>
          CustomPaint(painter: QBittorrentGlyphPainter()),
        DownloaderType.transmission =>
          CustomPaint(painter: TransmissionGlyphPainter()),
      },
    );
  }
}
```

同文件继续补齐尺寸模型与三种 painter，关键约束如下：

```dart
class _IconMetrics {
  final double tile;
  final double radius;
  final double padding;

  const _IconMetrics(this.tile, this.radius, this.padding);

  factory _IconMetrics.fromSize(DownloaderTypeIconSize size) {
    return switch (size) {
      DownloaderTypeIconSize.large => const _IconMetrics(48, 16, 6),
      DownloaderTypeIconSize.medium => const _IconMetrics(44, 14, 5),
      DownloaderTypeIconSize.small => const _IconMetrics(28, 10, 3.5),
    };
  }
}

class QBittorrentGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF25B2F3), Color(0xFF1E73F2)],
      ).createShader(Offset.zero & size);
    final shell = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.22),
    );
    canvas.drawRRect(shell, bg);

    final qb = Path()
      ..moveTo(size.width * 0.23, size.height * 0.34)
      ..arcToPoint(
        Offset(size.width * 0.23, size.height * 0.66),
        radius: Radius.circular(size.width * 0.16),
        clockwise: false,
      )
      ..lineTo(size.width * 0.46, size.height * 0.66)
      ..lineTo(size.width * 0.46, size.height * 0.80)
      ..lineTo(size.width * 0.58, size.height * 0.80)
      ..lineTo(size.width * 0.58, size.height * 0.34)
      ..arcToPoint(
        Offset(size.width * 0.77, size.height * 0.34),
        radius: Radius.circular(size.width * 0.16),
      )
      ..arcToPoint(
        Offset(size.width * 0.77, size.height * 0.66),
        radius: Radius.circular(size.width * 0.16),
      )
      ..lineTo(size.width * 0.58, size.height * 0.66)
      ..lineTo(size.width * 0.58, size.height * 0.52)
      ..lineTo(size.width * 0.35, size.height * 0.52)
      ..lineTo(size.width * 0.35, size.height * 0.34)
      ..close();
    canvas.drawPath(
      qb,
      Paint()..color = const Color(0xFFF6F9FC),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

实现要求：

- `qBittorrent` 用蓝色圆角方底 + 一体化白色 `qb` 轮廓
- `Transmission` 用红色握把 + 金属 `T` + 深色向下箭头
- `Aria2` 用字标式 `A + 2` 识别，不退化为通用下载箭头

- [ ] **Step 4: 重新运行共享图标测试**

Run:

```bash
flutter test test/widget/downloader_type_icon_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交共享图标组件**

```bash
git add \
  lib/features/downloaders/presentation/widgets/downloader_type_icon.dart \
  test/widget/downloader_type_icon_test.dart
git commit -m "feat: add shared downloader type icon widget"
```

## 任务 2：扩展基础组件以支持自定义 leading

**Files:**
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/core/theme/neo_components.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/theme/neo_page_primitives_test.dart`

- [ ] **Step 1: 先写失败的基础组件回归测试**

在 `neo_page_primitives_test.dart` 增加两个测试：

```dart
testWidgets('NeoStatusHeroCard supports custom leading widget', (tester) async {
  await tester.pumpWidget(
    buildSubject(
      const NeoStatusHeroCard(
        leading: ColoredBox(
          key: Key('hero-leading'),
          color: Colors.teal,
        ),
        title: 'NAS qB',
        subtitle: 'qBittorrent',
      ),
    ),
  );

  expect(find.byKey(const Key('hero-leading')), findsOneWidget);
});

testWidgets('NeoSettingRow supports custom leading widget', (tester) async {
  await tester.pumpWidget(
    buildSubject(
      const NeoSettingRow(
        leading: ColoredBox(
          key: Key('setting-leading'),
          color: Colors.orange,
        ),
        title: 'qBittorrent',
      ),
    ),
  );

  expect(find.byKey(const Key('setting-leading')), findsOneWidget);
});
```

- [ ] **Step 2: 运行基础组件测试，确认新入参尚未存在**

Run:

```bash
flutter test test/widget/theme/neo_page_primitives_test.dart
```

Expected:

```text
Compilation failed because NeoStatusHeroCard.leading / NeoSettingRow.leading is undefined.
```

- [ ] **Step 3: 最小改造基础组件，保持向后兼容**

在 `neo_components.dart` 把两个组件都改成“`icon` 和 `leading` 二选一，但兼容旧调用”：

```dart
class NeoStatusHeroCard extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final Widget? badge;
  final double? progress;
  final String? leadingMeta;
  final String? trailingMeta;
  final Color? iconColor;
  final VoidCallback? onTap;

  const NeoStatusHeroCard({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    this.badge,
    this.progress,
    this.leadingMeta,
    this.trailingMeta,
    this.iconColor,
    this.onTap,
  }) : assert(icon != null || leading != null);
```

图标槽位改成：

```dart
child: leading ??
    Icon(icon, color: iconColor ?? tokens.primaryAccent),
```

`NeoSettingRow` 同样改造：

```dart
class NeoSettingRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final bool isDestructive;
  final VoidCallback? onTap;

  const NeoSettingRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.isDestructive = false,
    this.onTap,
  }) : assert(icon != null || leading != null);
```

行首渲染改成：

```dart
leading ?? Icon(icon, color: foreground),
```

- [ ] **Step 4: 重新运行基础组件测试**

Run:

```bash
flutter test test/widget/theme/neo_page_primitives_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交基础组件兼容层**

```bash
git add \
  lib/core/theme/neo_components.dart \
  test/widget/theme/neo_page_primitives_test.dart
git commit -m "refactor: allow custom leading widgets in neo components"
```

## 任务 3：把共享图标接入管理页与编辑器

**Files:**
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/home/presentation/widgets/neo_downloader_widgets.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/downloaders/presentation/pages/downloader_editor_page.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/home/management_tab_neumorphism_test.dart`

- [ ] **Step 1: 先写失败的管理页回归测试**

在 `management_tab_neumorphism_test.dart` 的 `card shows identity metadata...` 测试后追加断言：

```dart
expect(
  find.byKey(const Key('downloader-type-icon-aria2-large')),
  findsOneWidget,
);
```

- [ ] **Step 2: 运行管理页测试，确认还没切到共享组件**

Run:

```bash
flutter test test/widget/home/management_tab_neumorphism_test.dart
```

Expected:

```text
Test fails because downloader-type-icon-aria2-large is not found.
```

- [ ] **Step 3: 用共享图标替换管理页和编辑器中的本地实现**

在 `neo_downloader_widgets.dart` 删除旧的 `NeoDownloaderTypeIcon`、`_DownloaderTypeGlyph`、`_TransmissionGlyphPainter`，改为导入共享组件：

```dart
import 'package:windwalker/features/downloaders/presentation/widgets/downloader_type_icon.dart';
```

管理卡片图标位替换成：

```dart
DownloaderTypeIcon(
  type: downloader.type,
  size: DownloaderTypeIconSize.large,
),
```

在 `downloader_editor_page.dart` 的类型选择卡中改为：

```dart
DownloaderTypeIcon(
  type: type,
  size: DownloaderTypeIconSize.medium,
),
```

- [ ] **Step 4: 重新运行管理页测试**

Run:

```bash
flutter test test/widget/home/management_tab_neumorphism_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交管理页与编辑器接线**

```bash
git add \
  lib/features/home/presentation/widgets/neo_downloader_widgets.dart \
  lib/features/downloaders/presentation/pages/downloader_editor_page.dart \
  test/widget/home/management_tab_neumorphism_test.dart
git commit -m "refactor: use shared downloader icons in management surfaces"
```

## 任务 4：把共享图标接入添加任务页与概览列表

**Files:**
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/add_task/presentation/pages/add_task_page.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/home/presentation/widgets/neo_overview_widgets.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/add_task_page_test.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/home/data_tab_neumorphism_test.dart`

- [ ] **Step 1: 先写失败的页面回归测试**

在 `add_task_page_test.dart` 的 `renders v2 neumorphic add task structure` 测试后追加：

```dart
expect(
  find.byKey(const Key('downloader-type-icon-aria2-medium')),
  findsOneWidget,
);
expect(find.byIcon(Icons.cloud_download_rounded), findsNothing);
expect(find.byIcon(Icons.downloading_rounded), findsNothing);
expect(find.byIcon(Icons.file_download_rounded), findsNothing);
```

再新增一个选择列表测试：

```dart
testWidgets('downloader picker rows use shared downloader icons', (
  tester,
) async {
  final controller = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(id: 'aria', type: DownloaderType.aria2),
      createTestDownloader(
        id: 'qbit',
        type: DownloaderType.qbittorrent,
        name: 'SeedBox qB',
      ),
    ];

  await tester.pumpWidget(
    createAddTaskTestApp(downloaderController: controller),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('选择下载器').first);
  await tester.pumpAndSettle();

  expect(
    find.byKey(const Key('downloader-type-icon-aria2-medium')),
    findsWidgets,
  );
  expect(
    find.byKey(const Key('downloader-type-icon-qbittorrent-medium')),
    findsOneWidget,
  );
});
```

在 `data_tab_neumorphism_test.dart` 的首个测试里，滚动到分布区后增加：

```dart
expect(
  find.byKey(const Key('downloader-type-icon-aria2-medium')),
  findsOneWidget,
);
expect(
  find.byKey(const Key('downloader-type-icon-qbittorrent-medium')),
  findsOneWidget,
);
expect(find.byIcon(Icons.storage_rounded), findsNothing);
```

- [ ] **Step 2: 运行页面测试，确认旧图标逻辑尚未被替换**

Run:

```bash
flutter test test/widget/add_task_page_test.dart
flutter test test/widget/home/data_tab_neumorphism_test.dart
```

Expected:

```text
Tests fail because shared downloader icon keys are absent and generic Material icons are still present.
```

- [ ] **Step 3: 接线添加任务页与概览列表**

在 `add_task_page.dart` 中导入共享组件，并做三处替换：

1. 已选下载器卡片：

```dart
return NeoStatusHeroCard(
  leading: DownloaderTypeIcon(
    type: selectedDownloader.type,
    size: DownloaderTypeIconSize.medium,
  ),
  title: selectedDownloader.name,
  subtitle: selectedDownloader.type.label,
  badge: NeoBadge(
    label: online ? l10n.online : l10n.offline,
    backgroundColor: (online ? AppColors.success : AppColors.offline)
        .withValues(alpha: 0.14),
    foregroundColor: online ? AppColors.success : AppColors.offline,
  ),
  leadingMeta: '${selectedDownloader.host}:${selectedDownloader.port}',
  trailingMeta: _stepTitle(l10n.selectDownloaderStep),
  onTap: _showDownloaderPicker,
);
```

2. 删除本地 `IconData _downloaderIcon(...)` 与 `Color _downloaderColor(...)` 两个方法。

3. 下载器选择列表改成自定义 leading：

```dart
return NeoSettingRow(
  leading: DownloaderTypeIcon(
    type: downloader.type,
    size: DownloaderTypeIconSize.medium,
  ),
  title: downloader.name,
  subtitle: '${downloader.type.label} · ${downloader.host}:${downloader.port}',
  trailing: _selectedDownloaderId == downloader.id
      ? Icon(
          Icons.check_circle_rounded,
          color: Theme.of(context).colorScheme.primary,
        )
      : null,
  onTap: () {
    Navigator.pop(context);
    _selectDownloader(downloader);
  },
);
```

在 `neo_overview_widgets.dart` 中，把概览行左侧的通用 `storage` 容器替换成：

```dart
DownloaderTypeIcon(
  type: downloader.type,
  size: DownloaderTypeIconSize.medium,
),
```

并删掉与旧 `statusColor` 背景容器耦合的图标盒子，状态颜色只保留给文案和状态标签，不再驱动下载器类型图标本身。

- [ ] **Step 4: 重新运行页面测试**

Run:

```bash
flutter test test/widget/add_task_page_test.dart
flutter test test/widget/home/data_tab_neumorphism_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交页面接线变更**

```bash
git add \
  lib/features/add_task/presentation/pages/add_task_page.dart \
  lib/features/home/presentation/widgets/neo_overview_widgets.dart \
  test/widget/add_task_page_test.dart \
  test/widget/home/data_tab_neumorphism_test.dart
git commit -m "feat: unify downloader type icons across task and overview pages"
```

## 任务 5：跑完整回归并收尾

**Files:**
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/downloaders/presentation/widgets/downloader_type_icon.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/core/theme/neo_components.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/home/presentation/widgets/neo_downloader_widgets.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/add_task/presentation/pages/add_task_page.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/home/presentation/widgets/neo_overview_widgets.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/downloader_type_icon_test.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/theme/neo_page_primitives_test.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/home/management_tab_neumorphism_test.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/add_task_page_test.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/home/data_tab_neumorphism_test.dart`

- [ ] **Step 1: 运行聚合回归测试**

Run:

```bash
flutter test \
  test/widget/downloader_type_icon_test.dart \
  test/widget/theme/neo_page_primitives_test.dart \
  test/widget/home/management_tab_neumorphism_test.dart \
  test/widget/add_task_page_test.dart \
  test/widget/home/data_tab_neumorphism_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 2: 手工检查三处 UI 的图标层级**

Run:

```bash
flutter test test/widget/home/management_tab_neumorphism_test.dart -r expanded
flutter test test/widget/add_task_page_test.dart -r expanded
flutter test test/widget/home/data_tab_neumorphism_test.dart -r expanded
```

Expected:

```text
Targeted widget suites pass, confirming management, add-task, and overview surfaces all use the shared icon family.
```

- [ ] **Step 3: 若有尺寸或留白偏差，只做最小修正**

如果聚合测试都通过，但视觉检查发现 qB `qb` 轮廓、小尺寸 Transmission 箭头或 Aria2 字标留白不稳，只调整 `downloader_type_icon.dart` 中的 metrics/painter 数值，不在页面层继续分叉：

```dart
factory _IconMetrics.fromSize(DownloaderTypeIconSize size) {
  return switch (size) {
    DownloaderTypeIconSize.large => const _IconMetrics(48, 16, 6),
    DownloaderTypeIconSize.medium => const _IconMetrics(44, 14, 5),
    DownloaderTypeIconSize.small => const _IconMetrics(28, 10, 3.5),
  };
}
```

- [ ] **Step 4: 再跑一次聚合回归**

Run:

```bash
flutter test \
  test/widget/downloader_type_icon_test.dart \
  test/widget/theme/neo_page_primitives_test.dart \
  test/widget/home/management_tab_neumorphism_test.dart \
  test/widget/add_task_page_test.dart \
  test/widget/home/data_tab_neumorphism_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交最终整体验证结果**

```bash
git add \
  lib/features/downloaders/presentation/widgets/downloader_type_icon.dart \
  lib/core/theme/neo_components.dart \
  lib/features/home/presentation/widgets/neo_downloader_widgets.dart \
  lib/features/downloaders/presentation/pages/downloader_editor_page.dart \
  lib/features/add_task/presentation/pages/add_task_page.dart \
  lib/features/home/presentation/widgets/neo_overview_widgets.dart \
  test/widget/downloader_type_icon_test.dart \
  test/widget/theme/neo_page_primitives_test.dart \
  test/widget/home/management_tab_neumorphism_test.dart \
  test/widget/add_task_page_test.dart \
  test/widget/home/data_tab_neumorphism_test.dart
git commit -m "feat: unify downloader type icon system"
```
