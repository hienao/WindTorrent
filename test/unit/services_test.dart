// Service tests for WindTorrent app
// Following flutter-handling-http-and-json SKILL.md guidelines

import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/core/constants/app_constants.dart';

void main() {
  group('Aria2Service Tests', () {
    late Aria2Service service;
    late Downloader downloader;

    setUp(() {
      downloader = Downloader(
        id: 'test-aria2',
        name: 'Test Aria2',
        type: DownloaderType.aria2,
        host: '192.168.1.100',
        port: 6800,
        secret: 'testsecret',
      );
      service = Aria2Service(downloader);
    });

    test('should create service with correct RPC URL', () {
      expect(service.downloader.host, '192.168.1.100');
      expect(service.downloader.port, 6800);
      expect(service.downloader.secret, 'testsecret');
    });

    test('rpcUrl should be formatted correctly', () {
      expect(service.downloader.rpcUrl, 'http://192.168.1.100:6800/jsonrpc');
    });
  });

  group('Downloader Model Tests', () {
    test('should create Aria2 downloader correctly', () {
      final downloader = Downloader(
        id: 'aria2-1',
        name: 'Local Aria2',
        type: DownloaderType.aria2,
        host: '127.0.0.1',
        port: 6800,
        secret: 'mypassword',
      );

      expect(downloader.type, DownloaderType.aria2);
      expect(downloader.rpcUrl, 'http://127.0.0.1:6800/jsonrpc');
    });

    test('should create qBittorrent downloader correctly', () {
      final downloader = Downloader(
        id: 'qbittorrent-1',
        name: 'qBittorrent',
        type: DownloaderType.qbittorrent,
        host: '192.168.1.50',
        port: 8080,
        username: 'admin',
        password: 'adminadmin',
      );

      expect(downloader.type, DownloaderType.qbittorrent);
    });

    test('should create Transmission downloader correctly', () {
      final downloader = Downloader(
        id: 'transmission-1',
        name: 'Transmission',
        type: DownloaderType.transmission,
        host: '192.168.1.60',
        port: 9091,
        username: 'transmission',
        password: 'transmission',
      );

      expect(downloader.type, DownloaderType.transmission);
    });

    test('copyWith should work correctly', () {
      final downloader = Downloader(
        id: 'test',
        name: 'Test',
        type: DownloaderType.aria2,
        host: 'localhost',
        port: 6800,
        status: DownloaderStatus.offline,
      );

      final updated = downloader.copyWith(
        name: 'Updated Name',
        status: DownloaderStatus.online,
      );

      expect(updated.name, 'Updated Name');
      expect(updated.status, DownloaderStatus.online);
      expect(updated.host, 'localhost'); // Unchanged
    });

    test('fromJson should parse correctly', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Downloader',
        'type': 'qbittorrent',
        'host': '10.0.0.1',
        'port': 8080,
        'username': 'user',
        'password': 'pass',
        'status': 'online',
      };

      final downloader = Downloader.fromJson(json);

      expect(downloader.id, 'test-id');
      expect(downloader.name, 'Test Downloader');
      expect(downloader.type, DownloaderType.qbittorrent);
      expect(downloader.status, DownloaderStatus.online);
    });
  });
}
