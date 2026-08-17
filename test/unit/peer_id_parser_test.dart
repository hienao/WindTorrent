import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/utils/peer_id_parser.dart';

void main() {
  group('PeerIdParser', () {
    test('解析 URL 编码的 µTorrent peerId', () {
      // -UT355W- -> µTorrent 3.5.5
      final result = PeerIdParser.parse('%2DUT355W%2D%1C%B3J%CB%F2%025%D6%94%ED9%E8');
      expect(result.client, 'µTorrent');
      expect(result.version, '3.5.5');
    });

    test('解析 URL 编码的 qBittorrent peerId', () {
      // -qB5100- -> qBittorrent 5.1.0
      final result = PeerIdParser.parse('%2DqB5100%2DsmUcWpqzyEHf');
      expect(result.client, 'qBittorrent');
      expect(result.version, '5.1.0');
    });

    test('解析 URL 编码的 BitComet peerId', () {
      // -BC0220- -> BitComet 2.20 (buffer[4]=0x32='2', buffer[5]=0x32='2', buffer[6]=0x30='0')
      final result = PeerIdParser.parse('%2DBC0220%2D%DD%CE%13%AA%9E%C7%B1r%A4%DE%2E%EF');
      expect(result.client, 'BitComet');
      expect(result.version, '2.20');
    });

    test('解析 URL 编码的迅雷 peerId', () {
      // -XL0018- -> Xunlei 0.0.1.8 (四段式版本号)
      final result = PeerIdParser.parse('%2DXL0018%2D89875EDFE269');
      expect(result.client, 'Xunlei');
      expect(result.version, '0.0.1.8');
    });

    test('解析未编码的 µTorrent peerId', () {
      final result = PeerIdParser.parse('-UT355W-%1C%B3J%CB%F2%025%D6%94%ED9%E8');
      expect(result.client, 'µTorrent');
    });

    test('空 peerId 返回 unknown', () {
      final result = PeerIdParser.parse('');
      expect(result.client, 'unknown');
    });

    test('display 展示客户端+版本', () {
      final result = PeerIdParser.parse('%2DqB5100%2DsmUcWpqzyEHf');
      expect(result.display, 'qBittorrent 5.1.0');
    });

    test('display 无版本时只展示客户端', () {
      final result = PeerIdParser.parse('%2DBC0220%2Dtest');
      expect(result.display, contains('BitComet'));
    });

    test('Transmission peerId', () {
      // -TR4050- -> Transmission 4.050
      final result = PeerIdParser.parse('-TR4050-abcdef01234567');
      expect(result.client, 'Transmission');
      expect(result.version, isNotNull);
    });

    test('Deluge peerId', () {
      // -DE1230- -> Deluge 1.2.3
      final result = PeerIdParser.parse('-DE1230-abcdef01234567');
      expect(result.client, 'Deluge');
      expect(result.version, '1.2.3');
    });

    test('Aria2 peerId (simple client)', () {
      final result = PeerIdParser.parse('-aria2-1.36.0');
      expect(result.client, 'Aria2');
    });

    test('µTorrent Beta peerId', () {
      // -UT355B- -> µTorrent 3.5.5 Beta (B = Beta mnemonic)
      final result = PeerIdParser.parse('-UT355B-abcdef01234567');
      expect(result.client, 'µTorrent');
      expect(result.version, '3.5.5 Beta');
    });

    test('µTorrent Alpha peerId', () {
      // -UT355A- -> µTorrent 3.5.5 Alpha (A = Alpha mnemonic)
      final result = PeerIdParser.parse('-UT355A-abcdef01234567');
      expect(result.client, 'µTorrent');
      expect(result.version, '3.5.5 Alpha');
    });
  });
}
