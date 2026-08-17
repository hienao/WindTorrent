import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';

void main() {
  group('DownloaderBackupBundle', () {
    final downloader = Downloader(
      id: 'd1',
      name: 'Home qBit',
      type: DownloaderType.qbittorrent,
      host: '192.168.1.3',
      port: 8080,
      username: 'admin',
      password: '123456',
      useHttps: false,
      version: '4.6.5',
    );

    test('toJson only persists connection fields', () {
      final bundle = DownloaderBackupBundle(
        schemaVersion: 1,
        backupId: '20260627T143015Z_abcde',
        createdAt: DateTime.parse('2026-06-27T14:30:15Z'),
        appVersion: '1.0.0+1',
        downloaders: [downloader],
      );

      final json = bundle.toJson();
      expect(json['schemaVersion'], 1);
      expect((json['downloaders'] as List).single['host'], '192.168.1.3');
      expect(
        (json['downloaders'] as List).single.containsKey('status'),
        isFalse,
      );
      expect(
        (json['downloaders'] as List).single.containsKey('taskCount'),
        isFalse,
      );
    });

    test('fromJson restores full downloader credentials', () {
      final bundle = DownloaderBackupBundle.fromJson({
        'schemaVersion': 1,
        'backupId': '20260627T143015Z_abcde',
        'createdAt': '2026-06-27T14:30:15Z',
        'appVersion': '1.0.0+1',
        'user': {'uid': 'uid-1'},
        'downloaders': [
          {
            'id': 'd1',
            'name': 'Home qBit',
            'type': 'qbittorrent',
            'host': '192.168.1.3',
            'port': 8080,
            'username': 'admin',
            'password': '123456',
            'useHttps': false,
            'version': '4.6.5',
          },
        ],
      });

      expect(bundle.downloaders.single.password, '123456');
      expect(bundle.downloaders.single.type, DownloaderType.qbittorrent);
    });

    test('throws on unsupported schemaVersion', () {
      expect(
        () => DownloaderBackupBundle.fromJson({
          'schemaVersion': 2,
          'backupId': 'b1',
          'createdAt': '2026-06-27T14:30:15Z',
          'appVersion': '1.0.0',
          'user': {'uid': 'u1'},
          'downloaders': const [],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
