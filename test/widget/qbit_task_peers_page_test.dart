import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/models/qbit_task_peer.dart';

import 'qbit_test_helpers.dart';

void main() {
  // 本地 4.1 / 5.0 API 文档未定义 /sync/torrentPeers 响应体；此处用已确认字段
  // （connection、flags、ip、port、progress、relevance、dl/up_speed、downloaded/uploaded）
  // 构造对端行，验证节点页渲染。
  testWidgets('qBit peers page renders dense peer rows', (tester) async {
    await tester.pumpWidget(
      buildQBitPeersTestApp(
        peers: const [
          QBitTaskPeer(
            address: '1.1.1.1',
            port: 51413,
            protocol: 'BT',
            stateTags: ['H', 'X'],
            downloadSpeed: 0,
            uploadSpeed: 12800,
            downloaded: 0,
            uploaded: 2048,
            progress: 0.31,
            relevance: 0.0002,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.1.1.1:51413'), findsOneWidget);
    expect(find.text('BT'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);
    expect(find.text('↓ 0 B/s'), findsOneWidget);
    expect(find.text('↑ 12.5 KB/s'), findsOneWidget);
    expect(find.text('0 B'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Uploaded'), findsOneWidget);
    expect(find.text('31%'), findsOneWidget);
    expect(find.text('file affinity 0.02%'), findsOneWidget);

    // 销毁 Shell（取消 5s 自动刷新 Timer），避免 pending timer 断言失败。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets('qBit peers page shows empty state', (tester) async {
    await tester.pumpWidget(buildQBitPeersTestApp(peers: const []));
    await tester.pumpAndSettle();

    expect(find.text('No peers'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(milliseconds: 10));
  });

  testWidgets(
    'qBit peer footer keeps 100% and affinity readable on narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildQBitPeersTestApp(
          peers: const [
            QBitTaskPeer(
              address: '1.1.1.1',
              port: 51413,
              protocol: 'BT',
              stateTags: ['H'],
              downloadSpeed: 0,
              uploadSpeed: 0,
              downloaded: 0,
              uploaded: 0,
              progress: 1,
              relevance: 1,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('file affinity 100.00%'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
    },
  );
}
