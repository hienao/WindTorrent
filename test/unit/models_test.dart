// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/core/constants/app_constants.dart';

void main() {
  group('DownloadTask Model Tests', () {
    test('should parse from JSON correctly', () {
      final json = {
        'gid': '12345',
        'name': 'test-file.mp4',
        'totalSize': 1024000,
        'completedLength': 512000,
        'downloadSpeed': 102400,
        'status': 'downloading',
        'dir': '/downloads',
        'downloaderId': 'aria2-1',
      };

      final task = DownloadTask.fromJson(json);

      expect(task.gid, '12345');
      expect(task.name, 'test-file.mp4');
      expect(task.totalSize, 1024000);
      expect(task.downloaded, 512000);
      expect(task.status, TaskStatus.downloading);
    });

    test('should format size correctly', () {
      final task = DownloadTask(
        id: '1',
        gid: '1',
        name: 'test',
        totalSize: 1024 * 1024 * 1024, // 1 GB
        downloaderId: 'test',
      );

      expect(task.formattedSize, contains('GB'));
    });

    test('copyWith should work correctly', () {
      final task = DownloadTask(
        id: '1',
        gid: '1',
        name: 'test',
        status: TaskStatus.downloading,
        downloaderId: 'test',
      );

      final pausedTask = task.copyWith(status: TaskStatus.paused);

      expect(pausedTask.status, TaskStatus.paused);
      expect(pausedTask.name, 'test');
    });
  });

  group('Downloader Model Tests', () {
    test('should create from JSON correctly', () {
      final json = {
        'id': 'aria2-1',
        'name': 'My Aria2',
        'type': 'aria2',
        'host': '192.168.1.100',
        'port': 6800,
        'secret': 'mypassword',
        'status': 'online',
      };

      final downloader = Downloader.fromJson(json);

      expect(downloader.id, 'aria2-1');
      expect(downloader.name, 'My Aria2');
      expect(downloader.type, DownloaderType.aria2);
      expect(downloader.status, DownloaderStatus.online);
    });
  });
}
