import 'package:windwalker/models/qbit_task_file_node.dart' show formatQBitBytes;

/// qBit 节点页的密集对端行模型。
///
/// 由 `/sync/torrentPeers` 响应解析得到。本地 4.1/5.0 文档未定义该响应体，
/// 故仅依赖已确认字段：`connection`、`flags`、`ip`、`port`、`progress`、
/// `relevance`、`dl_speed`、`up_speed`、`downloaded`、`uploaded`。当嵌套 `ip`/`port`
/// 缺失时由 peer-map key（`ip:port`）兜底推导。
class QBitTaskPeer {
  const QBitTaskPeer({
    required this.address,
    required this.port,
    required this.protocol,
    required this.stateTags,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.downloaded,
    required this.uploaded,
    required this.progress,
    required this.relevance,
  });

  final String address;
  final int port;
  final String protocol;
  final List<String> stateTags;
  final int downloadSpeed;
  final int uploadSpeed;
  final int downloaded;
  final int uploaded;
  final double progress;
  final double relevance;

  String get formattedDownloadSpeed => '${formatQBitBytes(downloadSpeed)}/s';
  String get formattedUploadSpeed => '${formatQBitBytes(uploadSpeed)}/s';
  String get formattedDownloaded => formatQBitBytes(downloaded);
  String get formattedUploaded => formatQBitBytes(uploaded);
  String get progressLabel => '${(progress * 100).toStringAsFixed(0)}%';
  String get relevancePercent => '${(relevance * 100).toStringAsFixed(2)}%';
}
