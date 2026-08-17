import 'package:windwalker/models/transmission_task_options.dart';

/// Transmission 任务选项更新载荷。
///
/// 用于 `torrent-set` RPC 调用，将用户编辑的选项保存到服务器。
class TransmissionTaskOptionsUpdate {
  const TransmissionTaskOptionsUpdate({
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

  final int bandwidthPriority;
  final bool honorsSessionLimits;
  final bool downloadLimited;
  final int downloadLimitKBps;
  final bool uploadLimited;
  final int uploadLimitKBps;
  final TransmissionLimitMode seedRatioMode;
  final double seedRatioLimit;
  final TransmissionLimitMode idleLimitMode;
  final int idleLimitMinutes;

  /// 从已加载的 [TransmissionTaskOptions] 创建更新载荷。
  factory TransmissionTaskOptionsUpdate.fromOptions(
    TransmissionTaskOptions options,
  ) {
    return TransmissionTaskOptionsUpdate(
      bandwidthPriority: options.bandwidthPriority,
      honorsSessionLimits: options.honorsSessionLimits,
      downloadLimited: options.downloadLimited,
      downloadLimitKBps: options.downloadLimitKBps,
      uploadLimited: options.uploadLimited,
      uploadLimitKBps: options.uploadLimitKBps,
      seedRatioMode: options.seedRatioMode,
      seedRatioLimit: options.seedRatioLimit,
      idleLimitMode: options.idleLimitMode,
      idleLimitMinutes: options.idleLimitMinutes,
    );
  }
}
