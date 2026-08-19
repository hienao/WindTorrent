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

    test('GitHub 仓库与 Issues 地址指向 WindTorrent', () {
      expect(
        AppConstants.githubRepositoryUrl,
        'https://github.com/hienao/WindTorrent',
      );
      expect(
        AppConstants.githubIssuesUrl,
        '${AppConstants.githubRepositoryUrl}/issues',
      );
    });

    test('playStoreUrl 指向正确的包名', () {
      final uri = Uri.parse(AppConstants.playStoreUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, 'play.google.com');
      expect(uri.queryParameters['id'], 'com.hienao.windtorrent');
    });
  });
}
