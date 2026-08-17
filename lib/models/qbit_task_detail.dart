/// qBit 任务详情信息主页读模型。
///
/// 由 adapter 合并 `/torrents/info`、`/properties`、`/trackers`、`/webseeds`
/// 得到，承载 qBit 信息主页的各分组字段及子页面入口摘要。弱文档化字段
/// （v1/v2 hash、时间戳）保持可空，仅在服务端返回时渲染。
class QBitTaskDetail {
  const QBitTaskDetail({
    required this.taskId,
    required this.downloaderId,
    required this.name,
    required this.progress,
    required this.queuePosition,
    required this.category,
    required this.tags,
    required this.savePath,
    required this.totalSize,
    required this.fileCount,
    required this.sourceCount,
    required this.peerCount,
    required this.httpSourceCount,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.state,
    required this.downloaded,
    required this.uploaded,
    required this.shareRatio,
    required this.eta,
    required this.dlSpeedAvg,
    required this.upSpeedAvg,
    required this.seeds,
    required this.leechs,
    required this.connections,
    required this.connectionsLimit,
    required this.dlLimit,
    required this.upLimit,
    required this.availability,
    required this.pieceSize,
    required this.pieceCount,
    required this.completedPieceCount,
    required this.createdAt,
    required this.addedAt,
    required this.completedAt,
    required this.lastSeen,
    required this.timeElapsed,
    required this.seedingTime,
    required this.createdBy,
    required this.comment,
    this.infoHashV1,
    this.infoHashV2,
  });

  final String taskId;
  final String downloaderId;
  final String name;
  final double progress;
  final int queuePosition;
  final String category;
  final List<String> tags;
  final String savePath;
  final int totalSize;
  final int fileCount;
  final int sourceCount;
  final int peerCount;
  final int httpSourceCount;
  final int downloadSpeed;
  final int uploadSpeed;
  final String state;
  final int downloaded;
  final int uploaded;
  final double shareRatio;
  final int eta;
  final int dlSpeedAvg;
  final int upSpeedAvg;
  final int seeds;
  final int leechs;
  final int connections;
  final int connectionsLimit;
  final int dlLimit;
  final int upLimit;
  final double availability;
  final int pieceSize;
  final int pieceCount;
  final int completedPieceCount;
  final DateTime? createdAt;
  final DateTime? addedAt;
  final DateTime? completedAt;
  final DateTime? lastSeen;
  final int timeElapsed;
  final int seedingTime;
  final String createdBy;
  final String comment;

  /// v1/v2 info hash，弱文档化字段，仅在服务端返回时渲染。
  final String? infoHashV1;
  final String? infoHashV2;

  /// 返回仅更新指定字段的新实例，未指定字段保持原值。
  QBitTaskDetail copyWith({
    double? progress,
    int? downloadSpeed,
    int? uploadSpeed,
    int? downloaded,
    int? uploaded,
    double? shareRatio,
    int? eta,
    int? timeElapsed,
  }) {
    return QBitTaskDetail(
      taskId: taskId,
      downloaderId: downloaderId,
      name: name,
      progress: progress ?? this.progress,
      queuePosition: queuePosition,
      category: category,
      tags: tags,
      savePath: savePath,
      totalSize: totalSize,
      fileCount: fileCount,
      sourceCount: sourceCount,
      peerCount: peerCount,
      httpSourceCount: httpSourceCount,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      state: state,
      downloaded: downloaded ?? this.downloaded,
      uploaded: uploaded ?? this.uploaded,
      shareRatio: shareRatio ?? this.shareRatio,
      eta: eta ?? this.eta,
      dlSpeedAvg: dlSpeedAvg,
      upSpeedAvg: upSpeedAvg,
      seeds: seeds,
      leechs: leechs,
      connections: connections,
      connectionsLimit: connectionsLimit,
      dlLimit: dlLimit,
      upLimit: upLimit,
      availability: availability,
      pieceSize: pieceSize,
      pieceCount: pieceCount,
      completedPieceCount: completedPieceCount,
      createdAt: createdAt,
      addedAt: addedAt,
      completedAt: completedAt,
      lastSeen: lastSeen,
      timeElapsed: timeElapsed ?? this.timeElapsed,
      seedingTime: seedingTime,
      createdBy: createdBy,
      comment: comment,
      infoHashV1: infoHashV1,
      infoHashV2: infoHashV2,
    );
  }

  /// 从 `/sync/maindata` 的单个 torrent 增量 Map 合并到当前实例。
  ///
  /// sync 接口仅返回变化的动态字段（速度/进度/流量/活动时间），
  /// 静态字段（名称/分类/标签/分片等）保持不变。
  QBitTaskDetail applySyncUpdate(Map<String, dynamic> sync) {
    return copyWith(
      progress: (sync['progress'] as num?)?.toDouble(),
      downloadSpeed: (sync['dlspeed'] as num?)?.toInt(),
      uploadSpeed: (sync['upspeed'] as num?)?.toInt(),
      downloaded: (sync['downloaded'] as num?)?.toInt(),
      uploaded: (sync['uploaded'] as num?)?.toInt(),
      shareRatio: (sync['ratio'] as num?)?.toDouble(),
      eta: (sync['eta'] as num?)?.toInt(),
      timeElapsed: (sync['time_active'] as num?)?.toInt(),
    );
  }
}
