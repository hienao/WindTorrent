import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:windwalker/core/config/build_channel_config.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/update/data/update_service.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

class GitHubReleaseUpdateService implements UpdateService {
  GitHubReleaseUpdateService({
    required ReleaseTrack releaseTrack,
    http.Client? client,
    Future<PackageInfo> Function()? packageInfoLoader,
    ExternalUrlLauncher? urlLauncher,
  }) : _releaseTrack = releaseTrack,
       _client = client ?? http.Client(),
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _urlLauncher = urlLauncher ?? _launchExternalUrl;

  static final Uri _releasesUri = Uri.https(
    'api.github.com',
    '/repos/hienao/WindTorrent/releases',
    <String, String>{'per_page': '100'},
  );

  final ReleaseTrack _releaseTrack;
  final http.Client _client;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final ExternalUrlLauncher _urlLauncher;

  @override
  UpdateSource get source => UpdateSource.githubRelease;

  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final packageInfo = await _packageInfoLoader();
      final currentVersionCode = int.parse(packageInfo.buildNumber);
      final response = await _client.get(
        _releasesUri,
        headers: const <String, String>{
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'WindTorrent-Android',
        },
      );
      if (response.statusCode != 200) {
        throw StateError(
          'GitHub Releases returned HTTP ${response.statusCode}.',
        );
      }

      final payload = jsonDecode(response.body);
      if (payload is! List<dynamic>) {
        throw const FormatException('GitHub Releases response is not a list.');
      }

      final candidates =
          payload
              .whereType<Map<String, dynamic>>()
              .map(_parseRelease)
              .whereType<_GitHubReleaseCandidate>()
              .toList()
            ..sort((a, b) => b.versionCode.compareTo(a.versionCode));

      if (candidates.isEmpty ||
          candidates.first.versionCode <= currentVersionCode) {
        return const UpdateCheckResult.upToDate();
      }

      final latest = candidates.first;
      return UpdateCheckResult.available(
        latest.versionCode,
        versionName: latest.versionName,
        updatePageUrl: latest.releasePageUrl,
      );
    } catch (e, st) {
      Log.e('GitHub update check failed', error: e, stackTrace: st);
      return const UpdateCheckResult.unknown();
    }
  }

  _GitHubReleaseCandidate? _parseRelease(Map<String, dynamic> release) {
    if (release['draft'] != false ||
        release['prerelease'] != (_releaseTrack == ReleaseTrack.beta) ||
        release['target_commitish'] != _releaseTrack.sourceBranch) {
      return null;
    }

    final tagName = release['tag_name'];
    final releasePageUrl = release['html_url'];
    final assets = release['assets'];
    if (tagName is! String ||
        releasePageUrl is! String ||
        assets is! List<dynamic>) {
      return null;
    }

    final versionMatch = _versionPattern.firstMatch(tagName);
    if (versionMatch == null) return null;

    final hasUniversalApk = assets.whereType<Map<String, dynamic>>().any((
      asset,
    ) {
      final name = asset['name'];
      return name is String && name.endsWith('-universal.apk');
    });
    if (!hasUniversalApk) return null;

    return _GitHubReleaseCandidate(
      versionName: versionMatch.group(1)!,
      versionCode: int.parse(versionMatch.group(2)!),
      releasePageUrl: releasePageUrl,
    );
  }

  RegExp get _versionPattern => switch (_releaseTrack) {
    ReleaseTrack.stable => RegExp(r'^v(\d+\.\d+\.\d+)\+(\d+)$'),
    ReleaseTrack.beta => RegExp(r'^v(\d+\.\d+\.\d+-beta\.\d+)\+(\d+)$'),
  };

  @override
  Future<void> openUpdatePage(UpdateCheckResult result) async {
    final rawUrl = result.updatePageUrl;
    if (rawUrl == null) {
      throw StateError('GitHub update result has no release page URL.');
    }
    final launched = await _urlLauncher(Uri.parse(rawUrl));
    if (!launched) {
      throw StateError('Unable to open GitHub Release page: $rawUrl');
    }
  }

  static Future<bool> _launchExternalUrl(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _GitHubReleaseCandidate {
  const _GitHubReleaseCandidate({
    required this.versionName,
    required this.versionCode,
    required this.releasePageUrl,
  });

  final String versionName;
  final int versionCode;
  final String releasePageUrl;
}
