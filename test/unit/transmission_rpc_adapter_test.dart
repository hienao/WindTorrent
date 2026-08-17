import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/transmission/transmission_legacy_rpc_adapter.dart';
import 'package:windwalker/services/transmission/transmission_modern_rpc_adapter.dart';
import 'package:windwalker/services/transmission/transmission_protocol_info.dart';

void main() {
  Downloader trans() => Downloader(
        id: 't',
        name: 'Transmission',
        type: DownloaderType.transmission,
        host: 'localhost',
        port: 9091,
      );

  group('Modern adapter', () {
    test('should map snake_case torrent fields', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'result': {
                'torrents': [
                  {
                    'id': 7,
                    'hash_string': 'abc',
                    'name': 'demo.iso',
                    'total_size': 100,
                    'percent_done': 0.5,
                    'rate_download': 10,
                    'rate_upload': 2,
                    'status': 4,
                    'eta': 60,
                    'peers_sending_to_us': 3,
                    'peers_getting_from_us': 5,
                    'added_date': 1710000000,
                    'done_date': 0,
                    'download_dir': '/downloads',
                  }
                ]
              },
              'id': 1,
            }),
            200,
          ));

      final adapter = TransmissionModernRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.modern,
          appVersion: '4.1.1',
          rpcSemver: '6.0.1',
        ),
      );

      final tasks = await adapter.getTasks();

      expect(tasks.single.gid, 'abc');
      expect(tasks.single.totalSize, 100);
      expect(tasks.single.savePath, '/downloads');
      expect(tasks.single.downloadSpeed, 10);
      expect(tasks.single.uploadSpeed, 2);
    });

    test('should send torrent_add with snake_case fields', () async {
      late Map<String, dynamic> payload;
      final client = MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'result': {
              'torrent_added': {'id': 42}
            },
            'id': 1,
          }),
          200,
        );
      });

      final adapter = TransmissionModernRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.modern,
          appVersion: '4.1.1',
        ),
      );

      final result = await adapter.addTask(
        AddTaskRequest(
          downloaderId: 't',
          torrentFileName: 'demo.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
          savePath: '/downloads',
        ),
      );

      expect(result, '42');
      expect(payload['method'], 'torrent_add');
      final params = payload['params'] as Map<String, dynamic>;
      expect(params['download_dir'], '/downloads');
      expect(params['metainfo'], base64Encode([1, 2, 3]));
    });

    test('should map alt_speed fields into DownloaderSpeedConfig', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'result': {
                'alt_speed_enabled': true,
                'speed_limit_down': 100,
                'speed_limit_up': 50,
                'alt_speed_down': 20,
                'alt_speed_up': 10,
              },
              'id': 1,
            }),
            200,
          ));

      final adapter = TransmissionModernRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.modern,
          appVersion: '4.1.1',
        ),
      );

      final config = await adapter.getSpeedConfig();
      expect(config.speedLimitModeEnabled, isTrue);
      expect(config.downloadLimitKB, 100);
      expect(config.altUploadLimitKB, 10);
    });

    test('should map session_stats into global stat', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'result': {
                'download_speed': 1024,
                'upload_speed': 512,
                'torrent_count': 5,
              },
              'id': 1,
            }),
            200,
          ));

      final adapter = TransmissionModernRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.modern,
          appVersion: '4.1.1',
        ),
      );

      final stat = await adapter.getGlobalStat();
      expect(stat['downloadSpeed'], 1024);
      expect(stat['uploadSpeed'], 512);
      expect(stat['torrentCount'], 5);
    });
  });

  group('Legacy adapter', () {
    test('should map legacy torrent fields', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'result': 'success',
              'arguments': {
                'torrents': [
                  {
                    'id': 8,
                    'hashString': 'def',
                    'name': 'legacy.iso',
                    'totalSize': 200,
                    'percentDone': 0.25,
                    'rateDownload': 20,
                    'rateUpload': 4,
                    'status': 4,
                    'eta': 120,
                    'peersSendingToUs': 1,
                    'peersGettingFromUs': 2,
                    'addedDate': 1710000010,
                    'doneDate': 0,
                    'downloadDir': '/legacy',
                  }
                ]
              },
              'tag': 1,
            }),
            200,
          ));

      final adapter = TransmissionLegacyRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.legacy,
          appVersion: '4.0.3',
          rpcSemver: '5.3.0',
        ),
      );

      final tasks = await adapter.getTasks();

      expect(tasks.single.gid, 'def');
      expect(tasks.single.totalSize, 200);
      expect(tasks.single.savePath, '/legacy');
      expect(tasks.single.downloadSpeed, 20);
      expect(tasks.single.uploadSpeed, 4);
    });

    test('should send torrent-add with legacy fields', () async {
      late Map<String, dynamic> payload;
      final client = MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'result': 'success',
            'arguments': {
              'torrent-added': {'id': 42}
            },
            'tag': 1,
          }),
          200,
        );
      });

      final adapter = TransmissionLegacyRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.legacy,
          appVersion: '4.0.3',
        ),
      );

      final result = await adapter.addTask(
        AddTaskRequest(
          downloaderId: 't',
          torrentFileName: 'demo.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
          savePath: '/legacy',
        ),
      );

      expect(result, '42');
      expect(payload['method'], 'torrent-add');
      expect((payload['arguments'] as Map<String, dynamic>)['download-dir'],
          '/legacy');
    });

    test('should map alt-speed fields into DownloaderSpeedConfig', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'result': 'success',
              'arguments': {
                'alt-speed-enabled': true,
                'speed-limit-down': 100,
                'speed-limit-up': 50,
                'alt-speed-down': 20,
                'alt-speed-up': 10,
              },
              'tag': 1,
            }),
            200,
          ));

      final adapter = TransmissionLegacyRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.legacy,
          appVersion: '4.0.3',
        ),
      );

      final config = await adapter.getSpeedConfig();
      expect(config.speedLimitModeEnabled, isTrue);
      expect(config.downloadLimitKB, 100);
      expect(config.altUploadLimitKB, 10);
    });

    test('should map session-stats into global stat', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'result': 'success',
              'arguments': {
                'downloadSpeed': 2048,
                'uploadSpeed': 1024,
                'activeTorrentCount': 3,
              },
              'tag': 1,
            }),
            200,
          ));

      final adapter = TransmissionLegacyRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.legacy,
          appVersion: '4.0.3',
        ),
      );

      final stat = await adapter.getGlobalStat();
      expect(stat['downloadSpeed'], 2048);
      expect(stat['uploadSpeed'], 1024);
      expect(stat['torrentCount'], 3);
    });
  });

  group('Modern adapter full detail', () {
    test('maps info, transfer, dates, and runtime fields', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'result': {
                'torrents': [
                  {
                    'id': 7,
                    'hash_string': 'abc',
                    'name': 'demo.iso',
                    'total_size': 1000,
                    'piece_count': 20,
                    'piece_size': 50,
                    'download_dir': '/downloads',
                    'is_private': true,
                    'creator': 'qBittorrent',
                    'date_created': 1710000000,
                    'magnet_link': 'magnet:?xt=urn:btih:abc',
                    'desired_available': 0.95,
                    'downloaded_ever': 900,
                    'uploaded_ever': 300,
                    'upload_ratio': 0.33,
                    'rate_download': 10,
                    'added_date': 1710000100,
                    'done_date': 1710000200,
                    'activity_date': 1710000300,
                    'seconds_downloading': 120,
                    'seconds_seeding': 45,
                    'files': [
                      {'name': 'demo.iso', 'length': 1000, 'bytes_completed': 900}
                    ],
                    'trackers': [
                      {'announce': 'https://tracker.example/announce'}
                    ],
                    'peers': [
                      {'address': '1.1.1.1'}
                    ],
                  }
                ]
              },
              'id': 1,
            }),
            200,
          ));

      final adapter = TransmissionModernRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.modern,
          appVersion: '4.1.1',
        ),
      );

      final detail = await adapter.getTaskFullDetail('7');

      expect(detail.pieceCount, 20);
      expect(detail.isPrivate, isTrue);
      expect(detail.fileCount, 1);
      expect(detail.trackerCount, 1);
      expect(detail.peerCount, 1);
    expect(detail.downloadDuration, const Duration(seconds: 120));
  });

  test('throws DownloaderServiceException when task is missing', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'result': {'torrents': <Map<String, dynamic>>[]},
            'id': 1,
          }),
          200,
        ));

    final adapter = TransmissionModernRpcAdapter(
      downloader: trans(),
      client: client,
      protocolInfo: const TransmissionProtocolInfo(
        protocol: TransmissionProtocol.modern,
        appVersion: '4.1.1',
      ),
    );

    await expectLater(
      adapter.getTaskFullDetail('999'),
      throwsA(isA<DownloaderServiceException>()),
    );
  });
});

  group('Legacy adapter full detail', () {
    test('maps camelCase full-detail fields', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'result': 'success',
              'arguments': {
                'torrents': [
                  {
                    'id': 8,
                    'hashString': 'def',
                    'name': 'legacy.iso',
                    'totalSize': 2000,
                    'pieceCount': 40,
                    'pieceSize': 50,
                    'downloadDir': '/legacy',
                    'isPrivate': false,
                    'creator': 'Transmission',
                    'dateCreated': 1710001000,
                    'magnetLink': 'magnet:?xt=urn:btih:def',
                    'desiredAvailable': 1.0,
                    'downloadedEver': 2000,
                    'uploadedEver': 1000,
                    'uploadRatio': 0.5,
                    'rateDownload': 20,
                    'addedDate': 1710001100,
                    'doneDate': 1710001200,
                    'activityDate': 1710001300,
                    'secondsDownloading': 240,
                    'secondsSeeding': 60,
                    'files': [
                      {'name': 'legacy.iso', 'length': 2000, 'bytesCompleted': 2000}
                    ],
                    'trackers': [
                      {'announce': 'https://tracker.example/legacy'}
                    ],
                    'peers': [
                      {'address': '2.2.2.2'}
                    ],
                  }
                ]
              },
              'tag': 1,
            }),
            200,
          ));

      final adapter = TransmissionLegacyRpcAdapter(
        downloader: trans(),
        client: client,
        protocolInfo: const TransmissionProtocolInfo(
          protocol: TransmissionProtocol.legacy,
          appVersion: '4.0.3',
          rpcSemver: '5.3.0',
        ),
      );

      final detail = await adapter.getTaskFullDetail('8');

      expect(detail.pieceCount, 40);
      expect(detail.isPrivate, isFalse);
      expect(detail.fileCount, 1);
      expect(detail.trackerCount, 1);
      expect(detail.peerCount, 1);
      expect(detail.seedingDuration, const Duration(seconds: 60));
    });
  });
}
