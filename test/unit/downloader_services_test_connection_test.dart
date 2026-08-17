import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/qbit_service.dart';
import 'package:windwalker/services/transmission_service.dart';

void main() {
  group('Aria2Service.testConnection 版本检查', () {
    Downloader aria2() => Downloader(
      id: 'a', name: 'a', type: DownloaderType.aria2,
      host: 'h', port: 6800, secret: 's',
    );

    test('版本达标返回 success 且携带 serverVersion', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({
          'id': 1, 'jsonrpc': '2.0',
          'result': {'version': '1.36.0', 'enabledFeatures': []},
        }), 200,
      ));
      final result = await Aria2Service(aria2(), client: client).testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '1.36.0');
    });

    test('版本过低返回 versionUnsupported', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({
          'id': 1, 'jsonrpc': '2.0',
          'result': {'version': '1.35.0', 'enabledFeatures': []},
        }), 200,
      ));
      final result = await Aria2Service(aria2(), client: client).testConnection();
      expect(result, isA<ConnectionFailure>());
      final f = result as ConnectionFailure;
      expect(f.isVersionUnsupported, isTrue);
      expect(f.actualVersion, '1.35.0');
      expect(f.minVersion, '1.36');
    });

    test('secret 错误(200 + error)返回 authFailed', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode({
          'id': 1, 'jsonrpc': '2.0',
          'error': {'code': 1, 'message': 'Unauthorized'},
        }), 200,
      ));
      final result = await Aria2Service(aria2(), client: client).testConnection();
      expect((result as ConnectionFailure).category,
          ConnectionFailureCategory.authFailed);
    });
  });

  group('QBitService.testConnection 版本检查', () {
    Downloader qbit() => Downloader(
      id: 'q', name: 'q', type: DownloaderType.qbittorrent,
      host: 'h', port: 8080, username: 'u', password: 'p',
    );

    // 登录成功 + 给定 app/version 与 webapiVersion 响应的 MockClient
    http.Client qbitClient({
      required String appVersionBody,
      required String webApiVersionBody,
    }) {
      return MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/api/v2/auth/login')) {
          return http.Response('Ok.', 200,
              headers: {'set-cookie': 'SID=abc; Path=/'});
        }
        if (path.endsWith('/api/v2/app/version')) {
          return http.Response(appVersionBody, 200);
        }
        if (path.endsWith('/api/v2/app/webapiVersion')) {
          return http.Response(webApiVersionBody, 200);
        }
        return http.Response('', 404);
      });
    }

    test('4.x 版本返回 success 携带 serverVersion', () async {
      final result = await QBitService(qbit(),
          client: qbitClient(
              appVersionBody: 'v4.5.0', webApiVersionBody: '2.8.3'))
          .testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '4.5.0');
    });

    test('5.0+ 版本返回 success 携带 serverVersion', () async {
      final result = await QBitService(qbit(),
          client: qbitClient(
              appVersionBody: 'v5.0.0', webApiVersionBody: '2.11.3'))
          .testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '5.0.0');
    });

    test('4.0.x 返回 versionUnsupported', () async {
      final result = await QBitService(qbit(),
          client: qbitClient(
              appVersionBody: 'v4.0.3', webApiVersionBody: '2.7.0'))
          .testConnection();
      final failure = result as ConnectionFailure;
      expect(failure.category, ConnectionFailureCategory.versionUnsupported);
      expect(failure.actualVersion, '4.0.3');
      expect(failure.minVersion, '4.1');
    });

    test('登录失败返回 authFailed', () async {
      final client = MockClient((_) async => http.Response('Fails.', 200));
      final result = await QBitService(qbit(), client: client).testConnection();
      expect((result as ConnectionFailure).category,
          ConnectionFailureCategory.authFailed);
    });
  });

  group('TransmissionService.testConnection 版本检查', () {
    Downloader trans() => Downloader(
      id: 't', name: 't', type: DownloaderType.transmission,
      host: 'h', port: 9091, username: 'u', password: 'p',
    );

    // 首次 409 取 session id，modern session_get 失败，回退 legacy session-get 成功。
    // legacy 响应格式：result:"success" + arguments，字段名为 kebab-case。
    http.Client transModernClient({
      required String semver,
      required String appVersion,
    }) {
      int callCount = 0;
      return MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('', 409,
              headers: {'x-transmission-session-id': 'sid-1'});
        }
        // detector 的 modern session_get 请求 → 返回 JSON-RPC 2.0 成功
        return http.Response(jsonEncode({
          'jsonrpc': '2.0',
          'result': {
            'rpc_version_semver': semver,
            'version': appVersion,
          },
          'id': 1,
        }), 200);
      });
    }

    test('4.1.0+ (rpc 6.0.0) 达标返回 success，携带应用版本', () async {
      final result = await TransmissionService(trans(),
              client: transModernClient(
                  semver: '6.0.0', appVersion: '4.1.0 (ae226418eb)'))
          .testConnection();
      expect(result, isA<ConnectionSuccess>());
      // 显示/记录应用版本（截取首段），而非 RPC 协议版本
      expect((result as ConnectionSuccess).serverVersion, '4.1.0');
    });

    test('4.0.x legacy 版本返回 success（双协议支持后不再拒绝旧版）', () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('', 409,
              headers: {'x-transmission-session-id': 'sid-1'});
        }
        // modern session_get → 返回 legacy 格式（触发回退）
        return http.Response(jsonEncode({
          'result': 'success',
          'arguments': {
            'rpc-version-semver': '5.3.0',
            'version': '4.0.3 (abc12345)',
          },
        }), 200);
      });
      final result =
          await TransmissionService(trans(), client: client).testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '4.0.3');
    });

    // 防御：部分 Transmission 部署回旧协议响应（result:"success" + arguments），
    // 字段名为 kebab 连字符。验证 detector 能自动回退 legacy 并成功。
    test('旧协议响应(arguments+kebab)也能识别 legacy 并返回 success', () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('', 409,
              headers: {'x-transmission-session-id': 'sid-1'});
        }
        // 任何请求都返回 legacy 格式
        return http.Response(jsonEncode({
          'result': 'success',
          'arguments': {
            'rpc-version-semver': '6.0.0',
            'version': '4.1.0 (ae226418eb)',
          },
        }), 200);
      });
      final result =
          await TransmissionService(trans(), client: client).testConnection();
      expect(result, isA<ConnectionSuccess>());
      expect((result as ConnectionSuccess).serverVersion, '4.1.0');
    });
  });
}
