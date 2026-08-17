import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit_service.dart';
import 'package:windwalker/services/transmission_service.dart';

void main() {
  group('Aria2Service addTask torrent', () {
    test('should call aria2.addTorrent with base64 encoded torrent', () async {
      late Map<String, dynamic> payload;

      final client = MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 1,
            'jsonrpc': '2.0',
            'result': '2089b10ebee335a0',
          }),
          200,
        );
      });

      final service = Aria2Service(
        Downloader(
          id: 'aria2-test',
          name: 'Test Aria2',
          type: DownloaderType.aria2,
          host: 'localhost',
          port: 6800,
        ),
        client: client,
      );

      final result = await service.addTask(
        AddTaskRequest(
          downloaderId: 'aria2-test',
          torrentFileName: 'demo.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      expect(result, '2089b10ebee335a0');
      expect(payload['method'], 'aria2.addTorrent');
      expect(payload['params'][1], base64Encode([1, 2, 3]));
    });

    test('should pass savePath as dir option', () async {
      late Map<String, dynamic> payload;

      final client = MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'id': 1, 'jsonrpc': '2.0', 'result': 'gid123'}),
          200,
        );
      });

      final service = Aria2Service(
        Downloader(
          id: 'aria2-test',
          name: 'Test Aria2',
          type: DownloaderType.aria2,
          host: 'localhost',
          port: 6800,
        ),
        client: client,
      );

      await service.addTask(
        AddTaskRequest(
          downloaderId: 'aria2-test',
          torrentFileName: 'demo.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
          savePath: '/downloads',
        ),
      );

      final params = payload['params'] as List;
      // params layout: [token, base64, [], {'dir': '/downloads'}]
      // options map is at params[3]
      expect(params.length, 4);
      expect((params[3] as Map)['dir'], '/downloads');
    });

    test('should throw DownloaderServiceException when result is null', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'id': 1, 'jsonrpc': '2.0', 'result': null}),
          200,
        );
      });

      final service = Aria2Service(
        Downloader(
          id: 'aria2-test',
          name: 'Test Aria2',
          type: DownloaderType.aria2,
          host: 'localhost',
          port: 6800,
        ),
        client: client,
      );

      expect(
        () => service.addTask(
          AddTaskRequest(
            downloaderId: 'aria2-test',
            torrentFileName: 'demo.torrent',
            torrentFileBytes: Uint8List.fromList([1, 2, 3]),
          ),
        ),
        throwsA(isA<DownloaderServiceException>()),
      );
    });
  });

  group('QBitService addTask torrent', () {
    Downloader qbit() => Downloader(
      id: 'qbit-test',
      name: 'Test QBit',
      type: DownloaderType.qbittorrent,
      host: 'localhost',
      port: 8080,
      username: 'admin',
      password: 'admin',
    );

    // 响应 detect 所需的 login/version/webapiVersion（v5 modern），
    // 其余请求（torrents/add 等）交由 [other] 决定响应。
    http.Client qbitClient(
      Future<http.StreamedResponse> Function(http.BaseRequest request) other,
    ) {
      return MockClient.streaming((request, bodyStream) async {
        await bodyStream.toBytes();
        final path = request.url.path;
        if (path.endsWith('/api/v2/auth/login')) {
          return http.StreamedResponse(
            http.ByteStream.fromBytes(utf8.encode('Ok.')),
            200,
            headers: {'set-cookie': 'SID=abc; Path=/'},
          );
        }
        if (path.endsWith('/api/v2/app/version')) {
          return http.StreamedResponse(
            http.ByteStream.fromBytes(utf8.encode('v5.0.0')),
            200,
          );
        }
        if (path.endsWith('/api/v2/app/webapiVersion')) {
          return http.StreamedResponse(
            http.ByteStream.fromBytes(utf8.encode('2.11.3')),
            200,
          );
        }
        return other(request);
      });
    }

    test('should upload torrent as multipart form data', () async {
      // Use MockClient.streaming to intercept the raw BaseRequest,
      // which preserves the MultipartRequest type.
      http.BaseRequest? capturedBase;
      final client = qbitClient((request) async {
        capturedBase = request;
        return http.StreamedResponse(
          http.ByteStream.fromBytes(utf8.encode('Ok.')),
          200,
          contentLength: 3,
        );
      });

      final service = QBitService(qbit(), client: client);

      final result = await service.addTask(
        AddTaskRequest(
          downloaderId: 'qbit-test',
          torrentFileName: 'demo.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      expect(result, 'ok');
      expect(capturedBase, isNotNull);
      expect(capturedBase, isA<http.MultipartRequest>());
      final multipart = capturedBase! as http.MultipartRequest;
      expect(multipart.method, 'POST');
      expect(multipart.url.path, endsWith('/api/v2/torrents/add'));
      expect(
        multipart.files.any((f) => f.field == 'torrents'),
        isTrue,
      );
    });

    test('should include savepath field when savePath is provided', () async {
      http.BaseRequest? capturedBase;
      final client = qbitClient((request) async {
        capturedBase = request;
        return http.StreamedResponse(
          http.ByteStream.fromBytes(utf8.encode('Ok.')),
          200,
        );
      });

      final service = QBitService(qbit(), client: client);

      await service.addTask(
        AddTaskRequest(
          downloaderId: 'qbit-test',
          torrentFileName: 'demo.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
          savePath: '/downloads',
        ),
      );

      expect(capturedBase, isA<http.MultipartRequest>());
      final multipart = capturedBase! as http.MultipartRequest;
      expect(multipart.fields['savepath'], '/downloads');
    });

    test('should not include savepath field when savePath is null', () async {
      http.BaseRequest? capturedBase;
      final client = qbitClient((request) async {
        capturedBase = request;
        return http.StreamedResponse(
          http.ByteStream.fromBytes(utf8.encode('Ok.')),
          200,
        );
      });

      final service = QBitService(qbit(), client: client);

      await service.addTask(
        AddTaskRequest(
          downloaderId: 'qbit-test',
          torrentFileName: 'demo.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      expect(capturedBase, isA<http.MultipartRequest>());
      final multipart = capturedBase! as http.MultipartRequest;
      expect(multipart.fields.containsKey('savepath'), isFalse);
    });

    test('should throw DownloaderServiceException on non-200 response', () async {
      final client = qbitClient((request) async => http.StreamedResponse(
            http.ByteStream.fromBytes(utf8.encode('Forbidden')),
            403,
          ));

      final service = QBitService(qbit(), client: client);

      expect(
        () => service.addTask(
          AddTaskRequest(
            downloaderId: 'qbit-test',
            torrentFileName: 'demo.torrent',
            torrentFileBytes: Uint8List.fromList([1, 2, 3]),
          ),
        ),
        throwsA(isA<DownloaderServiceException>()),
      );
    });
  });

  group('TransmissionService addTask torrent', () {
    test('should use metainfo field with base64 encoded torrent', () async {
      late Map<String, dynamic> payload;

      final client = MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'torrent_added': {'id': 7}
            }
          }),
          200,
        );
      });

      final service = TransmissionService(
        Downloader(
          id: 'tx-test',
          name: 'Test Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
          username: 'admin',
          password: 'admin',
        ),
        client: client,
      );

      final result = await service.addTask(
        AddTaskRequest(
          downloaderId: 'tx-test',
          torrentFileName: 'demo.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      expect(result, '7');
      final params = payload['params'] as Map<String, dynamic>;
      expect(params['metainfo'], base64Encode([1, 2, 3]));
    });

    test('should pass download_dir when savePath is provided', () async {
      late Map<String, dynamic> payload;

      final client = MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'torrent_added': {'id': 8}
            }
          }),
          200,
        );
      });

      final service = TransmissionService(
        Downloader(
          id: 'tx-test',
          name: 'Test Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
          username: 'admin',
          password: 'admin',
        ),
        client: client,
      );

      await service.addTask(
        AddTaskRequest(
          downloaderId: 'tx-test',
          torrentFileName: 'demo.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
          savePath: '/downloads',
        ),
      );

      final params = payload['params'] as Map<String, dynamic>;
      expect(params['download_dir'], '/downloads');
    });

    test('should handle torrent_duplicate response', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'torrent_duplicate': {'id': 42}
            }
          }),
          200,
        );
      });

      final service = TransmissionService(
        Downloader(
          id: 'tx-test',
          name: 'Test Transmission',
          type: DownloaderType.transmission,
          host: 'localhost',
          port: 9091,
          username: 'admin',
          password: 'admin',
        ),
        client: client,
      );

      final result = await service.addTask(
        AddTaskRequest(
          downloaderId: 'tx-test',
          torrentFileName: 'dup.torrent',
          torrentFileBytes: Uint8List.fromList([1, 2, 3]),
        ),
      );

      expect(result, '42');
    });
  });
}
