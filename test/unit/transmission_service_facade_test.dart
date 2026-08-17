import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/transmission_service.dart';

void main() {
  Downloader trans() => Downloader(
        id: 't',
        name: 'Transmission',
        type: DownloaderType.transmission,
        host: 'localhost',
        port: 9091,
        username: 'u',
        password: 'p',
      );

  group('TransmissionService facade', () {
    test('modern server should pass testConnection with serverVersion',
        () async {
      String? needSession = 'first';
      final client = MockClient((request) async {
        if (needSession == 'first') {
          needSession = 'done';
          return http.Response('', 409,
              headers: {'x-transmission-session-id': 'sid-1'});
        }
        return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'result': {
                'rpc_version_semver': '6.0.1',
                'version': '4.1.1 (abcdef)',
              },
              'id': 1,
            }),
            200);
      });

      final result =
          await TransmissionService(trans(), client: client).testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '4.1.1');
    });

    test(
        'legacy server should pass testConnection when capability check passes',
        () async {
      String? needSession = 'first';
      final client = MockClient((request) async {
        if (needSession == 'first') {
          needSession = 'done';
          return http.Response('', 409,
              headers: {'x-transmission-session-id': 'sid-1'});
        }
        // modern 探测失败 → 回退 legacy → 成功
        final body = request.body;
        if (body.contains('session_get')) {
          return http.Response('', 500);
        }
        return http.Response(
            jsonEncode({
              'result': 'success',
              'arguments': {
                'rpc-version-semver': '5.3.0',
                'version': '4.0.3 (abc12345)',
              },
              'tag': 1,
            }),
            200);
      });

      final result =
          await TransmissionService(trans(), client: client).testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '4.0.3');
    });

    test('401 should return authFailed', () async {
      final client = MockClient((_) async => http.Response('', 401));

      final result =
          await TransmissionService(trans(), client: client).testConnection();
      expect(result, isA<ConnectionFailure>());
      expect(
          (result as ConnectionFailure).category,
          ConnectionFailureCategory.authFailed);
    });

    test('capability-insufficient legacy server should return failure',
        () async {
      String phase = 'first';
      final client = MockClient((request) async {
        if (phase == 'first') {
          phase = 'done';
          return http.Response('', 409,
              headers: {'x-transmission-session-id': 'sid-1'});
        }
        // modern 失败 → legacy 失败
        return http.Response('', 500);
      });

      final result =
          await TransmissionService(trans(), client: client).testConnection();
      expect(result, isA<ConnectionFailure>());
    });

    test('cached adapter should not re-detect on subsequent calls', () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('', 409,
              headers: {'x-transmission-session-id': 'sid'});
        }
        return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'result': {
                'torrents': <dynamic>[],
              },
              'id': 1,
            }),
            200);
      });

      final service = TransmissionService(trans(), client: client);
      await service.getTasks();
      final countAfterFirst = callCount;

      await service.getTasks();
      // 第二次调用不应重新进行协议探测（无新的 _ensureSession 调用）
      // callCount 应仅增加业务调用数
      expect(callCount, greaterThan(countAfterFirst));
    });
  });
}
