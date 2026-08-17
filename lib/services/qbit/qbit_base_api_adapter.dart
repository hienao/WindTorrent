import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';
import 'package:windwalker/models/qbit_task_detail.dart';
import 'package:windwalker/models/qbit_task_file_node.dart';
import 'package:windwalker/models/qbit_task_options.dart';
import 'package:windwalker/models/qbit_task_options_update.dart';
import 'package:windwalker/models/qbit_task_peer.dart';
import 'package:windwalker/models/qbit_task_source.dart';
import 'package:windwalker/services/qbit/qbit_api_adapter.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';

/// 各版本 adapter 的共享基类。
///
/// 承载 4.x 与 5.x 共有的端点逻辑；版本差异（pause/resume 端点）由子类
/// [QBitV4Adapter] / [QBitV5Adapter] override。任务解析、限速、增删查等
/// 共有操作在此统一实现。
abstract class QBitBaseApiAdapter implements QBitApiAdapter {
  final QBitSession session;

  QBitBaseApiAdapter(this.session);

  /// 发送 hashes 类型的任务动作（pause/resume/stop/start/delete 等）。
  /// 非 200 抛 protocol 异常。
  Future<void> postTaskAction(String path, String taskId) async {
    final response = await session.postForm(path, {'hashes': taskId});
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent task action 失败: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
  }

  @override
  Future<List<DownloadTask>> getTasks() async {
    final body = await session.getText('/api/v2/torrents/info');
    final List<dynamic> data = jsonDecode(body);
    return data.map((json) => _parseTask(json)).toList();
  }

  @override
  Future<Map<String, dynamic>> getGlobalStat() async {
    final infoBody = await session.getText('/api/v2/transfer/info');
    final data = jsonDecode(infoBody) ?? {};

    // /api/v2/transfer/info 不返回 torrentCount，需单独获取
    int torrentCount = 0;
    try {
      final torrentsBody = await session.getText('/api/v2/torrents/info');
      torrentCount = (jsonDecode(torrentsBody) as List).length;
    } catch (e) {
      // 获取任务数（次要统计字段）失败时降级为 0，不影响主统计
      Log.w('QBitBaseApiAdapter.getGlobalStat: torrentCount 获取失败: $e');
    }

    return {
      'downloadSpeed': data['dl_info_speed'] ?? 0,
      'uploadSpeed': data['up_info_speed'] ?? 0,
      'torrentCount': torrentCount,
    };
  }

  @override
  Future<QBitRealtimeSnapshot> getRealtimeSnapshot({required int rid}) async {
    final body = await session.getText('/api/v2/sync/maindata?rid=$rid');
    return QBitRealtimeSnapshot.fromJson(
      downloaderId: session.downloader.id,
      json: jsonDecode(body) as Map<String, dynamic>,
    );
  }

  @override
  Future<Map<String, dynamic>> getRealtimeMainData({required int rid}) async {
    final body = await session.getText('/api/v2/sync/maindata?rid=$rid');
    return jsonDecode(body) as Map<String, dynamic>;
  }

  @override
  Future<String> addTask(AddTaskRequest request) async {
    if (request.hasUrlSource) {
      return addDownload(request.url!, savePath: request.savePath);
    }

    final multipartRequest = http.MultipartRequest(
      'POST',
      Uri.parse('${session.baseUrl}/api/v2/torrents/add'),
    )..files.add(
        http.MultipartFile.fromBytes(
          'torrents',
          request.torrentFileBytes!,
          filename: request.torrentFileName!,
        ),
      );

    if (request.savePath != null && request.savePath!.isNotEmpty) {
      multipartRequest.fields['savepath'] = request.savePath!;
    }

    final response = await session.sendMultipart(multipartRequest);
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent addTask: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    return 'ok';
  }

  @override
  Future<String> addDownload(String url, {String? savePath}) async {
    final response = await session.postForm(
      '/api/v2/torrents/add',
      {'urls': url, 'savepath': ?savePath},
    );
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent addDownload: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    return 'ok';
  }

  @override
  Future<String> getDefaultSavePath() async {
    final body = await session.getText('/api/v2/app/defaultSavePath');
    return body.trim();
  }

  @override
  Future<void> removeTask(String taskId, {bool deleteFiles = false}) async {
    final response = await session.postForm(
      '/api/v2/torrents/delete',
      {'hashes': taskId, 'deleteFiles': deleteFiles.toString()},
    );
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent removeTask 失败: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
  }

