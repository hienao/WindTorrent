import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/downloaders/presentation/utils/downloader_host_input.dart';

void main() {
  group('normalizeDownloaderHostInput', () {
    test('removes normal HTTP and HTTPS prefixes case-insensitively', () {
      expect(
        normalizeDownloaderHostInput('https://example.com'),
        'example.com',
      );
      expect(
        normalizeDownloaderHostInput('HTTP://192.168.1.10'),
        '192.168.1.10',
      );
    });

    test('removes escaped HTTP and HTTPS prefixes', () {
      expect(
        normalizeDownloaderHostInput(r'https\://example.com'),
        'example.com',
      );
      expect(normalizeDownloaderHostInput(r'http\://localhost'), 'localhost');
    });

    test('trims whitespace and removes repeated prefixes', () {
      expect(
        normalizeDownloaderHostInput('  https://http://example.com  '),
        'example.com',
      );
    });

    test('does not alter a scheme-free server address', () {
      expect(normalizeDownloaderHostInput('192.168.1.10'), '192.168.1.10');
    });
  });
}
