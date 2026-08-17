import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/models/add_task_request.dart';

void main() {
  group('AddTaskRequest', () {
    test('url 请求应被识别为合法来源', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        url: 'magnet:?xt=urn:btih:test',
      );

      expect(request.hasUrlSource, isTrue);
      expect(request.hasTorrentSource, isFalse);
      expect(request.isValidSourceSelection, isTrue);
    });

    test('torrent 请求应被识别为合法来源', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        torrentFileName: 'demo.torrent',
        torrentFileBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(request.hasUrlSource, isFalse);
      expect(request.hasTorrentSource, isTrue);
      expect(request.isValidSourceSelection, isTrue);
    });

    test('同时存在 url 和 torrent 时应视为非法提交', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        url: 'https://example.com/file.iso',
        torrentFileName: 'demo.torrent',
        torrentFileBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(request.isValidSourceSelection, isFalse);
    });

    test('torrent 缺少文件名时应视为非法提交', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        torrentFileBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(request.isValidSourceSelection, isFalse);
    });

    test('无来源时 isValidSourceSelection 应为 false', () {
      final request = AddTaskRequest(downloaderId: 'd1');

      expect(request.hasUrlSource, isFalse);
      expect(request.hasTorrentSource, isFalse);
      expect(request.isValidSourceSelection, isFalse);
    });

    test('空白 url 不应被视为有效来源', () {
      final request = AddTaskRequest(downloaderId: 'd1', url: '   ');

      expect(request.hasUrlSource, isFalse);
      expect(request.isValidSourceSelection, isFalse);
    });
  });

  group('AddTaskRequest copyWith', () {
    test('copyWith clearTorrent 应清空 torrent 来源', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        torrentFileName: 'demo.torrent',
        torrentFileBytes: Uint8List.fromList([1, 2, 3]),
      );

      final cleared = request.copyWith(clearTorrent: true);

      expect(cleared.torrentFileName, isNull);
      expect(cleared.torrentFileBytes, isNull);
    });

    test('copyWith clearUrl 应清空 url', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        url: 'https://example.com/file.iso',
      );

      final cleared = request.copyWith(clearUrl: true);

      expect(cleared.url, isNull);
    });

    test('copyWith 普通字段替换应保留未修改字段', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        url: 'https://example.com/file.iso',
        savePath: '/downloads',
      );

      final modified = request.copyWith(downloaderId: 'd2', url: 'magnet:?xt=urn:btih:new');

      expect(modified.downloaderId, 'd2');
      expect(modified.url, 'magnet:?xt=urn:btih:new');
      expect(modified.savePath, '/downloads');
    });
  });
}
