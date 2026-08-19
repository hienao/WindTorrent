enum UpdateCheckStatus { unsupported, unknown, upToDate, available }

enum UpdateSource {
  playStore('play_store'),
  githubRelease('github_release');

  const UpdateSource(this.analyticsValue);

  final String analyticsValue;
}

class UpdateCheckResult {
  const UpdateCheckResult._({
    required this.status,
    this.availableVersionCode,
    this.availableVersionName,
    this.updatePageUrl,
  });

  const UpdateCheckResult.unsupported()
    : this._(status: UpdateCheckStatus.unsupported);

  const UpdateCheckResult.unknown() : this._(status: UpdateCheckStatus.unknown);

  const UpdateCheckResult.upToDate()
    : this._(status: UpdateCheckStatus.upToDate);

  const UpdateCheckResult.available(
    int versionCode, {
    String? versionName,
    String? updatePageUrl,
  }) : this._(
         status: UpdateCheckStatus.available,
         availableVersionCode: versionCode,
         availableVersionName: versionName,
         updatePageUrl: updatePageUrl,
       );

  final UpdateCheckStatus status;
  final int? availableVersionCode;
  final String? availableVersionName;
  final String? updatePageUrl;

  bool get hasUpdate => status == UpdateCheckStatus.available;
}
