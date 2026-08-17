import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';
import 'package:windwalker/services/qbit/qbit_v4_adapter.dart';
import 'package:windwalker/services/qbit/qbit_v5_adapter.dart';

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

  test('v4 pause/resume use pause and resume endpoints', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      return http.Response('', 200);
    });

    final session = QBitSession(qbit(), client: client);
    final adapter = QBitV4Adapter(session);

    await adapter.pauseTask('hash-1');
    await adapter.resumeTask('hash-1');

    expect(paths, contains('/api/v2/torrents/pause'));
    expect(paths, contains('/api/v2/torrents/resume'));
  });

  test('v5 pause/resume use stop and start endpoints', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/api/v2/auth/login')) {
        return http.Response('Ok.', 200,
            headers: {'set-cookie': 'SID=abc; Path=/'});
      }
      return http.Response('', 200);
    });

    final session = QBitSession(qbit(), client: client);
    final adapter = QBitV5Adapter(session);

    await adapter.pauseTask('hash-1');
    await adapter.resumeTask('hash-1');

    expect(paths, contains('/api/v2/torrents/stop'));
    expect(paths, contains('/api/v2/torrents/start'));
  });
}
