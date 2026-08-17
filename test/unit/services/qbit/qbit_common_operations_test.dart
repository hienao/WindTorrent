import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/qbit_service.dart';

void main() {
  Downloader qbit() => Downloader(
    id: 'q',
    name: 'q',
    type: DownloaderType.qbittorrent,
    host: 'localhost',
    port: 8080,
    username: 'admin',
    password: 'admin',
  );

  AddTaskRequest torrentRequest() => AddTaskRequest(
    downloaderId: 'q',
    torrentFileName: 'demo.torrent',
    torrentFileBytes: Uint8List.fromList([1, 2, 3]),
  );

  test('addTask uploads torrent through facade', () async {
    http.BaseRequest? capturedBase;
    var versionReads = 0;

    final client = MockClient.streaming((request, bodyStream) async {
      capturedBase = request;
      await bodyStream.toBytes();
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.StreamedResponse(
          http.ByteStream.fromBytes('Ok.'.codeUnits),
          200,
          headers: {'set-cookie': 'SID=abc; Path=/'},
        );
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        versionReads++;
        return http.StreamedResponse(
          http.ByteStream.fromBytes('v4.5.0'.codeUnits),
          200,
        );
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.StreamedResponse(
          http.ByteStream.fromBytes('2.8.3'.codeUnits),
          200,
        );
      }
      return http.StreamedResponse(
        http.ByteStream.fromBytes('Ok.'.codeUnits),
        200,
      );
    });

    final service = QBitService(qbit(), client: client);
    await service.addTask(torrentRequest());

    expect(capturedBase, isA<http.MultipartRequest>());
    // 经 facade adapter 必然触发一次探测
    expect(versionReads, 1);
  });

  test('getDefaultSavePath reads dedicated default-save-path endpoint', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('v5.0.0', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.11.3', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/defaultSavePath')) {
        return http.Response('/downloads/media', 200);
      }
      return http.Response('', 404);
    });

    final service = QBitService(qbit(), client: client);
    final path = await service.getDefaultSavePath();

    expect(path, '/downloads/media');
  });

  test('getSpeedConfig reads shared preferences endpoint', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('v5.0.0', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.11.3', 200);
      }
      if (request.url.path.endsWith('/api/v2/transfer/speedLimitsMode')) {
        return http.Response('1', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/preferences')) {
        return http.Response(
            '{"dl_limit":10,"up_limit":20,"alt_dl_limit":30,"alt_up_limit":40}',
            200);
      }
      return http.Response('', 404);
    });

    final service = QBitService(qbit(), client: client);
    final config = await service.getSpeedConfig();

    expect(config.speedLimitModeEnabled, isTrue);
    expect(config.downloadLimitKB, 10);
    expect(config.uploadLimitKB, 20);
  });
}
