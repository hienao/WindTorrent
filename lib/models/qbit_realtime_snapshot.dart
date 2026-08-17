import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/download_task.dart';

/// qBittorrent `sync/maindata` 服务器全局态。
///
/// 仅承载主页/列表所需的速度与连接汇总；分类统计由 [QBitRealtimeSnapshot]
/// 聚合 torrents 得到。
class QBitRealtimeServerState {
  const QBitRealtimeServerState({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.totalPeerConnections,
  });

  final int downloadSpeed;
  final int uploadSpeed;
  final int totalPeerConnections;

  /// qBit `server_state` 在增量响应里以完整对象下发（不变时缺省），
  /// 故增量出现时整体替换。
  factory QBitRealtimeServerState.fromJson(Map<String, dynamic> json) {
    return QBitRealtimeServerState(
      downloadSpeed: (json['dl_info_speed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (json['up_info_speed'] as num?)?.toInt() ?? 0,
      totalPeerConnections:
          (json['total_peer_connections'] as num?)?.toInt() ?? 0,
    );
  }

  static const QBitRealtimeServerState empty = QBitRealtimeServerState(
    downloadSpeed: 0,
    uploadSpeed: 0,
    totalPeerConnections: 0,
  );
}

/// qBittorrent `sync/maindata` 单任务实时态。
///
/// 字段语义对齐 qBit `/torrents/info`，便于与 [DownloadTask] 互转。
/// 增量响应只包含变化字段，缺失项由 [merge] 保留旧值。
class QBitRealtimeTorrent {
  const QBitRealtimeTorrent({
    required this.hash,
    required this.name,
    required this.state,
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.totalSize,
    required this.downloaded,
    required this.uploaded,
    required this.savePath,
  });

  final String hash;
  final String name;
  final String state;
  final double progress;
  final int downloadSpeed;
  final int uploadSpeed;
  final int totalSize;
  final int downloaded;
  final int uploaded;
  final String savePath;

  factory QBitRealtimeTorrent.fromJson(String hash, Map<String, dynamic> json) {
    return QBitRealtimeTorrent(
      hash: hash,
      name: json['name']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      downloadSpeed: (json['dlspeed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (json['upspeed'] as num?)?.toInt() ?? 0,
      totalSize: (json['total_size'] as num?)?.toInt() ?? 0,
      downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
      uploaded: (json['uploaded'] as num?)?.toInt() ?? 0,
      savePath: json['save_path']?.toString() ?? '',
    );
  }

  /// 用增量字段合并，未出现的字段保留旧值。
  QBitRealtimeTorrent merge(Map<String, dynamic> json) {
    return QBitRealtimeTorrent(
      hash: hash,
      name: json.containsKey('name') ? json['name']?.toString() ?? name : name,
      state: json.containsKey('state')
          ? json['state']?.toString() ?? state
          : state,
      progress: json.containsKey('progress')
          ? (json['progress'] as num?)?.toDouble() ?? progress
          : progress,
      downloadSpeed: json.containsKey('dlspeed')
          ? (json['dlspeed'] as num?)?.toInt() ?? downloadSpeed
          : downloadSpeed,
      uploadSpeed: json.containsKey('upspeed')
          ? (json['upspeed'] as num?)?.toInt() ?? uploadSpeed
          : uploadSpeed,
      totalSize: json.containsKey('total_size')
          ? (json['total_size'] as num?)?.toInt() ?? totalSize
          : totalSize,
      downloaded: json.containsKey('downloaded')
          ? (json['downloaded'] as num?)?.toInt() ?? downloaded
          : downloaded,
      uploaded: json.containsKey('uploaded')
          ? (json['uploaded'] as num?)?.toInt() ?? uploaded
          : uploaded,
      savePath: json.containsKey('save_path')
          ? json['save_path']?.toString() ?? savePath
          : savePath,
    );
  }

  DownloadTask toDownloadTask(String downloaderId) {
    return DownloadTask(
      id: hash,
      gid: hash,
      name: name,
      totalSize: totalSize,
      downloaded: downloaded,
      progress: progress,
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      status: qBitStateToTaskStatus(state),
      savePath: savePath,
      downloaderId: downloaderId,
    );
  }
}

/// qBit `sync/maindata` 读模型，支持首次全量与后续增量合并。
///
/// 增量语义：
/// - `rid`：始终取新值。
/// - `server_state`：出现即整体替换（qBit 下发完整对象）。
/// - `torrents`：逐 key 合并；value 为 null 表示删除。
/// - `torrents_removed`：列表中的 hash 直接删除。
/// - `categories` / `categories_removed`：分类增删。
/// - `tags` / `tags_removed`：标签整体替换 / 列表删除。
class QBitRealtimeSnapshot {
  const QBitRealtimeSnapshot({
    required this.downloaderId,
    required this.rid,
    required this.serverState,
    required this.categories,
    required this.tags,
    required this.torrents,
  });

  final String downloaderId;
  final int rid;
  final QBitRealtimeServerState serverState;
  final Map<String, String> categories;
  final List<String> tags;
  final Map<String, QBitRealtimeTorrent> torrents;

  factory QBitRealtimeSnapshot.fromJson({
    required String downloaderId,
    required Map<String, dynamic> json,
  }) {
    final torrentsRaw = _asMap(json['torrents']);
    final torrents = <String, QBitRealtimeTorrent>{};
    torrentsRaw.forEach((hash, raw) {
      if (raw is Map) {
        torrents[hash] =
            QBitRealtimeTorrent.fromJson(hash, Map<String, dynamic>.from(raw));
      }
    });

    final categoriesRaw = _asMap(json['categories']);
    final categories = <String, String>{};
    categoriesRaw.forEach((key, value) {
      if (value is Map) {
        categories[key] = value['name']?.toString() ?? key;
      }
    });

    final tagsRaw = json['tags'] as List<dynamic>? ?? const [];
    final tags = tagsRaw.map((t) => t.toString()).toList();

    final serverStateJson = _asMap(json['server_state']);
    final rid = (json['rid'] as num?)?.toInt() ?? 0;

    return QBitRealtimeSnapshot(
      downloaderId: downloaderId,
      rid: rid,
      serverState: serverStateJson.isEmpty
          ? QBitRealtimeServerState.empty
          : QBitRealtimeServerState.fromJson(serverStateJson),
      categories: categories,
      tags: tags,
      torrents: torrents,
    );
  }

  /// 用增量响应合并出新的快照（不可变）。
  QBitRealtimeSnapshot mergeJson(Map<String, dynamic> json) {
    final newRid = (json['rid'] as num?)?.toInt() ?? rid;

    final serverState = json.containsKey('server_state')
        ? QBitRealtimeServerState.fromJson(_asMap(json['server_state']))
        : this.serverState;

    // torrents 增量合并
    final torrents = Map<String, QBitRealtimeTorrent>.from(this.torrents);
    final torrentsDelta = _asMap(json['torrents']);
    torrentsDelta.forEach((hash, raw) {
      if (raw == null) {
        torrents.remove(hash);
      } else if (raw is Map) {
        final existing = torrents[hash];
        torrents[hash] = existing == null
            ? QBitRealtimeTorrent.fromJson(hash, Map<String, dynamic>.from(raw))
            : existing.merge(Map<String, dynamic>.from(raw));
      }
    });
    final torrentsRemoved =
        json['torrents_removed'] as List<dynamic>? ?? const [];
    for (final hash in torrentsRemoved) {
      torrents.remove(hash.toString());
    }

    // categories 增量合并
    final categories = Map<String, String>.from(this.categories);
    final categoriesDelta = _asMap(json['categories']);
    categoriesDelta.forEach((key, value) {
      if (value == null) {
        categories.remove(key);
      } else if (value is Map) {
        categories[key] = value['name']?.toString() ?? key;
      }
    });
    final categoriesRemoved =
        json['categories_removed'] as List<dynamic>? ?? const [];
    for (final key in categoriesRemoved) {
      categories.remove(key.toString());
    }

    // tags 增量合并
    var tags = this.tags;
    if (json.containsKey('tags')) {
      final tagsRaw = json['tags'] as List<dynamic>? ?? const [];
      tags = tagsRaw.map((t) => t.toString()).toList();
    }
    final tagsRemoved = json['tags_removed'] as List<dynamic>? ?? const [];
    if (tagsRemoved.isNotEmpty) {
      final removed = tagsRemoved.map((t) => t.toString()).toSet();
      tags = tags.where((t) => !removed.contains(t)).toList();
    }

    return QBitRealtimeSnapshot(
      downloaderId: downloaderId,
      rid: newRid,
      serverState: serverState,
      categories: categories,
      tags: tags,
      torrents: torrents,
    );
  }

  List<DownloadTask> get tasks =>
      torrents.values.map((t) => t.toDownloadTask(downloaderId)).toList();
}

/// qBit `state` 字符串 → [TaskStatus]。
///
/// 与 [QBitBaseApiAdapter] 的状态机保持一致，覆盖 stalled / stopped / queued
/// 等 qBit 私有状态，避免做种/等待中的 stalled 任务被误判为 unknown。
TaskStatus qBitStateToTaskStatus(String state) {
  switch (state) {
    case 'downloading':
    case 'stalledDL':
    case 'forcedDL':
    case 'metaDL':
      return TaskStatus.downloading;
    case 'stoppedDL':
    case 'stoppedUP':
    case 'pausedDL':
    case 'pausedUP':
      return TaskStatus.paused;
    case 'queuedDL':
    case 'queuedUP':
      return TaskStatus.waiting;
    case 'uploading':
    case 'stalledUP':
    case 'forcedUP':
      return TaskStatus.seeding;
    case 'error':
    case 'missingFiles':
      return TaskStatus.error;
    case 'checkingDL':
    case 'checkingUP':
    case 'checkingResumeData':
    case 'moving':
    case 'allocating':
      return TaskStatus.waiting;
    default:
      return TaskStatus.unknown;
  }
}

/// 将 JSON 字面量 / RPC 解析后的动态 Map 规范化为 `Map<String, dynamic>`。
///
/// JSON 字面量（测试）与 Dart 内联 Map 在运行时是 `_Map<dynamic, dynamic>`，
/// 直接 `as Map<String, dynamic>` 会抛 type cast 异常，统一走 `Map.from`。
Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
