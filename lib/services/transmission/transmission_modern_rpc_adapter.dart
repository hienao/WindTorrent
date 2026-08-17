import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/transmission_realtime_snapshot.dart';
import 'package:windwalker/models/transmission_task_detail.dart';
import 'package:windwalker/models/transmission_task_file_node.dart';
import 'package:windwalker/models/transmission_task_options.dart';
import 'package:windwalker/models/transmission_task_options_update.dart';
import 'package:windwalker/models/transmission_task_peer.dart';
import 'package:windwalker/models/transmission_task_tracker.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/transmission/transmission_file_tree_builder.dart';
import 'package:windwalker/services/transmission/transmission_protocol_info.dart';
import 'package:windwalker/services/transmission/transmission_rpc_adapter.dart';

/// Transmission modern RPC adapter（JSON-RPC 2.0 + snake_case）。
///
/// 适用于 Transmission 4.1.0+（rpc_version_semver ≥ 6.0.0）。
class TransmissionModernRpcAdapter implements TransmissionRpcAdapter {
  TransmissionModernRpcAdapter({
    required this.downloader,
    required this.protocolInfo,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Downloader downloader;
  final TransmissionProtocolInfo protocolInfo;
  final http.Client _client;

  String get _rpcUrl => downloader.rpcUrl;
  String? _sessionId;

  int _requestId = 0;

  Map<String, dynamic> _buildRequest(String method,
      [Map<String, dynamic>? params]) {
    return {
      'jsonrpc': '2.0',
      'method': method,
      'params': ?params,
      'id': ++_requestId,
    };
  }

  Map<String, String> _headers({String? sessionId}) => {
        'Content-Type': 'application/json',
        if ((sessionId ?? _sessionId) != null)
          'X-Transmission-Session-Id': sessionId ?? _sessionId!,
        if (downloader.username != null && downloader.password != null)
          'Authorization': _basicAuth(),
      };

  String get _headersWithoutSessionAuth =>
      downloader.username != null && downloader.password != null
          ? 'Basic ${base64Encode(utf8.encode("${downloader.username}:${downloader.password}"))}'
          : '';

  Map<String, String> get _headersWithoutSession => {
        'Content-Type': 'application/json',
        if (downloader.username != null && downloader.password != null)
          'Authorization': _headersWithoutSessionAuth,
      };

  String _basicAuth() {
    final raw = '${downloader.username}:${downloader.password}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  /// 确保有有效的 session id（CSRF token）
  Future<void> _ensureSession() async {
    if (_sessionId != null) return;

    final response = await _client
        .post(
          Uri.parse(_rpcUrl),
          headers: _headersWithoutSession,
          body: jsonEncode(_buildRequest('session_get')),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 409) {
      _sessionId = response.headers['x-transmission-session-id'];
      return;
    }

    if (response.statusCode == 200) {
      _sessionId = response.headers['x-transmission-session-id'];
      return;
    }

    if (response.statusCode == 401) {
      throw DownloaderServiceException(
        'Transmission 认证失败',
        category: DownloaderServiceErrorCategory.auth,
      );
    }

    throw DownloaderServiceException(
      'Transmission 会话建立失败: HTTP ${response.statusCode}',
      category: DownloaderServiceErrorCategory.network,
    );
  }

  /// 发送 JSON-RPC 2.0 请求，内部处理 session 和 409 重试。
  Future<Map<String, dynamic>> _call(String method,
      [Map<String, dynamic>? params]) async {
    await _ensureSession();

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_rpcUrl),
            headers: _headers(),
            body: jsonEncode(_buildRequest(method, params)),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e, st) {
      Log.e('TransmissionModern _call 网络错误', error: e, stackTrace: st);
      throw DownloaderServiceException(
        'Transmission $method 网络错误: $e',
        category: DownloaderServiceErrorCategory.network,
      );
    }

    // 409: CSRF token 过期，刷新后重试一次
    if (response.statusCode == 409) {
      _sessionId = response.headers['x-transmission-session-id'];
      try {
        response = await _client
            .post(
              Uri.parse(_rpcUrl),
              headers: _headers(),
              body: jsonEncode(_buildRequest(method, params)),
            )
            .timeout(const Duration(seconds: 30));
      } catch (e, st) {
        Log.e('TransmissionModern _call 重试网络错误',
            error: e, stackTrace: st);
        throw DownloaderServiceException(
          'Transmission $method 重试网络错误: $e',
          category: DownloaderServiceErrorCategory.network,
        );
      }
    }

    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'Transmission $method: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['error'] != null) {
      final error = data['error'];
      final message =
          error is Map ? error['message'] ?? error : error.toString();
      throw DownloaderServiceException(
        'Transmission $method: $message',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    return data['result'] as Map<String, dynamic>;
  }

  // ─── TransmissionRpcAdapter 实现 ──────────────────────────────

  @override
  Future<ConnectionResult> testConnection() async {
    try {
      final result = await _call('session_get');
      final semver = result['rpc_version_semver']?.toString() ?? '';
      final appVersionRaw = result['version']?.toString() ?? '';
      final appVersion = _normalizeAppVersion(appVersionRaw);

      if (semver.isEmpty) {
        return ConnectionFailure(
          ConnectionFailureCategory.versionUnsupported,
          'Transmission 版本信息缺失',
          actualVersion: appVersion,
          minVersion: '4.1.0',
        );
      }

      return ConnectionSuccess(
        serverVersion: appVersion.isEmpty ? semver : appVersion,
      );
    } catch (e) {
      if (e is DownloaderServiceException &&
          e.category == DownloaderServiceErrorCategory.auth) {
        return const ConnectionFailure(
          ConnectionFailureCategory.authFailed,
          'Transmission 用户名/密码错误',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<DownloadTask>> getTasks() async {
    final result = await _call('torrent_get', {
      'fields': [
        'id',
        'hash_string',
        'name',
        'total_size',
        'percent_done',
        'rate_download',
        'rate_upload',
        'status',
        'eta',
        'peers_sending_to_us',
        'peers_getting_from_us',
        'added_date',
        'done_date',
        'download_dir',
      ],
    });

    final torrents = result['torrents'] as List<dynamic>?;
    if (torrents == null || torrents.isEmpty) return [];
    return torrents
        .map((json) => _parseTask(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DownloadTask?> getTaskDetail(String taskId) async {
    final result = await _call('torrent_get', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'fields': [
        'id',
        'hash_string',
        'name',
        'total_size',
        'percent_done',
        'rate_download',
        'rate_upload',
        'status',
        'eta',
        'peers_sending_to_us',
        'peers_getting_from_us',
        'added_date',
        'done_date',
        'download_dir',
        'peers_connected',
        'trackers',
      ],
    });

    final torrents = result['torrents'] as List<dynamic>?;
    if (torrents == null || torrents.isEmpty) return null;
    return _parseTask(torrents.first as Map<String, dynamic>);
  }

  @override
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async {
    final result = await _call('torrent_get', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'fields': [
        'id',
        'hash_string',
        'name',
        'total_size',
        'piece_count',
        'piece_size',
        'download_dir',
        'is_private',
        'creator',
        'date_created',
        'magnet_link',
        'desired_available',
        'have_valid',
        'have_unchecked',
        'downloaded_ever',
        'uploaded_ever',
        'upload_ratio',
        'rate_download',
        'added_date',
        'done_date',
        'activity_date',
        'seconds_downloading',
        'seconds_seeding',
        'files',
        'trackers',
        'peers',
      ],
    });

    final torrents = result['torrents'] as List<dynamic>;
    if (torrents.isEmpty) {
      throw DownloaderServiceException(
        'Transmission 任务不存在',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    final json = torrents.first as Map<String, dynamic>;
    final totalSize = json['total_size'] as int? ?? 0;
    final desiredAvailable = (json['desired_available'] as num?)?.toInt() ?? 0;
    return TransmissionTaskDetail(
      taskId: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? 'Unknown',
      downloaderId: downloader.id,
      totalSize: totalSize,
      pieceCount: json['piece_count'] as int? ?? 0,
      pieceSize: json['piece_size'] as int? ?? 0,
      savePath: json['download_dir'] as String? ?? '',
      isPrivate: json['is_private'] as bool? ?? false,
      creator: json['creator'] as String?,
      createdAt: _timestampOrNull(json['date_created']),
      magnet: json['magnet_link'] as String?,
      availablePercent: totalSize > 0
          ? (totalSize - desiredAvailable) / totalSize
          : 0,
      downloadedEver: (json['have_valid'] as int? ?? 0) +
          (json['have_unchecked'] as int? ?? 0),
      uploadedEver: json['uploaded_ever'] as int? ?? 0,
      ratio: (json['upload_ratio'] as num?)?.toDouble() ?? 0,
      averageSpeed: json['rate_download'] as int? ?? 0,
      addedAt: _timestampOrNull(json['added_date']),
      completedAt: _timestampOrNull(json['done_date']),
      lastActivityAt: _timestampOrNull(json['activity_date']),
      downloadDuration:
          Duration(seconds: json['seconds_downloading'] as int? ?? 0),
      seedingDuration:
          Duration(seconds: json['seconds_seeding'] as int? ?? 0),
      fileCount: (json['files'] as List?)?.length ?? 0,
      trackerCount: (json['trackers'] as List?)?.length ?? 0,
      peerCount: (json['peers'] as List?)?.length ?? 0,
      optionsEditable: true,
    );
  }

  @override
  Future<TransmissionRealtimeSnapshot> getRealtimeSnapshot() async {
    final result = await _call('torrent_get', {
      'fields': [
        'id',
        'name',
        'status',
        'percent_done',
        'total_size',
        'left_until_done',
        'rate_download',
        'rate_upload',
        'download_dir',
        'peers_sending_to_us',
        'peers_getting_from_us',
        'tracker_stats',
        'added_date',
        'done_date',
        'activity_date',
        'seconds_downloading',
        'seconds_seeding',
        'piece_count',
        'downloaded_ever',
        'uploaded_ever',
        'upload_ratio',
        'error',
        'error_string',
        'labels',
      ],
    });

    final torrents = (result['torrents'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return TransmissionRealtimeSnapshot.fromRpc(
      downloaderId: downloader.id,
      torrents: torrents,
    );
  }

  @override
  Future<Map<String, dynamic>> getGlobalStat() async {
    final result = await _call('session_stats');
    return {
      'downloadSpeed': result['download_speed'] ?? 0,
      'uploadSpeed': result['upload_speed'] ?? 0,
      'torrentCount': result['torrent_count'] ?? 0,
    };
  }

  @override
  Future<String> addTask(AddTaskRequest request) async {
    if (request.hasUrlSource) {
      return _addDownload(request.url!, savePath: request.savePath);
    }

    final result = await _call('torrent_add', {
      'metainfo': base64Encode(request.torrentFileBytes!),
      if (request.savePath != null) 'download_dir': request.savePath,
    });

    return result['torrent_added']?['id']?.toString() ??
        result['torrent_duplicate']?['id']?.toString() ??
        '';
  }

  Future<String> _addDownload(String url, {String? savePath}) async {
    final result = await _call('torrent_add', {
      'filename': url,
      'download_dir': ?savePath,
    });

    return result['torrent_added']?['id']?.toString() ??
        result['torrent_duplicate']?['id']?.toString() ??
        '';
  }

  @override
  Future<void> pauseTask(String taskId) async {
    await _call('torrent_stop', {
      'ids': [int.tryParse(taskId) ?? 0],
    });
  }

  @override
  Future<void> resumeTask(String taskId) async {
    await _call('torrent_start', {
      'ids': [int.tryParse(taskId) ?? 0],
    });
  }

  @override
  Future<void> removeTask(String taskId, {bool deleteFiles = false}) async {
    await _call('torrent_remove', {
      'ids': [int.tryParse(taskId) ?? 0],
      'delete_local_data': deleteFiles,
    });
  }

  @override
  Future<DownloaderSpeedConfig> getSpeedConfig() async {
    final result = await _call('session_get');
    return DownloaderSpeedConfig(
      speedLimitModeEnabled: result['alt_speed_enabled'] as bool? ?? false,
      downloadLimitKB: result['speed_limit_down'] as int? ?? 0,
      uploadLimitKB: result['speed_limit_up'] as int? ?? 0,
      altDownloadLimitKB: result['alt_speed_down'] as int? ?? 0,
      altUploadLimitKB: result['alt_speed_up'] as int? ?? 0,
    );
  }

  @override
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config) async {
    await _call('session_set', {
      'speed_limit_down_enabled': true,
      'speed_limit_down': config.downloadLimitKB,
      'speed_limit_up_enabled': true,
      'speed_limit_up': config.uploadLimitKB,
      'alt_speed_enabled': config.speedLimitModeEnabled,
      'alt_speed_down': config.altDownloadLimitKB,
      'alt_speed_up': config.altUploadLimitKB,
    });
    return true;
  }

  // ─── 子页面数据方法 ──────────────────────────────────────────

  @override
  Future<List<TransmissionTaskFileNode>> getTaskFiles(String taskId) async {
    final result = await _call('torrent_get', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'fields': ['files'],
    });

    final torrents = result['torrents'] as List<dynamic>;
    if (torrents.isEmpty) {
      throw DownloaderServiceException(
        'Transmission 任务不存在',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    final json = torrents.first as Map<String, dynamic>;
    return _parseFiles(json['files']);
  }

  @override
  Future<List<TransmissionTaskTracker>> getTaskTrackers(String taskId) async {
    final result = await _call('torrent_get', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'fields': ['trackers'],
    });

    final torrents = result['torrents'] as List<dynamic>;
    if (torrents.isEmpty) {
      throw DownloaderServiceException(
        'Transmission 任务不存在',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    final json = torrents.first as Map<String, dynamic>;
    return _parseTrackers(json['trackers']);
  }

  @override
  Future<List<TransmissionTaskPeer>> getTaskPeers(String taskId) async {
    final result = await _call('torrent_get', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'fields': ['peers'],
    });

    final torrents = result['torrents'] as List<dynamic>;
    if (torrents.isEmpty) {
      throw DownloaderServiceException(
        'Transmission 任务不存在',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    final json = torrents.first as Map<String, dynamic>;
    return _parsePeers(json['peers']);
  }

  @override
  Future<TransmissionTaskOptions> getTaskOptions(String taskId) async {
    final result = await _call('torrent_get', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'fields': [
        'bandwidth_priority',
        'honors_session_limits',
        'download_limited',
        'download_limit',
        'upload_limited',
        'upload_limit',
        'seed_ratio_mode',
        'seed_ratio_limit',
        'idle_seeding_limit_mode',
        'idle_seeding_limit',
      ],
    });

    final torrents = result['torrents'] as List<dynamic>;
    if (torrents.isEmpty) {
      throw DownloaderServiceException(
        'Transmission 任务不存在',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    final json = torrents.first as Map<String, dynamic>;
    return _parseOptions(json);
  }

  @override
  Future<void> updateTaskOptions(
    String taskId,
    TransmissionTaskOptionsUpdate update,
  ) async {
    await _call('torrent_set', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'bandwidth_priority': update.bandwidthPriority,
      'honors_session_limits': update.honorsSessionLimits,
      'download_limited': update.downloadLimited,
      'download_limit': update.downloadLimitKBps,
      'upload_limited': update.uploadLimited,
      'upload_limit': update.uploadLimitKBps,
      'seed_ratio_mode': update.seedRatioMode.rpcValue,
      'seed_ratio_limit': update.seedRatioLimit,
      'idle_seeding_limit_mode': update.idleLimitMode.rpcValue,
      'idle_seeding_limit': update.idleLimitMinutes,
    });
  }

  // ─── 内部解析 ──────────────────────────────────────────────────

  DateTime? _timestampOrNull(dynamic value) {
    if (value == null) return null;
    final seconds = value is int ? value : int.tryParse(value.toString());
    if (seconds == null || seconds == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  DownloadTask _parseTask(Map<String, dynamic> json) {
    final totalSize = json['total_size'] as int? ?? 0;
    final percentDone = (json['percent_done'] ?? 0).toDouble();

    return DownloadTask(
      id: json['id']?.toString() ?? '',
      gid: json['hash_string']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      totalSize: totalSize,
      downloaded: (totalSize * percentDone).toInt(),
      progress: percentDone,
      downloadSpeed: json['rate_download'] ?? 0,
      uploadSpeed: json['rate_upload'] ?? 0,
      status: _parseStatus(json['status']),
      savePath: json['download_dir'] ?? '',
      downloaderId: downloader.id,
      addedAt: json['added_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['added_date'] * 1000)
          : null,
      doneAt: json['done_date'] != null && json['done_date'] > 0
          ? DateTime.fromMillisecondsSinceEpoch(json['done_date'] * 1000)
          : null,
      seeders: json['peers_sending_to_us'],
      peers: json['peers_getting_from_us'],
      connections: json['peers_connected'],
      tracker: _parseTrackerUrl(json['trackers']),
    );
  }

  String? _parseTrackerUrl(dynamic trackers) {
    if (trackers is! List || trackers.isEmpty) return null;
    for (final t in trackers) {
      if (t is Map) {
        final announce = t['announce']?.toString() ?? '';
        if (announce.isNotEmpty) return announce;
      }
    }
    return null;
  }

  TaskStatus _parseStatus(int? status) {
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

  String _normalizeAppVersion(String raw) {
    if (raw.isEmpty) return '';
    return raw.split(RegExp(r'\s+')).first.trim();
  }

  List<TransmissionTaskFileNode> _parseFiles(dynamic filesJson) {
    if (filesJson is! List) return [];
    final flat = filesJson.map((f) {
      final file = f as Map<String, dynamic>;
      final name = file['name'] as String? ?? '';
      final length = file['length'] as int? ?? 0;
      final bytesCompleted = file['bytes_completed'] as int? ?? 0;
      final parts = name.split('/');
      return TransmissionTaskFileNode(
        path: name,
        name: parts.isNotEmpty ? parts.last : name,
        isDirectory: false,
        size: length,
        downloaded: bytesCompleted,
        progress: length > 0 ? bytesCompleted / length : 0,
      );
    }).toList();
    return buildFileTree(flat);
  }

  List<TransmissionTaskTracker> _parseTrackers(dynamic trackersJson) {
    if (trackersJson is! List) return [];
    return trackersJson.map((t) {
      final tracker = t as Map<String, dynamic>;
      final announce = tracker['announce'] as String? ?? '';
      final host = tracker['sitename'] as String? ?? _extractHost(announce);
      return TransmissionTaskTracker(
        id: tracker['id'] as int? ?? 0,
        host: host,
        announce: announce,
        tier: tracker['tier'] as int? ?? 0,
        lastAnnounceAt: _timestampOrNull(tracker['last_announce_time']),
        nextAnnounceAt: _timestampOrNull(tracker['next_announce_time']),
        lastScrapeAt: _timestampOrNull(tracker['last_scrape_time']),
        seederCount: tracker['seeder_count'] as int? ?? 0,
        leecherCount: tracker['leecher_count'] as int? ?? 0,
        downloadCount: tracker['download_count'] as int? ?? 0,
        status: tracker['last_announce_result'] as String?,
        errorMessage: tracker['last_announce_peer_count'] != null
            ? null
            : tracker['last_announce_result'] as String?,
      );
    }).toList();
  }

  List<TransmissionTaskPeer> _parsePeers(dynamic peersJson) {
    if (peersJson is! List) return [];
    return peersJson.map((p) {
      final peer = p as Map<String, dynamic>;
      return TransmissionTaskPeer(
        address: peer['address'] as String? ?? '',
        clientName: peer['client_name'] as String? ?? '',
        port: peer['port'] as int? ?? 0,
        progress: (peer['progress'] as num?)?.toDouble() ?? 0,
        downloadSpeed: peer['rate_to_client'] as int? ?? 0,
        uploadSpeed: peer['rate_to_peer'] as int? ?? 0,
        isDownloadingToUs: peer['isDownloadingFromUs'] as bool? ?? false,
        isUploadingFromUs: peer['isUploadingToUs'] as bool? ?? false,
      );
    }).toList();
  }

  TransmissionTaskOptions _parseOptions(Map<String, dynamic> json) {
    return TransmissionTaskOptions(
      bandwidthPriority: json['bandwidth_priority'] as int? ?? 0,
      honorsSessionLimits: json['honors_session_limits'] as bool? ?? true,
      downloadLimited: json['download_limited'] as bool? ?? false,
      downloadLimitKBps: json['download_limit'] as int? ?? 0,
      uploadLimited: json['upload_limited'] as bool? ?? false,
      uploadLimitKBps: json['upload_limit'] as int? ?? 0,
      seedRatioMode: TransmissionLimitMode.fromRpcValue(
        json['seed_ratio_mode'] as int? ?? 0,
      ),
      seedRatioLimit: (json['seed_ratio_limit'] as num?)?.toDouble() ?? 0,
      idleLimitMode: TransmissionLimitMode.fromRpcValue(
        json['idle_seeding_limit_mode'] as int? ?? 0,
      ),
      idleLimitMinutes: json['idle_seeding_limit'] as int? ?? 0,
    );
  }

  String _extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty
          ? '${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}'
          : url;
    } catch (_) {
      return url;
    }
  }
}
