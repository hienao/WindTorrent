import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/transmission/transmission_protocol_detector.dart';
import 'package:windwalker/services/transmission/transmission_protocol_info.dart';

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

  test('modern session_get response should be detected as modern', () async {
    String phase = 'first';
    final client = MockClient((request) async {
      if (phase == 'first') {
        phase = 'done';
        return http.Response('', 409, headers: {
          'x-transmission-session-id': 'sid-1',
        });
      }
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'result': {
            'rpc_version_semver': '6.0.1',
            'version': '4.1.1 (rev)',
          },
          'id': 1,
        }),
        200,
      );
    });

    final result =
        await TransmissionProtocolDetector(trans(), client: client).detect();

    expect(result.protocol, TransmissionProtocol.modern);
    expect(result.info!.appVersion, '4.1.1');
    expect(result.info!.rpcSemver, '6.0.1');
    expect(result.info!.sessionId, 'sid-1');
  });

  test('legacy response should be detected after modern fallback', () async {
    final responses = <http.Response>[
      http.Response('', 409, headers: {'x-transmission-session-id': 'sid-2'}),
      http.Response('', 500),
      http.Response(
        jsonEncode({
          'result': 'success',
          'arguments': {
            'rpc-version-semver': '5.3.0',
            'version': '4.0.3 (rev)',
          },
          'tag': 1,
        }),
        200,
      ),
    ];

    final client = MockClient((_) async => responses.removeAt(0));

    final result =
        await TransmissionProtocolDetector(trans(), client: client).detect();

    expect(result.protocol, TransmissionProtocol.legacy);
    expect(result.info!.appVersion, '4.0.3');
    expect(result.info!.rpcSemver, '5.3.0');
  });

  test('401 should surface authFailed detection result', () async {
    final client = MockClient((_) async => http.Response('', 401));

    final result =
        await TransmissionProtocolDetector(trans(), client: client).detect();

    expect(result.failureCategory, TransmissionDetectionFailure.authFailed);
  });

  test('modern success should carry sessionId from 409', () async {
    String phase = 'first';
    final client = MockClient((request) async {
      if (phase == 'first') {
        phase = 'done';
        return http.Response('', 409, headers: {
          'x-transmission-session-id': 'my-session-token',
        });
      }
      return http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'result': {
            'version': '4.2.0 (abcdef)',
            'rpc_version_semver': '6.1.0',
          },
          'id': 1,
        }),
        200,
      );
    });

    final result =
        await TransmissionProtocolDetector(trans(), client: client).detect();

    expect(result.isSuccess, isTrue);
    expect(result.info!.sessionId, 'my-session-token');
    expect(result.protocol, TransmissionProtocol.modern);
    expect(result.info!.appVersion, '4.2.0');
  });

  test('both modern and legacy should fail with networkError', () async {
    final client = MockClient((_) async => http.Response('', 502));

    final result =
        await TransmissionProtocolDetector(trans(), client: client).detect();

    expect(result.failureCategory, TransmissionDetectionFailure.networkError);
  });
}
