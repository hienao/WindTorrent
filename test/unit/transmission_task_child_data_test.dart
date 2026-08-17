import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/transmission_task_options.dart';
import 'package:windwalker/models/transmission_task_options_update.dart';
import 'package:windwalker/services/transmission/transmission_modern_rpc_adapter.dart';
import 'package:windwalker/services/transmission/transmission_legacy_rpc_adapter.dart';
import 'package:windwalker/services/transmission/transmission_protocol_info.dart';

Downloader _testDownloader() => Downloader(
      id: 't1',
      name: 'Test',
      type: DownloaderType.transmission,
      host: 'localhost',
      port: 9091,
    );

const _modernProtocolInfo = TransmissionProtocolInfo(
  protocol: TransmissionProtocol.modern,
  appVersion: '4.1.0',
  rpcVersion: 17,
);

const _legacyProtocolInfo = TransmissionProtocolInfo(
  protocol: TransmissionProtocol.legacy,
  appVersion: '3.00',
  rpcVersion: 15,
);

/// Build a modern adapter that returns the given response body for every call.
TransmissionModernRpcAdapter _buildModernAdapter(
  Map<String, dynamic> responseBody,
) {
  return TransmissionModernRpcAdapter(
    downloader: _testDownloader(),
    protocolInfo: _modernProtocolInfo,
    client: http_testing.MockClient(
      (request) async => http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'result': responseBody,
          'id': 1,
        }),
        200,
        headers: {'x-transmission-session-id': 'test-session'},
      ),
    ),
  );
}

/// Build a legacy adapter that returns the given arguments body for every call.
TransmissionLegacyRpcAdapter _buildLegacyAdapter(
  Map<String, dynamic> argumentsBody,
) {
  return TransmissionLegacyRpcAdapter(
    downloader: _testDownloader(),
    protocolInfo: _legacyProtocolInfo,
    client: http_testing.MockClient(
      (request) async => http.Response(
        jsonEncode({
          'result': 'success',
          'arguments': argumentsBody,
          'tag': 1,
        }),
        200,
        headers: {'x-transmission-session-id': 'test-session'},
      ),
    ),
  );
}

