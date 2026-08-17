enum UpdateCheckStatus {
  unsupported,
  unknown,
  upToDate,
  available,
}

class UpdateCheckResult {
  const UpdateCheckResult._({
    required this.status,
    this.availableVersionCode,
  });

  const UpdateCheckResult.unsupported()
      : this._(status: UpdateCheckStatus.unsupported);

  const UpdateCheckResult.unknown()
      : this._(status: UpdateCheckStatus.unknown);

  const UpdateCheckResult.upToDate()
      : this._(status: UpdateCheckStatus.upToDate);

  const UpdateCheckResult.available(int versionCode)
      : this._(
          status: UpdateCheckStatus.available,
          availableVersionCode: versionCode,
        );

  final UpdateCheckStatus status;
  final int? availableVersionCode;

  bool get hasUpdate => status == UpdateCheckStatus.available;
}
