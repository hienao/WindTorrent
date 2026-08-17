import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
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

  test('service detects once and reuses adapter for multiple operations',
      () async {
    var versionReads = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        versionReads++;
        return http.Response('v4.5.0', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.8.3', 200);
      }
      return http.Response('', 200);
    });

    final service = QBitService(qbit(), client: client);
    await service.testConnection();
    await service.pauseTask('hash-1');
    await service.resumeTask('hash-1');

    expect(versionReads, 1);
  });

  test('403 on pause triggers one re-login and retry', () async {
    var pauseCalls = 0;
    var loginCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        loginCalls++;
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('v5.0.0', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.11.3', 200);
      }
      if (request.url.path.endsWith('/api/v2/torrents/stop')) {
        pauseCalls++;
        return pauseCalls == 1
            ? http.Response('', 403)
            : http.Response('', 200);
      }
      return http.Response('', 200);
    });

    final service = QBitService(qbit(), client: client);
    await service.pauseTask('hash-1');

    expect(loginCalls, 2);
    expect(pauseCalls, 2);
  });
}
