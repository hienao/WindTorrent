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

  testWidgets(
    'NeoPageHeader renders title, subtitle, back and trailing actions',
    (tester) async {
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
    },
  );

  testWidgets('NeoSettingRow exposes text, value, and danger styling hook', (
    tester,
  ) async {
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

  testWidgets('NeoSettingRow supports widget trailing content', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const NeoSettingRow(
          icon: Icons.notifications,
          title: 'Notifications',
          trailing: Switch(value: true, onChanged: null),
        ),
      ),
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('NeoFilterStrip calls selection callback with selected value', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      buildSubject(
        NeoFilterStrip<String>(
          selectedValue: 'all',
          options: const [
            NeoChoiceOption(value: 'all', label: 'All'),
            NeoChoiceOption(
              value: 'downloading',
              label: 'Downloading',
              icon: Icons.download_rounded,
            ),
          ],
          onSelected: (value) => selected = value,
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Downloading'), findsOneWidget);

    await tester.tap(find.text('Downloading'));
    expect(selected, 'downloading');
    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });

  testWidgets('NeoChoicePill uses compact inset chip styling', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        NeoChoicePill(label: 'Compact', selected: false, onTap: () {}),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration! as BoxDecoration;
    final label = tester.widget<Text>(find.text('Compact'));

    expect(
      container.padding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    );
    expect(decoration.boxShadow?.first.offset, const Offset(3, 3));
    expect(label.style?.fontSize, 12);
    expect(label.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('NeoFilterStrip leaves room for pill shadows', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        NeoFilterStrip<String>(
          selectedValue: 'all',
          options: const [
            NeoChoiceOption(value: 'all', label: 'All'),
            NeoChoiceOption(value: 'paused', label: 'Paused'),
          ],
          onSelected: (_) {},
        ),
      ),
    );

    final strip = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );

    expect(strip.clipBehavior, Clip.none);
    expect(strip.padding, const EdgeInsets.fromLTRB(16, 8, 16, 10));
  });

  testWidgets('NeoChoicePill supports direct plan constructor shape', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      buildSubject(
        NeoChoicePill(
          label: 'Active',
          icon: Icons.check_circle,
          selected: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Active'));
    expect(tapped, isTrue);
  });

  testWidgets('NeoFormFieldShell renders label, suffix, and child', (
    tester,
  ) async {
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

  testWidgets('NeoFormFieldShell supports disabled opacity', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const NeoFormFieldShell(
          label: 'Download limit',
          enabled: false,
          child: Text('Disabled'),
        ),
      ),
    );

    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 0.48);
    expect(find.text('Disabled'), findsOneWidget);
  });

  testWidgets('NeoStatusHeroCard renders badge, progress, and metadata', (
    tester,
  ) async {
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

  testWidgets('NeoStatusHeroCard supports optional fields and tap', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      buildSubject(
        NeoStatusHeroCard(
          icon: Icons.storage_rounded,
          iconColor: Colors.teal,
          title: 'NAS',
          subtitle: 'Aria2',
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('NAS'), findsOneWidget);
    expect(find.text('Aria2'), findsOneWidget);
    expect(find.byType(NeoProgress), findsNothing);

    await tester.tap(find.text('NAS'));
    expect(tapped, isTrue);
  });

  testWidgets('NeoStatusHeroCard supports custom leading widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const NeoStatusHeroCard(
          leading: ColoredBox(key: Key('hero-leading'), color: Colors.teal),
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
}
