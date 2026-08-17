import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/transmission_task_detail.dart';

/// Transmission 单任务实时态。
///
/// 字段解析兼容 modern（snake_case）与 legacy（camelCase）两种 RPC 返回。
/// 因全局轮询服务端只下发 `torrent-get` 全量字段，这里只承载主页/列表/详情
/// 摘要所需的动态字段；文件树、peers 明细继续走各自的子页加载。
class TransmissionRealtimeTorrent {
  const TransmissionRealtimeTorrent({
    required this.id,
    required this.name,
    required this.statusCode,
    required this.percentDone,
    required this.totalSize,
    required this.leftUntilDone,
    required this.rateDownload,
    required this.rateUpload,
    required this.downloadDir,
    required this.peersSendingToUs,
    required this.peersGettingFromUs,
    required this.trackerStats,
    required this.uploadRatio,
    required this.downloadedEver,
    required this.uploadedEver,
    required this.addedDate,
    required this.doneDate,
    required this.activityDate,
    required this.secondsDownloading,
    required this.secondsSeeding,
    required this.pieceCount,
    required this.labels,
    required this.error,
    required this.errorString,
  });

  final String id;
  final String name;
  final int statusCode;
  final double percentDone;
  final int totalSize;
  final int leftUntilDone;
  final int rateDownload;
  final int rateUpload;
  final String downloadDir;
  final int peersSendingToUs;
  final int peersGettingFromUs;
  final List<Map<String, dynamic>> trackerStats;
  final double uploadRatio;
  final int downloadedEver;
  final int uploadedEver;
  final int? addedDate;
  final int? doneDate;
  final int? activityDate;
  final int secondsDownloading;
  final int secondsSeeding;
  final int pieceCount;
  final List<String> labels;
  final int error;
  final String errorString;

  factory TransmissionRealtimeTorrent.fromRpc(Map<String, dynamic> json) {
    return TransmissionRealtimeTorrent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      statusCode: _asInt(json['status']),
      percentDone: _asDouble(json['percentDone'] ?? json['percent_done']),
      totalSize: _asInt(json['totalSize'] ?? json['total_size']),
      leftUntilDone: _asInt(json['leftUntilDone'] ?? json['left_until_done']),
      rateDownload: _asInt(json['rateDownload'] ?? json['rate_download']),
      rateUpload: _asInt(json['rateUpload'] ?? json['rate_upload']),
      downloadDir: (json['downloadDir'] ?? json['download_dir'] ?? '').toString(),
      peersSendingToUs:
          _asInt(json['peersSendingToUs'] ?? json['peers_sending_to_us']),
      peersGettingFromUs:
          _asInt(json['peersGettingFromUs'] ?? json['peers_getting_from_us']),
      trackerStats: _asTrackerStats(json['trackerStats'] ?? json['trackers']),
      uploadRatio:
          _asDouble(json['uploadRatio'] ?? json['upload_ratio']),
      downloadedEver:
          _asInt(json['downloadedEver'] ?? json['downloaded_ever']),
      uploadedEver: _asInt(json['uploadedEver'] ?? json['uploaded_ever']),
      addedDate: _asNullableInt(json['addedDate'] ?? json['added_date']),
      doneDate: _asNullableInt(json['doneDate'] ?? json['done_date']),
      activityDate:
          _asNullableInt(json['activityDate'] ?? json['activity_date']),
      secondsDownloading:
          _asInt(json['secondsDownloading'] ?? json['seconds_downloading']),
      secondsSeeding:
          _asInt(json['secondsSeeding'] ?? json['seconds_seeding']),
      pieceCount: _asInt(json['pieceCount'] ?? json['piece_count']),
      labels: _asLabels(json['labels']),
      error: _asInt(json['error']),
      errorString: (json['errorString'] ?? json['error_string'] ?? '').toString(),
    );
  }

  DownloadTask toDownloadTask(String downloaderId) {
    return DownloadTask(
      id: id,
      gid: id,
      name: name,
      totalSize: totalSize,
      downloaded: totalSize - leftUntilDone,
      progress: percentDone,
      downloadSpeed: rateDownload,
      uploadSpeed: rateUpload,
      status: transmissionStatusToTaskStatus(statusCode),
      savePath: downloadDir,
      downloaderId: downloaderId,
      seeders: peersSendingToUs,
      peers: peersGettingFromUs,
      tracker: _firstTrackerAnnounce(trackerStats),
    );
  }

  /// 转为详情摘要（覆盖 Transmission 详情主页所需动态字段）。
  TransmissionTaskDetail toDetail(String downloaderId) {
    final availablePercent =
        totalSize > 0 ? (totalSize - leftUntilDone) / totalSize : 0.0;

    return TransmissionTaskDetail(
      taskId: id,
      name: name,
      downloaderId: downloaderId,
      totalSize: totalSize,
      pieceCount: pieceCount,
      pieceSize: totalSize > 0 && pieceCount > 0 ? totalSize ~/ pieceCount : 0,
      savePath: downloadDir,
      isPrivate: false,
      creator: null,
      createdAt: null,
      magnet: null,
      availablePercent: availablePercent,
      downloadedEver: downloadedEver > 0 ? downloadedEver : totalSize - leftUntilDone,
      uploadedEver: uploadedEver,
      ratio: uploadRatio,
      averageSpeed: rateDownload,
      addedAt: _toDate(addedDate),
      completedAt: _toDate(doneDate),
      lastActivityAt: _toDate(activityDate),
      downloadDuration: Duration(seconds: secondsDownloading),
      seedingDuration: Duration(seconds: secondsSeeding),
      fileCount: 0,
      trackerCount: trackerStats.length,
      peerCount: peersSendingToUs + peersGettingFromUs,
      optionsEditable: true,
    );
  }
}

