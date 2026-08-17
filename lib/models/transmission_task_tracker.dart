/// Transmission 任务 Tracker 模型。
///
/// 用于服务器（Tracker）子页面，每个实例代表一个 tracker announce URL。
class TransmissionTaskTracker {
  const TransmissionTaskTracker({
    required this.id,
    required this.host,
    required this.announce,
    required this.tier,
    this.lastAnnounceAt,
    this.nextAnnounceAt,
    this.lastScrapeAt,
    this.seederCount = 0,
    this.leecherCount = 0,
    this.downloadCount = 0,
    this.status,
    this.errorMessage,
  });

  /// RPC 内部 tracker ID。
  final int id;

  /// tracker 主机名（含端口）。
  final String host;

  /// 完整的 announce URL。
  final String announce;

  /// 优先级层级（数字越小越优先）。
  final int tier;

  /// 最后一次 announce 时间。
  final DateTime? lastAnnounceAt;

  /// 下一次 announce 时间。
  final DateTime? nextAnnounceAt;

  /// 最后一次 scrape 时间。
  final DateTime? lastScrapeAt;

  /// 当前做种者数量。
  final int seederCount;

  /// 当前下载者数量。
  final int leecherCount;

  /// 累计下载次数。
  final int downloadCount;

  /// tracker 状态描述。
  final String? status;

  /// 最后一次错误信息。
  final String? errorMessage;
}
