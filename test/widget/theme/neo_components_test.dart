import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/theme/neo_components.dart';

void main() {
  Widget wrapSubject(ThemeData theme, Widget child) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(body: child),
    );
  }

  testWidgets('NeoCard renders child and decoration shell', (tester) async {
    await tester.pumpWidget(
      wrapSubject(AppTheme.lightTheme, const NeoCard(child: Text('card-body'))),
    );

    expect(find.text('card-body'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('NeoCard forwards onTap to an InkWell', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrapSubject(
        AppTheme.lightTheme,
        NeoCard(onTap: () => taps++, child: const Text('tappable')),
      ),
    );

    await tester.tap(find.text('tappable'));
    expect(taps, 1);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('NeoInputShell wraps a TextField', (tester) async {
    await tester.pumpWidget(
      wrapSubject(
        AppTheme.lightTheme,
        const NeoInputShell(child: TextField(decoration: InputDecoration())),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('NeoInputShell keeps nested input decorations transparent', (
    tester,
  ) async {
    InputDecorationThemeData? nestedTheme;

    await tester.pumpWidget(
      wrapSubject(
        AppTheme.lightTheme,
        NeoInputShell(
          child: Builder(
            builder: (context) {
              nestedTheme = Theme.of(context).inputDecorationTheme;
              return const TextField();
            },
          ),
        ),
      ),
    );

    expect(nestedTheme, isNotNull);
    expect(nestedTheme!.filled, isFalse);
    expect(nestedTheme!.fillColor, Colors.transparent);
    expect(nestedTheme!.enabledBorder, InputBorder.none);
    expect(nestedTheme!.focusedBorder, InputBorder.none);
  });

  testWidgets('NeoProgress clips a linear indicator', (tester) async {
    await tester.pumpWidget(
      wrapSubject(AppTheme.lightTheme, const NeoProgress(value: 0.5)),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('NeoBadge renders label text', (tester) async {
    await tester.pumpWidget(
      wrapSubject(
        AppTheme.lightTheme,
        NeoBadge(
          label: 'Downloading',
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
        ),
      ),
    );

    expect(find.text('Downloading'), findsOneWidget);
  });

  testWidgets('NeoButton renders label and is tappable', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      wrapSubject(
        AppTheme.darkTheme,
        NeoButton.primary(
          onPressed: () => pressed++,
          label: const Text('Start'),
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(pressed, 1);
  });

  testWidgets('NeoSection renders title, subtitle and child', (tester) async {
    await tester.pumpWidget(
      wrapSubject(
        AppTheme.darkTheme,
        const NeoSection(
          title: 'Section Title',
          subtitle: 'Section Sub',
          child: Text('section body'),
        ),
      ),
    );

    expect(find.text('Section Title'), findsOneWidget);
    expect(find.text('Section Sub'), findsOneWidget);
    expect(find.text('section body'), findsOneWidget);
  });

  testWidgets('NeoActionBar wraps child in a SafeArea + NeoCard', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapSubject(
        AppTheme.lightTheme,
        const NeoActionBar(child: Text('action')),
      ),
    );

    expect(find.text('action'), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
    expect(find.byType(NeoCard), findsOneWidget);
  });

  testWidgets('NeoSurface paints a raised container', (tester) async {
    await tester.pumpWidget(
      wrapSubject(
        AppTheme.lightTheme,
        const NeoSurface(child: Text('surface-body')),
      ),
    );

    expect(find.text('surface-body'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });
}
