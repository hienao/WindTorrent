import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:windwalker/core/config/build_channel_config.dart';
import 'package:windwalker/features/update/data/github_release_update_service.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

PackageInfo _packageInfo({String buildNumber = '2026081901'}) => PackageInfo(
  appName: 'WindTorrent',
  packageName: 'com.hienao.windtorrent',
  version: '1.2.0',
  buildNumber: buildNumber,
  buildSignature: '',
);

Map<String, Object> _release({
  required String tag,
  required String branch,
  required bool prerelease,
  bool draft = false,
  bool includeUniversal = true,
}) => <String, Object>{
  'tag_name': tag,
  'target_commitish': branch,
  'html_url': 'https://github.com/hienao/WindTorrent/releases/tag/$tag',
  'draft': draft,
  'prerelease': prerelease,
  'assets': <Map<String, Object>>[
    if (includeUniversal)
      <String, Object>{'name': 'WindTorrent-$tag-universal.apk'},
  ],
};

GitHubReleaseUpdateService _service({
  required ReleaseTrack track,
  required List<Map<String, Object>> releases,
  String buildNumber = '2026081901',
  Future<bool> Function(Uri)? launcher,
}) => GitHubReleaseUpdateService(
  releaseTrack: track,
  client: MockClient(
    (request) async => http.Response(jsonEncode(releases), 200),
  ),
  packageInfoLoader: () async => _packageInfo(buildNumber: buildNumber),
  urlLauncher: launcher,
);

void main() {
  test('stable checks only non-prerelease releases targeting main', () async {
    final service = _service(
      track: ReleaseTrack.stable,
      releases: <Map<String, Object>>[
        _release(tag: 'v1.3.0+2026081904', branch: 'beta', prerelease: false),
        _release(tag: 'v1.2.1+2026081903', branch: 'main', prerelease: false),
        _release(
          tag: 'v1.3.0-beta.1+2026081905',
          branch: 'main',
          prerelease: true,
        ),
      ],
    );

    final result = await service.checkForUpdate();

    expect(result.status, UpdateCheckStatus.available);
    expect(result.availableVersionCode, 2026081903);
    expect(result.availableVersionName, '1.2.1');
  });

  test('beta checks only prereleases targeting beta', () async {
    final service = _service(
      track: ReleaseTrack.beta,
      releases: <Map<String, Object>>[
        _release(tag: 'v1.3.0+2026081906', branch: 'main', prerelease: false),
        _release(
          tag: 'v1.3.0-beta.2+2026081905',
          branch: 'beta',
          prerelease: true,
        ),
      ],
    );

    final result = await service.checkForUpdate();

    expect(result.status, UpdateCheckStatus.available);
    expect(result.availableVersionCode, 2026081905);
    expect(result.availableVersionName, '1.3.0-beta.2');
  });

  test('ignores releases without a universal APK', () async {
    final service = _service(
      track: ReleaseTrack.beta,
      releases: <Map<String, Object>>[
        _release(
          tag: 'v1.3.0-beta.2+2026081905',
          branch: 'beta',
          prerelease: true,
          includeUniversal: false,
        ),
      ],
    );

    final result = await service.checkForUpdate();

    expect(result.status, UpdateCheckStatus.upToDate);
  });

  test('opens the selected GitHub Release page', () async {
    Uri? openedUri;
    final service = _service(
      track: ReleaseTrack.beta,
      releases: const <Map<String, Object>>[],
      launcher: (uri) async {
        openedUri = uri;
        return true;
      },
    );
    const result = UpdateCheckResult.available(
      2026081905,
      updatePageUrl:
          'https://github.com/hienao/WindTorrent/releases/tag/v1.3.0-beta.2',
    );

    await service.openUpdatePage(result);

    expect(openedUri?.host, 'github.com');
  });
}
