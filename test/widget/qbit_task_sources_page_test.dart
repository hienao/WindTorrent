import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/models/qbit_task_source.dart';

import 'qbit_test_helpers.dart';

void main() {
  testWidgets('qBit sources page renders source cards', (tester) async {
    await tester.pumpWidget(
      buildQBitSourcesTestApp(
        sources: const [
          QBitTaskSource(
            name: 'DHT',
            status: 'working',
            peerCount: 0,
            seedCount: 0,
            downloadCount: 0,
            downloadedCount: 0,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DHT'), findsOneWidget);
    expect(find.text('working'), findsOneWidget);
    expect(find.text('Peers'), findsOneWidget);
    expect(find.text('Seeds'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(4));

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets('qBit sources page shows empty state', (tester) async {
    await tester.pumpWidget(buildQBitSourcesTestApp(sources: const []));
    await tester.pumpAndSettle();

    expect(find.text('No sources'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });
}