void main() {
  group('Modern adapter child-page parsing', () {
    test('maps files into a directory tree', () async {
      final adapter = _buildModernAdapter({
        'torrents': [
          {
            'files': [
              {
                'name': 'demo/video/a.mkv',
                'length': 100,
                'bytes_completed': 100,
              },
              {
                'name': 'demo/subs/a.srt',
                'length': 10,
                'bytes_completed': 5,
              },
            ],
          },
        ],
      });

      final files = await adapter.getTaskFiles('7');

      // 应构建为 1 个根目录 "demo"
      expect(files.length, 1);
      final demo = files.first;
      expect(demo.name, 'demo');
      expect(demo.isDirectory, isTrue);
      expect(demo.children.length, 2);

      // demo 下有 video 和 subs 两个子目录
      final video = demo.children.first;
      expect(video.name, 'video');
      expect(video.isDirectory, isTrue);
      expect(video.children.length, 1);
      expect(video.children.first.name, 'a.mkv');
      expect(video.children.first.progress, 1.0);

      final subs = demo.children.last;
      expect(subs.name, 'subs');
      expect(subs.isDirectory, isTrue);
      expect(subs.children.length, 1);
      expect(subs.children.first.name, 'a.srt');
      expect(subs.children.first.progress, 0.5);
    });

    test('maps trackers with all fields', () async {
      final adapter = _buildModernAdapter({
        'torrents': [
          {
            'trackers': [
              {
                'id': 1,
                'announce': 'https://tracker.example/announce',
                'sitename': 'tracker.example',
                'tier': 1,
                'last_announce_time': 1710000000,
                'next_announce_time': 1710000600,
                'last_scrape_time': 1710000300,
                'seeder_count': 200,
                'leecher_count': 20,
                'download_count': 50,
              },
            ],
          },
        ],
      });

      final trackers = await adapter.getTaskTrackers('7');

      expect(trackers.length, 1);
      expect(trackers.single.id, 1);
      expect(trackers.single.host, 'tracker.example');
      expect(trackers.single.announce, 'https://tracker.example/announce');
      expect(trackers.single.tier, 1);
      expect(trackers.single.lastAnnounceAt,
          DateTime.fromMillisecondsSinceEpoch(1710000000 * 1000));
      expect(trackers.single.seederCount, 200);
      expect(trackers.single.leecherCount, 20);
      expect(trackers.single.downloadCount, 50);
    });

    test('maps peers with all fields', () async {
      final adapter = _buildModernAdapter({
        'torrents': [
          {
            'peers': [
              {
                'address': '1.1.1.1',
                'client_name': 'qBittorrent/4.3.8',
                'port': 42032,
                'progress': 0.31,
                'rate_to_client': 0,
                'rate_to_peer': 12800,
                'isDownloadingFromUs': false,
                'isUploadingToUs': true,
              },
            ],
          },
        ],
      });

      final peers = await adapter.getTaskPeers('7');

      expect(peers.length, 1);
      expect(peers.single.address, '1.1.1.1');
      expect(peers.single.clientName, 'qBittorrent/4.3.8');
      expect(peers.single.port, 42032);
      expect(peers.single.progress, 0.31);
      expect(peers.single.uploadSpeed, 12800);
      expect(peers.single.isUploadingFromUs, isTrue);
    });

    test('maps options with all fields', () async {
      final adapter = _buildModernAdapter({
        'torrents': [
          {
            'bandwidth_priority': 0,
            'honors_session_limits': true,
            'download_limited': true,
            'download_limit': 100,
            'upload_limited': true,
            'upload_limit': 3000,
            'seed_ratio_mode': 0,
            'seed_ratio_limit': 2.0,
            'idle_seeding_limit_mode': 0,
            'idle_seeding_limit': 30,
          },
        ],
      });

      final options = await adapter.getTaskOptions('7');

      expect(options.bandwidthPriority, 0);
      expect(options.honorsSessionLimits, isTrue);
      expect(options.downloadLimited, isTrue);
      expect(options.downloadLimitKBps, 100);
      expect(options.uploadLimited, isTrue);
      expect(options.uploadLimitKBps, 3000);
      expect(options.seedRatioMode, TransmissionLimitMode.global);
      expect(options.seedRatioLimit, 2.0);
      expect(options.idleLimitMode, TransmissionLimitMode.global);
      expect(options.idleLimitMinutes, 30);
    });
  });

  group('Legacy adapter child-page parsing', () {
    test('maps files with camelCase fields', () async {
      final adapter = _buildLegacyAdapter({
        'torrents': [
          {
            'files': [
              {
                'name': 'movie.mkv',
                'length': 500,
                'bytesCompleted': 250,
              },
            ],
          },
        ],
      });

      final files = await adapter.getTaskFiles('7');

      expect(files.length, 1);
      expect(files.single.path, 'movie.mkv');
      expect(files.single.name, 'movie.mkv');
      expect(files.single.size, 500);
      expect(files.single.downloaded, 250);
      expect(files.single.progress, 0.5);
    });

    test('maps trackers with camelCase fields', () async {
      final adapter = _buildLegacyAdapter({
        'torrents': [
          {
            'trackers': [
              {
                'id': 2,
                'announce': 'http://tracker.local:8080/announce',
                'sitename': 'tracker.local:8080',
                'tier': 0,
                'lastAnnounceTime': 1710000000,
                'nextAnnounceTime': 1710000600,
                'lastScrapeTime': 1710000300,
                'seederCount': 10,
                'leecherCount': 5,
                'downloadCount': 3,
              },
            ],
          },
        ],
      });

      final trackers = await adapter.getTaskTrackers('7');

      expect(trackers.length, 1);
      expect(trackers.single.id, 2);
      expect(trackers.single.host, 'tracker.local:8080');
      expect(trackers.single.tier, 0);
      expect(trackers.single.seederCount, 10);
    });

    test('maps peers with camelCase fields', () async {
      final adapter = _buildLegacyAdapter({
        'torrents': [
          {
            'peers': [
              {
                'address': '222.213.144.115',
                'clientName': 'qBittorrent/4.3.8',
                'port': 42032,
                'progress': 0.31,
                'rateToClient': 0,
                'rateToPeer': 12800,
                'isDownloadingFromUs': false,
                'isUploadingToUs': true,
              },
            ],
          },
        ],
      });

      final peers = await adapter.getTaskPeers('7');

      expect(peers.length, 1);
      expect(peers.single.address, '222.213.144.115');
      expect(peers.single.clientName, 'qBittorrent/4.3.8');
      expect(peers.single.progress, 0.31);
      expect(peers.single.uploadSpeed, 12800);
    });

    test('maps options with camelCase fields', () async {
      final adapter = _buildLegacyAdapter({
        'torrents': [
          {
            'bandwidthPriority': -1,
            'honorsSessionLimits': false,
            'downloadLimited': true,
            'downloadLimit': 500,
            'uploadLimited': false,
            'uploadLimit': 0,
            'seedRatioMode': 2,
            'seedRatioLimit': 1.5,
            'idleSeedingLimitMode': 1,
            'idleSeedingLimit': 0,
          },
        ],
      });

      final options = await adapter.getTaskOptions('7');

      expect(options.bandwidthPriority, -1);
      expect(options.honorsSessionLimits, isFalse);
      expect(options.downloadLimited, isTrue);
      expect(options.downloadLimitKBps, 500);
      expect(options.uploadLimited, isFalse);
      expect(options.seedRatioMode, TransmissionLimitMode.custom);
      expect(options.seedRatioLimit, 1.5);
      expect(options.idleLimitMode, TransmissionLimitMode.disabled);
      expect(options.idleLimitMinutes, 0);
    });
  });

  group('TransmissionLimitMode', () {
    test('rpcValue maps correctly', () {
      expect(TransmissionLimitMode.global.rpcValue, 0);
      expect(TransmissionLimitMode.disabled.rpcValue, 1);
      expect(TransmissionLimitMode.custom.rpcValue, 2);
    });

    test('fromRpcValue parses correctly', () {
      expect(
        TransmissionLimitMode.fromRpcValue(0),
        TransmissionLimitMode.global,
      );
      expect(
        TransmissionLimitMode.fromRpcValue(1),
        TransmissionLimitMode.disabled,
      );
      expect(
        TransmissionLimitMode.fromRpcValue(2),
        TransmissionLimitMode.custom,
      );
      expect(
        TransmissionLimitMode.fromRpcValue(99),
        TransmissionLimitMode.global,
      );
    });
  });

  group('TransmissionTaskOptions copyWith', () {
    test('copies changed fields', () {
      const original = TransmissionTaskOptions(
        bandwidthPriority: 0,
        honorsSessionLimits: true,
        downloadLimited: false,
        downloadLimitKBps: 0,
        uploadLimited: false,
        uploadLimitKBps: 0,
        seedRatioMode: TransmissionLimitMode.global,
        seedRatioLimit: 0,
        idleLimitMode: TransmissionLimitMode.global,
        idleLimitMinutes: 0,
      );

      final copied = original.copyWith(
        downloadLimited: true,
        downloadLimitKBps: 100,
      );

      expect(copied.downloadLimited, isTrue);
      expect(copied.downloadLimitKBps, 100);
      expect(copied.uploadLimited, isFalse);
      expect(copied.bandwidthPriority, 0);
    });
  });

  group('TransmissionTaskOptionsUpdate.fromOptions', () {
    test('creates update from options', () {
      const options = TransmissionTaskOptions(
        bandwidthPriority: 1,
        honorsSessionLimits: false,
        downloadLimited: true,
        downloadLimitKBps: 200,
        uploadLimited: true,
        uploadLimitKBps: 500,
        seedRatioMode: TransmissionLimitMode.custom,
        seedRatioLimit: 3.0,
        idleLimitMode: TransmissionLimitMode.disabled,
        idleLimitMinutes: 0,
      );

      final update =
          TransmissionTaskOptionsUpdate.fromOptions(options);

      expect(update.bandwidthPriority, 1);
      expect(update.honorsSessionLimits, isFalse);
      expect(update.downloadLimitKBps, 200);
      expect(update.uploadLimitKBps, 500);
      expect(update.seedRatioMode, TransmissionLimitMode.custom);
      expect(update.seedRatioLimit, 3.0);
    });
  });
}
