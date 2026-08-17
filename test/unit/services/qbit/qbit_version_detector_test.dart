import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/qbit/qbit_api_generation.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';
import 'package:windwalker/services/qbit/qbit_version_detector.dart';

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

  test('detects qBittorrent 4.x as v4Legacy', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('v4.5.2', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.8.3', 200);
      }
      return http.Response('', 404);
    });

    final session = QBitSession(qbit(), client: client);
    final profile = await QBitVersionDetector(session).detect();

    expect(profile.apiGeneration, QBitApiGeneration.v4Legacy);
    expect(profile.appVersion, '4.5.2');
    expect(profile.webApiVersion, '2.8.3');
  });

  test('detects qBittorrent 5.x as v5Modern', () async {
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
      return http.Response('', 404);
    });

    final session = QBitSession(qbit(), client: client);
    final profile = await QBitVersionDetector(session).detect();

    expect(profile.apiGeneration, QBitApiGeneration.v5Modern);
    expect(profile.appVersion, '5.0.0');
    expect(profile.webApiVersion, '2.11.3');
  });

  test('throws on malformed version payload', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('qbittorrent-latest', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.11.3', 200);
      }
      return http.Response('', 404);
    });

    final session = QBitSession(qbit(), client: client);

    expect(
      () => QBitVersionDetector(session).detect(),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects qBittorrent below 4.1', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      if (request.url.path.endsWith('/api/v2/app/version')) {
        return http.Response('v4.0.3', 200);
      }
      if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
        return http.Response('2.7.0', 200);
      }
      return http.Response('', 404);
    });

    final session = QBitSession(qbit(), client: client);

    expect(
      () => QBitVersionDetector(session).detect(),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
