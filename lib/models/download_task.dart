import '../core/constants/app_constants.dart';

/// 下载任务模型
class DownloadTask {
  final String id;
  final String gid; // 下载器内部 ID
  final String name;
  final int totalSize;
  final int downloaded;
  final double progress;
  final int downloadSpeed;
  final int uploadSpeed;
  final TaskStatus status;
  final String savePath;
  final String downloaderId;
  final DateTime? addedAt;
  final DateTime? doneAt;
  final int? seeders;
  final int? peers;
  final int? connections; // 连接数
  final String? tracker; // 主 Tracker URL
  final int? fileCount; // 任务包含的文件数（目录型任务常用）
  final double? healthPercent; // 健康度（0..1，Aria2 从 bitfield/numPieces 计算）

  DownloadTask({
    required this.id,
    required this.gid,
    required this.name,
    this.totalSize = 0,
    this.downloaded = 0,
    this.progress = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.status = TaskStatus.unknown,
    this.savePath = '',
    required this.downloaderId,
    this.addedAt,
    this.doneAt,
    this.seeders,
    this.peers,
    this.connections,
    this.tracker,
    this.fileCount,
    this.healthPercent,
  });

  /// 格式化文件大小
  String get formattedSize => _formatSize(totalSize);
  String get formattedDownloaded => _formatSize(downloaded);
  String get formattedSpeed => '${_formatSize(downloadSpeed)}/s';
  String get formattedUploadSpeed => '${_formatSize(uploadSpeed)}/s';

  /// 剩余时间估算
  String? get eta {
    if (downloadSpeed <= 0 || status != TaskStatus.downloading) return null;
    final remaining = totalSize - downloaded;
    final seconds = remaining ~/ downloadSpeed;
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分钟';
    return '${seconds ~/ 3600}小时${(seconds % 3600) ~/ 60}分钟';
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] ?? '',
      gid: json['gid'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      totalSize: json['totalSize'] ?? json['size'] ?? 0,
      downloaded: json['downloaded'] ?? json['completedLength'] ?? 0,
      progress: json['progress'] ?? 0.0,
      downloadSpeed: json['downloadSpeed'] ?? json['dlspeed'] ?? 0,
      uploadSpeed: json['uploadSpeed'] ?? json['upspeed'] ?? 0,
      status: _parseStatus(json['status']),
      savePath: json['savePath'] ?? json['dir'] ?? '',
      downloaderId: json['downloaderId'],
      addedAt: json['addedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['addedAt'] * 1000)
          : null,
      doneAt: json['doneAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['doneAt'] * 1000)
          : null,
      seeders: json['num_seeds'] ?? json['seeders'],
      peers: json['num_leechs'] ?? json['peers'],
      connections: json['connections'],
      tracker: json['tracker'],
      fileCount: json['fileCount'],
    );
  }

  static TaskStatus _parseStatus(dynamic status) {
    if (status == null) return TaskStatus.unknown;
    final s = status.toString().toLowerCase();
    if (s.contains('downloading') || s == 'active') {
      return TaskStatus.downloading;
    }
    if (s.contains('waiting') || s == 'waiting') return TaskStatus.waiting;
    if (s.contains('paused') || s == 'paused') return TaskStatus.paused;
    if (s.contains('complete') || s == 'complete' || s == 'done') {
      return TaskStatus.completed;
    }
    if (s.contains('removed') || s == 'removed') return TaskStatus.removed;
    if (s.contains('error')) return TaskStatus.error;
    return TaskStatus.unknown;
  }

  DownloadTask copyWith({
    String? id,
    String? gid,
    String? name,
    int? totalSize,
    int? downloaded,
    double? progress,
    int? downloadSpeed,
    int? uploadSpeed,
    TaskStatus? status,
    String? savePath,
    String? downloaderId,
    DateTime? addedAt,
    DateTime? doneAt,
    int? seeders,
    int? peers,
    int? connections,
    String? tracker,
    int? fileCount,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      gid: gid ?? this.gid,
      name: name ?? this.name,
      totalSize: totalSize ?? this.totalSize,
      downloaded: downloaded ?? this.downloaded,
      progress: progress ?? this.progress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      status: status ?? this.status,
      savePath: savePath ?? this.savePath,
      downloaderId: downloaderId ?? this.downloaderId,
      addedAt: addedAt ?? this.addedAt,
      doneAt: doneAt ?? this.doneAt,
      seeders: seeders ?? this.seeders,
      peers: peers ?? this.peers,
      connections: connections ?? this.connections,
      tracker: tracker ?? this.tracker,
      fileCount: fileCount ?? this.fileCount,
    );
  }
}
