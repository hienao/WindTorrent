import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'qbit_test_helpers.dart';

void main() {
  testWidgets('qBit detail page renders sections and child-page entries',
      (tester) async {
    await tester.pumpWidget(buildQBitDetailTestApp(detail: fakeQBitTaskDetail));
    await tester.pumpAndSettle();

    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Torrent Info'), findsOneWidget);
    expect(find.text('HTTP Sources'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Servers'), findsOneWidget);
    // Peers entry uses summary format: "30 active (35 total)"
    expect(find.textContaining('Peers'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });
}
