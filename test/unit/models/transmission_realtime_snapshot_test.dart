import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/transmission_realtime_snapshot.dart';

void main() {
  test('Transmission 快照可转换为 DownloadTask 与聚合统计', () {
    final snapshot = TransmissionRealtimeSnapshot.fromRpc(
      downloaderId: 'tr-1',
      torrents: [
        {
          'id': 1,
          'name': 'demo',
          'status': 4,
          'percentDone': 0.5,
          'totalSize': 100,
          'leftUntilDone': 50,
          'rateDownload': 12,
          'rateUpload': 3,
          'downloadDir': '/ptd',
          'peersSendingToUs': 2,
          'peersGettingFromUs': 1,
          'trackerStats': [],
        },
      ],
    );

    final task = snapshot.tasks.single;
    expect(task.downloaderId, 'tr-1');
    expect(task.status, TaskStatus.downloading);
    expect(task.progress, 0.5);
    expect(snapshot.totalDownloadSpeed, 12);
    expect(snapshot.totalUploadSpeed, 3);
  });
}
