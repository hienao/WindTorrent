/// Transmission 任务选项的限制模式。
enum TransmissionLimitMode {
  /// 使用全局（会话级）设置。
  global,

  /// 不限制。
  disabled,

  /// 使用自定义值。
  custom;

  /// 映射到 modern RPC 的整数值。
  int get rpcValue => switch (this) {
        TransmissionLimitMode.global => 0,
        TransmissionLimitMode.disabled => 1,
        TransmissionLimitMode.custom => 2,
      };

  /// 从 RPC 整数值解析。
  static TransmissionLimitMode fromRpcValue(int value) => switch (value) {
        0 => TransmissionLimitMode.global,
        1 => TransmissionLimitMode.disabled,
        2 => TransmissionLimitMode.custom,
        _ => TransmissionLimitMode.global,
      };
}

/// Transmission 任务选项读取模型。
///
/// 用于选项子页面，表示从 RPC 获取的当前任务级选项。
class TransmissionTaskOptions {
  const TransmissionTaskOptions({
    required this.bandwidthPriority,
    required this.honorsSessionLimits,
    required this.downloadLimited,
    required this.downloadLimitKBps,
    required this.uploadLimited,
    required this.uploadLimitKBps,
    required this.seedRatioMode,
    required this.seedRatioLimit,
    required this.idleLimitMode,
    required this.idleLimitMinutes,
  });

  /// 带宽优先级：-1=低，0=正常，1=高。
  final int bandwidthPriority;

  /// 是否遵循全局会话带宽限制。
  final bool honorsSessionLimits;

  /// 是否启用下载速度限制。
  final bool downloadLimited;

  /// 下载速度限制（KB/s）。
  final int downloadLimitKBps;

  /// 是否启用上传速度限制。
  final bool uploadLimited;

  /// 上传速度限制（KB/s）。
  final int uploadLimitKBps;

  /// 做种比率限制模式。
  final TransmissionLimitMode seedRatioMode;

  /// 做种比率限制值。
  final double seedRatioLimit;

  /// 空闲做种限制模式。
  final TransmissionLimitMode idleLimitMode;

  /// 空闲做种限制时间（分钟）。
  final int idleLimitMinutes;

  /// 创建修改后的副本。
  TransmissionTaskOptions copyWith({
    int? bandwidthPriority,
    bool? honorsSessionLimits,
    bool? downloadLimited,
    int? downloadLimitKBps,
    bool? uploadLimited,
    int? uploadLimitKBps,
    TransmissionLimitMode? seedRatioMode,
    double? seedRatioLimit,
    TransmissionLimitMode? idleLimitMode,
    int? idleLimitMinutes,
  }) {
    return TransmissionTaskOptions(
      bandwidthPriority: bandwidthPriority ?? this.bandwidthPriority,
      honorsSessionLimits: honorsSessionLimits ?? this.honorsSessionLimits,
      downloadLimited: downloadLimited ?? this.downloadLimited,
      downloadLimitKBps: downloadLimitKBps ?? this.downloadLimitKBps,
      uploadLimited: uploadLimited ?? this.uploadLimited,
      uploadLimitKBps: uploadLimitKBps ?? this.uploadLimitKBps,
      seedRatioMode: seedRatioMode ?? this.seedRatioMode,
      seedRatioLimit: seedRatioLimit ?? this.seedRatioLimit,
      idleLimitMode: idleLimitMode ?? this.idleLimitMode,
      idleLimitMinutes: idleLimitMinutes ?? this.idleLimitMinutes,
    );
  }
}
