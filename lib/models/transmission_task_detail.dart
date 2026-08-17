/// Transmission 任务完整详情模型。
///
/// 仅用于 Transmission 详情页（信息主页 + 子页面入口摘要），
/// 由各 adapter 的 `getTaskFullDetail` 从 RPC 全字段响应解析得到。
class TransmissionTaskDetail {
  const TransmissionTaskDetail({
    required this.taskId,
    required this.name,
    required this.downloaderId,
    required this.totalSize,
    required this.pieceCount,
    required this.pieceSize,
    required this.savePath,
    required this.isPrivate,
    required this.creator,
    required this.createdAt,
    required this.magnet,
    required this.availablePercent,
    required this.downloadedEver,
    required this.uploadedEver,
    required this.ratio,
    required this.averageSpeed,
    required this.addedAt,
    required this.completedAt,
    required this.lastActivityAt,
    required this.downloadDuration,
    required this.seedingDuration,
    required this.fileCount,
    required this.trackerCount,
    required this.peerCount,
    required this.optionsEditable,
  });

  final String taskId;
  final String name;
  final String downloaderId;
  final int totalSize;
  final int pieceCount;
  final int pieceSize;
  final String savePath;
  final bool isPrivate;
  final String? creator;
  final DateTime? createdAt;
  final String? magnet;
  final double availablePercent;
  final int downloadedEver;
  final int uploadedEver;
  final double ratio;
  final int averageSpeed;
  final DateTime? addedAt;
  final DateTime? completedAt;
  final DateTime? lastActivityAt;
  final Duration downloadDuration;
  final Duration seedingDuration;
  final int fileCount;
  final int trackerCount;
  final int peerCount;
  final bool optionsEditable;
}
