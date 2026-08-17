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

  testWidgets(
    'renders custom neumorphic tab bar instead of Material NavigationBar',
    (tester) async {
      await tester.pumpWidget(buildSubject(onTabSelected: (_) {}));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NeoHomeTabBar), findsOneWidget);
      expect(find.text('总览'), findsOneWidget);
      expect(find.text('下载器'), findsOneWidget);
    },
  );

  testWidgets('selecting a tab calls onTabSelected', (tester) async {
    int? selected;
    await tester.pumpWidget(
      buildSubject(onTabSelected: (index) => selected = index),
    );

    await tester.tap(find.text('下载器'));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

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
      buildSubject(selectedIndex: 1, onTabSelected: (_) {}),
    );

    expect(find.byTooltip('添加下载器'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });
}