/// Transmission 全量轮询读模型。
class TransmissionRealtimeSnapshot {
  const TransmissionRealtimeSnapshot({
    required this.downloaderId,
    required this.torrents,
  });

  final String downloaderId;
  final Map<String, TransmissionRealtimeTorrent> torrents;

  factory TransmissionRealtimeSnapshot.fromRpc({
    required String downloaderId,
    required List<Map<String, dynamic>> torrents,
  }) {
    final map = <String, TransmissionRealtimeTorrent>{};
    for (final json in torrents) {
      final torrent = TransmissionRealtimeTorrent.fromRpc(json);
      if (torrent.id.isNotEmpty) {
        map[torrent.id] = torrent;
      }
    }
    return TransmissionRealtimeSnapshot(
      downloaderId: downloaderId,
      torrents: map,
    );
  }

  List<DownloadTask> get tasks =>
      torrents.values.map((t) => t.toDownloadTask(downloaderId)).toList();

  int get totalDownloadSpeed =>
      torrents.values.fold(0, (sum, t) => sum + t.rateDownload);

  int get totalUploadSpeed =>
      torrents.values.fold(0, (sum, t) => sum + t.rateUpload);
}

/// Transmission `status` 数值 → [TaskStatus]。
///
/// 与 modern / legacy adapter 的状态机保持一致，覆盖 0/1-3/4/5-6。
TaskStatus transmissionStatusToTaskStatus(int? status) {
  switch (status) {
    case 0:
      return TaskStatus.paused;
    case 1:
    case 2:
    case 3:
      return TaskStatus.waiting;
    case 4:
      return TaskStatus.downloading;
    case 5:
    case 6:
      return TaskStatus.seeding;
    default:
      return TaskStatus.unknown;
  }
}

// ─── 解析辅助 ──────────────────────────────────────────────────

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

List<Map<String, dynamic>> _asTrackerStats(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}

List<String> _asLabels(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).toList(growable: false);
}

String? _firstTrackerAnnounce(List<Map<String, dynamic>> trackerStats) {
  for (final tracker in trackerStats) {
    final announce = tracker['announce']?.toString() ?? '';
    if (announce.isNotEmpty) return announce;
  }
  return null;
}

DateTime? _toDate(int? epochSeconds) {
  if (epochSeconds == null || epochSeconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
}
