class DownloaderBackupVersion {
  const DownloaderBackupVersion({
    required this.fileId,
    required this.fileName,
    required this.backupId,
    required this.createdAt,
    required this.appVersion,
    required this.downloaderCount,
    required this.isLatest,
  });

  final String fileId;
  final String fileName;
  final String backupId;
  final DateTime createdAt;
  final String appVersion;
  final int downloaderCount;
  final bool isLatest;
}
