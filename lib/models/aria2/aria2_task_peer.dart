/// Aria2 节点（Peer）模型。
///
/// 对应 `aria2.getPeers` 返回的单个节点信息。
class Aria2TaskPeer {
  const Aria2TaskPeer({
    required this.peerId,
    required this.ip,
    required this.port,
    required this.amChoking,
    required this.peerChoking,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.seeder,
  });

  final String peerId;
  final String ip;
  final int port;
  final bool amChoking;
  final bool peerChoking;
  final int downloadSpeed;
  final int uploadSpeed;
  final bool seeder;

  String get address => '$ip:$port';

  factory Aria2TaskPeer.fromJson(Map<String, dynamic> json) {
    return Aria2TaskPeer(
      peerId: json['peerId']?.toString() ?? '',
      ip: json['ip']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '0') ?? 0,
      amChoking: json['amChoking']?.toString() == 'true',
      peerChoking: json['peerChoking']?.toString() == 'true',
      downloadSpeed:
          int.tryParse(json['downloadSpeed']?.toString() ?? '0') ?? 0,
      uploadSpeed: int.tryParse(json['uploadSpeed']?.toString() ?? '0') ?? 0,
      seeder: json['seeder']?.toString() == 'true',
    );
  }
}
