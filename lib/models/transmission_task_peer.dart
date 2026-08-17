/// Transmission 任务 Peer（节点）模型。
///
/// 用于节点子页面，每个实例代表一个连接的 peer。
class TransmissionTaskPeer {
  const TransmissionTaskPeer({
    required this.address,
    required this.clientName,
    required this.port,
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.isDownloadingToUs,
    required this.isUploadingFromUs,
  });

  /// peer IP 地址。
  final String address;

  /// peer 客户端名称（如 "qBittorrent/4.3.8"）。
  final String clientName;

  /// peer 端口。
  final int port;

  /// peer 的下载进度（0.0–1.0）。
  final double progress;

  /// 从该 peer 的下载速度（bytes/s）。
  final int downloadSpeed;

  /// 向该 peer 的上传速度（bytes/s）。
  final int uploadSpeed;

  /// 该 peer 是否正在向我们发送数据。
  final bool isDownloadingToUs;

  /// 我们是否正在向该 peer 发送数据。
  final bool isUploadingFromUs;
}