  @override
  Future<DownloaderSpeedConfig> getSpeedConfig() async {
    final modeBody = await session.getText('/api/v2/transfer/speedLimitsMode');
    final prefsBody = await session.getText('/api/v2/app/preferences');
    final prefs = jsonDecode(prefsBody) as Map<String, dynamic>;
    return DownloaderSpeedConfig(
      speedLimitModeEnabled: modeBody.trim() == '1',
      downloadLimitKB: prefs['dl_limit'] as int? ?? 0,
      uploadLimitKB: prefs['up_limit'] as int? ?? 0,
      altDownloadLimitKB: prefs['alt_dl_limit'] as int? ?? 0,
      altUploadLimitKB: prefs['alt_up_limit'] as int? ?? 0,
    );
  }

  @override
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config) async {
    final response = await session.postForm(
      '/api/v2/app/setPreferences',
      {
        'json': jsonEncode({
          'dl_limit': config.downloadLimitKB,
          'up_limit': config.uploadLimitKB,
          'alt_dl_limit': config.altDownloadLimitKB,
          'alt_up_limit': config.altUploadLimitKB,
        })
      },
    );
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent setSpeedConfig: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }

    // 切换速度限制模式 (alternative speed limits mode)
    final modeBody = await session.getText('/api/v2/transfer/speedLimitsMode');
    final currentIsAlt = modeBody.trim() == '1';
    if (currentIsAlt != config.speedLimitModeEnabled) {
      await session.postForm('/api/v2/transfer/toggleSpeedLimitsMode', {});
    }

    return true;
  }

  @override
  Future<DownloadTask?> getTaskDetail(String taskId) async {
    DownloadTask? task;

    // 先按 hash 精确查询（探测性，失败则回退全量）
    try {
      final body =
          await session.getText('/api/v2/torrents/info?hashes=$taskId');
      final List<dynamic> data = jsonDecode(body);
      if (data.isNotEmpty) {
        task = _parseTask(data.first as Map<String, dynamic>);
      }
    } catch (e) {
      Log.w('QBitBaseApiAdapter.getTaskDetail: hash 查询失败: $e');
    }

    // Fallback: 全量列表过滤
    if (task == null) {
      final body = await session.getText('/api/v2/torrents/info');
      final List<dynamic> allData = jsonDecode(body);
      for (final torrent in allData) {
        if (torrent['hash'] == taskId) {
          task = _parseTask(torrent as Map<String, dynamic>);
          break;
        }
      }
    }

    if (task == null) return null;

    // Fetch properties for connections count (not available in /torrents/info)
    int? connections;
    try {
      final propsBody =
          await session.getText('/api/v2/torrents/properties?hash=$taskId');
      final props = jsonDecode(propsBody);
      connections = props['nb_connections'] as int?;
    } catch (e) {
      // properties 为次要字段，失败降级不影响主任务返回
      Log.w('QBitBaseApiAdapter.getTaskDetail: properties fetch failed: $e');
    }

    // Fetch tracker info via separate API call
    String? trackerUrl;
    try {
      final trackersBody =
          await session.getText('/api/v2/torrents/trackers?hash=$taskId');
      final List<dynamic> trackers = jsonDecode(trackersBody);
      for (final t in trackers) {
        final tUrl = t['url']?.toString() ?? '';
        // Skip DHT/PeX/LPD pseudo-trackers
        if (tUrl.isNotEmpty &&
            !tUrl.startsWith('**') &&
            !tUrl.contains('dht:') &&
            !tUrl.contains('pex:') &&
            !tUrl.contains('lpd:')) {
          trackerUrl = tUrl;
          break;
        }
      }
    } catch (e) {
      // tracker 为次要字段，失败降级不影响主任务返回
      Log.w('QBitBaseApiAdapter.getTaskDetail: tracker fetch failed: $e');
    }

    return task.copyWith(connections: connections, tracker: trackerUrl);
  }

  @override
  Future<QBitTaskDetail?> getTaskFullDetail(String taskId) async {
    // /torrents/info?hashes= 精确查询
    final infoBody =
        await session.getText('/api/v2/torrents/info?hashes=$taskId');
    final List<dynamic> infoList = jsonDecode(infoBody);
    final match = _firstByHash(infoList, taskId);
    if (match == null) return null;

    final propsBody =
        await session.getText('/api/v2/torrents/properties?hash=$taskId');
    final props = jsonDecode(propsBody) as Map<String, dynamic>;

    final trackersBody =
        await session.getText('/api/v2/torrents/trackers?hash=$taskId');
    final List<dynamic> trackers = jsonDecode(trackersBody);

    final webSeedsBody =
        await session.getText('/api/v2/torrents/webseeds?hash=$taskId');
    final List<dynamic> webSeeds = jsonDecode(webSeedsBody);

    return _parseDetail(
      taskId: taskId,
      info: match,
      props: props,
      trackers: trackers.cast<Map<String, dynamic>>(),
      webSeeds: webSeeds.cast<Map<String, dynamic>>(),
    );
  }

  @override
  Future<(int rid, Map<String, dynamic>?)> getTaskSyncUpdate(
      String taskId, int rid) async {
    final body =
        await session.getText('/api/v2/sync/maindata?rid=$rid');
    final json = jsonDecode(body) as Map<String, dynamic>;
    final newRid = (json['rid'] as num?)?.toInt() ?? rid;
    final torrents =
        json['torrents'] as Map<String, dynamic>? ?? const {};
    final torrentData = torrents[taskId] as Map<String, dynamic>?;
    return (newRid, torrentData);
  }

  @override
  Future<List<QBitTaskFileNode>> getTaskFiles(String taskId) async {
    final body = await session.getText('/api/v2/torrents/files?hash=$taskId');
    final List<dynamic> raw = jsonDecode(body);
    return _buildFileTree(raw.cast<Map<String, dynamic>>());
  }

  @override
  Future<List<QBitTaskSource>> getTaskSources(String taskId) async {
    final body = await session.getText('/api/v2/torrents/trackers?hash=$taskId');
    final List<dynamic> raw = jsonDecode(body);
    return raw
        .where(
            (item) => (item['url']?.toString() ?? '').startsWith('**'))
        .map((item) => _parseSource(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<QBitTaskPeer>> getTaskPeers(String taskId) async {
    final body =
        await session.getText('/api/v2/sync/torrentPeers?hash=$taskId&rid=0');
    final json = jsonDecode(body) as Map<String, dynamic>;
    final peers = json['peers'] as Map<String, dynamic>? ?? const {};
    return peers.entries
        .map((entry) => _parsePeer(
              key: entry.key,
              raw: entry.value as Map<String, dynamic>,
            ))
        .toList();
  }

  @override
  Future<QBitTaskOptions> getTaskOptions(String taskId) async {
    final infoBody =
        await session.getText('/api/v2/torrents/info?hashes=$taskId');
    final List<dynamic> infoList = jsonDecode(infoBody);
    final info = _firstByHash(infoList, taskId);

    final catsBody = await session.getText('/api/v2/torrents/categories');
    final cats = jsonDecode(catsBody) as Map<String, dynamic>;
    final availableCategories =
        cats.values.map((c) => (c as Map<String, dynamic>)['name'].toString()).toList();

    final tagsBody = await session.getText('/api/v2/torrents/tags');
    final List<dynamic> tagsJson = jsonDecode(tagsBody);
    final availableTags = tagsJson.map((t) => t.toString()).toList();

    return QBitTaskOptions(
      queuePosition: info?['priority'] as int? ?? -1,
      category: info?['category']?.toString() ?? '',
      tags: _parseTagsCsv(info?['tags']?.toString() ?? ''),
      availableCategories: availableCategories,
      availableTags: availableTags,
    );
  }

  @override
  Future<void> updateTaskOptions(
    String taskId, {
    required QBitTaskOptions current,
    required QBitTaskOptionsUpdate update,
  }) async {
    await _applyQueueAction(taskId, update.queueAction);
    await _applyCategory(
      taskId: taskId,
      current: current.category,
      next: update.category,
      available: current.availableCategories,
    );
    await _applyTags(
      taskId: taskId,
      current: current.tags,
      next: update.tags,
      available: current.availableTags,
    );
  }

  Future<void> _applyQueueAction(
      String taskId, QBitQueuePriorityAction action) async {
    final path = switch (action) {
      QBitQueuePriorityAction.unchanged => null,
      QBitQueuePriorityAction.top => '/api/v2/torrents/topPrio',
      QBitQueuePriorityAction.bottom => '/api/v2/torrents/bottomPrio',
      QBitQueuePriorityAction.increase => '/api/v2/torrents/increasePrio',
      QBitQueuePriorityAction.decrease => '/api/v2/torrents/decreasePrio',
    };
    if (path == null) return;
    final response = await session.postForm(path, {'hashes': taskId});
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent queue action 失败: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
  }

  Future<void> _applyCategory({
    required String taskId,
    required String current,
    required String next,
    required List<String> available,
  }) async {
    if (current == next) return;
    // 目标分类不在服务端目录时先创建，再归属。
    if (!available.contains(next)) {
      final create = await session.postForm(
        '/api/v2/torrents/createCategory',
        {'category': next},
      );
      if (create.statusCode != 200) {
        throw DownloaderServiceException(
          'qBittorrent createCategory 失败: HTTP ${create.statusCode}',
          category: DownloaderServiceErrorCategory.protocol,
        );
      }
    }
    final response = await session.postForm(
      '/api/v2/torrents/setCategory',
      {'hashes': taskId, 'category': next},
    );
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent setCategory 失败: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
  }

  Future<void> _applyTags({
    required String taskId,
    required List<String> current,
    required List<String> next,
    required List<String> available,
  }) async {
    final toAdd = next.where((t) => !current.contains(t)).toList();
    final toRemove = current.where((t) => !next.contains(t)).toList();
    final newTags = toAdd.where((t) => !available.contains(t)).toList();
    if (newTags.isNotEmpty) {
      final create = await session.postForm(
        '/api/v2/torrents/createTags',
        {'tags': newTags.join(',')},
      );
      if (create.statusCode != 200) {
        throw DownloaderServiceException(
          'qBittorrent createTags 失败: HTTP ${create.statusCode}',
          category: DownloaderServiceErrorCategory.protocol,
        );
      }
    }
    if (toRemove.isNotEmpty) {
      final response = await session.postForm(
        '/api/v2/torrents/removeTags',
        {'hashes': taskId, 'tags': toRemove.join(',')},
      );
      if (response.statusCode != 200) {
        throw DownloaderServiceException(
          'qBittorrent removeTags 失败: HTTP ${response.statusCode}',
          category: DownloaderServiceErrorCategory.protocol,
        );
      }
    }
    if (toAdd.isNotEmpty) {
      final response = await session.postForm(
        '/api/v2/torrents/addTags',
        {'hashes': taskId, 'tags': toAdd.join(',')},
      );
      if (response.statusCode != 200) {
        throw DownloaderServiceException(
          'qBittorrent addTags 失败: HTTP ${response.statusCode}',
          category: DownloaderServiceErrorCategory.protocol,
        );
      }
    }
  }

  QBitTaskDetail _parseDetail({
    required String taskId,
    required Map<String, dynamic> info,
    required Map<String, dynamic> props,
    required List<Map<String, dynamic>> trackers,
    required List<Map<String, dynamic>> webSeeds,
  }) {
    final realTrackers = trackers.where((t) {
      final url = t['url']?.toString() ?? '';
      return url.isNotEmpty && !url.startsWith('**');
    }).toList();
    // 仅存在 DHT/PeX/LSD 伪 tracker 时，仍展示 1 个来源入口。
    final sourceCount =
        realTrackers.isEmpty && trackers.isNotEmpty ? 1 : realTrackers.length;

    return QBitTaskDetail(
      taskId: taskId,
      downloaderId: session.downloader.id,
      name: info['name']?.toString() ?? 'Unknown',
      progress: (props['progress'] as num?)?.toDouble() ?? 0,
      queuePosition: info['priority'] as int? ?? -1,
      category: info['category']?.toString() ?? '',
      tags: _parseTagsCsv(info['tags']?.toString() ?? ''),
      savePath: info['save_path']?.toString() ?? '',
      totalSize: (props['total_size'] as num?)?.toInt() ?? 0,
      // /torrents/info 不含文件数；文件树由文件子页面 /torrents/files 提供。
      fileCount: 0,
      sourceCount: sourceCount,
      peerCount: (props['peers'] as num?)?.toInt() ?? 0,
      httpSourceCount: webSeeds.length,
      downloadSpeed: (info['dlspeed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (info['upspeed'] as num?)?.toInt() ?? 0,
      state: info['state']?.toString() ?? '',
      downloaded: (props['total_downloaded'] as num?)?.toInt() ?? 0,
      uploaded: (props['total_uploaded'] as num?)?.toInt() ?? 0,
      shareRatio: (props['share_ratio'] as num?)?.toDouble() ?? 0,
      eta: (props['eta'] as num?)?.toInt() ?? 0,
      dlSpeedAvg: (props['dl_speed_avg'] as num?)?.toInt() ?? 0,
      upSpeedAvg: (props['up_speed_avg'] as num?)?.toInt() ?? 0,
      seeds: (props['seeds_total'] as num?)?.toInt() ?? 0,
      leechs: (props['peers_total'] as num?)?.toInt() ?? 0,
      connections: (props['nb_connections'] as num?)?.toInt() ?? 0,
      connectionsLimit: (props['nb_connections_limit'] as num?)?.toInt() ?? 0,
      dlLimit: (props['dl_limit'] as num?)?.toInt() ?? -1,
      upLimit: (props['up_limit'] as num?)?.toInt() ?? -1,
      availability: (info['availability'] as num?)?.toDouble() ?? 0,
      pieceSize: (props['piece_size'] as num?)?.toInt() ?? 0,
      pieceCount: (props['pieces_num'] as num?)?.toInt() ?? 0,
      completedPieceCount: (props['pieces_have'] as num?)?.toInt() ?? 0,
      createdAt: _epochToDate(props['creation_date']),
      addedAt: _epochToDate(props['addition_date']),
      completedAt: _epochToDate(props['completion_date']),
      lastSeen: _epochToDate(props['last_seen']),
      timeElapsed: (props['time_elapsed'] as num?)?.toInt() ?? 0,
      seedingTime: (props['seeding_time'] as num?)?.toInt() ?? 0,
      createdBy: props['created_by']?.toString() ?? '',
      comment: props['comment']?.toString() ?? '',
      infoHashV1: (props['infohash_v1'] as String?) ?? '',
      infoHashV2: (props['infohash_v2'] as String?) ?? '',
    );
  }

  List<String> _parseTagsCsv(String raw) {
    return raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  DateTime? _epochToDate(num? epoch) {
    if (epoch == null || epoch <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch.toInt() * 1000,
        isUtc: false);
  }

  QBitTaskSource _parseSource(Map<String, dynamic> json) {
    final url = json['url']?.toString() ?? '';
    // `** [DHT] **` → `DHT`
    final name = RegExp(r'\*\*\s*\[(.*?)\]\s*\*\*').firstMatch(url)?.group(1) ??
        url.replaceAll('**', '').trim();
    final status = switch (json['status']) {
      0 => 'disabled',
      1 => 'not_yet_contacted',
      2 => 'working',
      3 => 'updating',
      4 => 'not_working',
      _ => 'unknown',
    };
    // qBit `/trackers` 计数字段语义：
    // num_peers=当前连接对端、num_seeds=做种者、num_leeches=下载者（活跃 leech）、
    // num_downloaded=累计已完成下载次数。UI "Downloads" 展示活跃 leech，
    // "Downloaded" 展示累计完成数。
    return QBitTaskSource(
      name: name.isEmpty ? 'Source' : name,
      status: status,
      peerCount: (json['num_peers'] as num?)?.toInt() ?? 0,
      seedCount: (json['num_seeds'] as num?)?.toInt() ?? 0,
      downloadCount: (json['num_leeches'] as num?)?.toInt() ?? 0,
      downloadedCount: (json['num_downloaded'] as num?)?.toInt() ?? 0,
    );
  }

  QBitTaskPeer _parsePeer({
    required String key,
    required Map<String, dynamic> raw,
  }) {
    // Map key 形如 `1.1.1.1:51413`，作为 ip/port 的兜底来源。
    final keyParts = key.split(':');
    final keyIp = keyParts.isNotEmpty ? keyParts.first : '';
    final keyPort = keyParts.length > 1 ? int.tryParse(keyParts[1]) ?? 0 : 0;

    final flags = (raw['flags']?.toString() ?? '')
        .split(' ')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    return QBitTaskPeer(
      address: raw['ip']?.toString() ?? keyIp,
      port: (raw['port'] as num?)?.toInt() ?? keyPort,
      protocol: raw['connection']?.toString() ?? '',
      stateTags: flags,
      downloadSpeed: (raw['dl_speed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (raw['up_speed'] as num?)?.toInt() ?? 0,
      downloaded: (raw['downloaded'] as num?)?.toInt() ?? 0,
      uploaded: (raw['uploaded'] as num?)?.toInt() ?? 0,
      progress: (raw['progress'] as num?)?.toDouble() ?? 0,
      relevance: (raw['relevance'] as num?)?.toDouble() ?? 0,
    );
  }

  /// 将扁平的文件列表（name 含 `/` 路径）聚合为目录树。
  ///
  /// 同一目录的多个文件归入同一目录节点；目录的 size/downloaded/progress
  /// 由其全部子节点汇总。返回根层节点列表。
  List<QBitTaskFileNode> _buildFileTree(List<Map<String, dynamic>> raw) {
    final builder = _FileTreeBuilder();
    for (final file in raw) {
      final full = file['name']?.toString() ?? '';
      final size = (file['size'] as num?)?.toInt() ?? 0;
      final progress = (file['progress'] as num?)?.toDouble() ?? 0;
      builder.add(path: full, size: size, progress: progress);
    }
    return builder.build();
  }

  DownloadTask _parseTask(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['hash'] ?? '',
      gid: json['hash'] ?? '',
      name: json['name'] ?? 'Unknown',
      totalSize: json['size'] ?? 0,
      downloaded: ((json['size'] ?? 0) * (json['progress'] ?? 0)).toInt(),
      progress: (json['progress'] ?? 0).toDouble(),
      downloadSpeed: json['dlspeed'] ?? 0,
      uploadSpeed: json['upspeed'] ?? 0,
      status: _parseStatus(json['state'] ?? ''),
      savePath: json['save_path'] ?? '',
      downloaderId: session.downloader.id,
      seeders: json['num_seeds'],
      peers: json['num_leechs'],
      connections: json['nb_connections'],
    );
  }

  TaskStatus _parseStatus(String state) {
    switch (state) {
      case 'downloading':
      case 'stalledDL':
      case 'forcedDL':
      case 'metaDL':
        return TaskStatus.downloading;
      // qBit 5.0+ 使用 stoppedDL/stoppedUP（替代旧版 pausedDL/pausedUP）
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
        // 检查/移动/分配中为瞬态，归入等待
        return TaskStatus.waiting;
      default:
        Log.w('QBitBaseApiAdapter._parseStatus: unhandled state="$state"');
        return TaskStatus.unknown;
    }
  }

  /// 按 hash 在 /torrents/info 列表中查找首个匹配项（无匹配返回 null）。
  Map<String, dynamic>? _firstByHash(List<dynamic> list, String taskId) {
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      if (m['hash'] == taskId) return m;
    }
    return null;
  }
}

/// 将扁平文件路径增量聚合为目录树。
///
/// 用 path 作为 key 缓存目录节点，保持首次插入顺序；叶子节点的
/// size/downloaded/progress 直接来自源数据，目录节点在 [build] 时汇总子节点。
class _FileTreeBuilder {
  _FileTreeBuilder()
      : _roots = <_BuildNode>[],
        _dirs = <String, _BuildNode>{};

  final List<_BuildNode> _roots;
  final Map<String, _BuildNode> _dirs;

  void add({required String path, required int size, required double progress}) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return;

    List<_BuildNode> currentLevel = _roots;
    var acc = '';
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      acc = acc.isEmpty ? segment : '$acc/$segment';
      final isLeaf = i == segments.length - 1;
      if (isLeaf) {
        currentLevel.add(_BuildNode(
          path: acc,
          name: segment,
          isDirectory: false,
          size: size,
          downloaded: (size * progress).round(),
          progress: progress,
        ));
      } else {
        var dir = _dirs[acc];
        if (dir == null) {
          dir = _BuildNode(path: acc, name: segment, isDirectory: true);
          _dirs[acc] = dir;
          currentLevel.add(dir);
        }
        currentLevel = dir.children;
      }
    }
  }

  List<QBitTaskFileNode> build() {
    return _roots.map(_materialize).toList();
  }

  QBitTaskFileNode _materialize(_BuildNode node) {
    if (!node.isDirectory) {
      return QBitTaskFileNode(
        path: node.path,
        name: node.name,
        isDirectory: false,
        size: node.size,
        downloaded: node.downloaded,
        progress: node.progress,
      );
    }
    final children = node.children.map(_materialize).toList();
    final size = children.fold<int>(0, (sum, c) => sum + c.size);
    final downloaded =
        children.fold<int>(0, (sum, c) => sum + c.downloaded);
    final progress = size == 0 ? 0.0 : downloaded / size;
    return QBitTaskFileNode(
      path: node.path,
      name: node.name,
      isDirectory: true,
      size: size,
      downloaded: downloaded,
      progress: progress,
      children: children,
    );
  }
}

/// 文件树构建中间结构。
class _BuildNode {
  _BuildNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.size = 0,
    this.downloaded = 0,
    this.progress = 0.0,
  });

  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final int downloaded;
  final double progress;
  final List<_BuildNode> children = [];
}
