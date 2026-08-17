/// qBit 节点页的来源统计卡片模型。
///
/// 对应 DHT / PeX / LSD 等伪 tracker（qBit 在 `/trackers` 端点用 `** [DHT] **`
/// 形式返回）。聚合 peers / seeds / downloads 计数用于来源状态展示。
class QBitTaskSource {
  const QBitTaskSource({
    required this.name,
    required this.status,
    required this.peerCount,
    required this.seedCount,
    required this.downloadCount,
    required this.downloadedCount,
  });

  final String name;
  final String status;
  final int peerCount;
  final int seedCount;
  final int downloadCount;
  final int downloadedCount;

  String get statusLabel => status;
}
