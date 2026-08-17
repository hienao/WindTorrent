/// 下载器速度配置 (统一单位: KB/s)
class DownloaderSpeedConfig {
  /// 速度限制模式开关
  final bool speedLimitModeEnabled;

  /// 正常模式 - 下载限速 (KB/s), 0 = unlimited
  final int downloadLimitKB;

  /// 正常模式 - 上传限速 (KB/s), 0 = unlimited
  final int uploadLimitKB;

  /// 备用模式 - 下载限速 (KB/s), 0 = unlimited (Transmission alt-speed)
  final int altDownloadLimitKB;

  /// 备用模式 - 上传限速 (KB/s), 0 = unlimited (Transmission alt-speed)
  final int altUploadLimitKB;

  const DownloaderSpeedConfig({
    this.speedLimitModeEnabled = false,
    this.downloadLimitKB = 0,
    this.uploadLimitKB = 0,
    this.altDownloadLimitKB = 0,
    this.altUploadLimitKB = 0,
  });

  DownloaderSpeedConfig copyWith({
    bool? speedLimitModeEnabled,
    int? downloadLimitKB,
    int? uploadLimitKB,
    int? altDownloadLimitKB,
    int? altUploadLimitKB,
  }) {
    return DownloaderSpeedConfig(
      speedLimitModeEnabled:
          speedLimitModeEnabled ?? this.speedLimitModeEnabled,
      downloadLimitKB: downloadLimitKB ?? this.downloadLimitKB,
      uploadLimitKB: uploadLimitKB ?? this.uploadLimitKB,
      altDownloadLimitKB: altDownloadLimitKB ?? this.altDownloadLimitKB,
      altUploadLimitKB: altUploadLimitKB ?? this.altUploadLimitKB,
    );
  }
}
