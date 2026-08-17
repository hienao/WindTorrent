import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';

void main() {
  group('Downloader.version', () {
    test('默认为 null', () {
      final d = Downloader(
        id: 'x', name: 'n', type: DownloaderType.aria2,
        host: 'h', port: 6800,
      );
      expect(d.version, isNull);
    });

    test('toJson / fromJson 往返保留 version', () {
      final d = Downloader(
        id: 'x', name: 'n', type: DownloaderType.aria2,
        host: 'h', port: 6800, version: '1.36.0',
      );
      final restored = Downloader.fromJson(d.toJson());
      expect(restored.version, '1.36.0');
    });

    test('旧 JSON 无 version 字段时反序列化为 null', () {
      final legacy = <String, dynamic>{
        'id': 'x', 'name': 'n', 'type': 'aria2', 'host': 'h', 'port': 6800,
      };
      expect(Downloader.fromJson(legacy).version, isNull);
    });

    test('copyWith 更新 version', () {
      final d = Downloader(
        id: 'x', name: 'n', type: DownloaderType.aria2,
        host: 'h', port: 6800,
      );
      expect(d.copyWith(version: '5.0.0').version, '5.0.0');
    });
  });
}
