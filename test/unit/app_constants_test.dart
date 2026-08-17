import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';

void main() {
  group('支持入口常量', () {
    test('privacyPolicyUrl 是合法的 https URL', () {
      final uri = Uri.parse(AppConstants.privacyPolicyUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, 'windtorrent-hienao.web.app');
      expect(uri.path, '/privacy-policy');
    });

    test('developerEmail 是合法邮箱格式', () {
      expect(AppConstants.developerEmail, contains('@'));
      expect(AppConstants.developerEmail, 'shiwentao666@gmail.com');
    });

    test('playStoreUrl 指向正确的包名', () {
      final uri = Uri.parse(AppConstants.playStoreUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, 'play.google.com');
      expect(uri.queryParameters['id'], 'com.hienao.windtorrent');
    });
  });
}
