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

/// Transmission legacy RPC adapter（legacy RPC + kebab-case / camelCase）。
///
/// 适用于 Transmission <4.1.0（rpc_version_semver < 6.0.0）。
class TransmissionLegacyRpcAdapter implements TransmissionRpcAdapter {
  TransmissionLegacyRpcAdapter({
    required this.downloader,
    required this.protocolInfo,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Downloader downloader;
  final TransmissionProtocolInfo protocolInfo;
  final http.Client _client;

  String get _rpcUrl => downloader.rpcUrl;
  String? _sessionId;

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
          body: jsonEncode({
            'method': 'session-get',
            'tag': 0,
          }),
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

  /// 发送 legacy RPC 请求，内部处理 session 和 409 重试。
  Future<Map<String, dynamic>> _call(String method,
      [Map<String, dynamic>? arguments]) async {
    await _ensureSession();

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_rpcUrl),
            headers: _headers(),
            body: jsonEncode({
              'method': method,
              'arguments': ?arguments,
              'tag': 1,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e, st) {
      Log.e('TransmissionLegacy _call 网络错误', error: e, stackTrace: st);
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
              body: jsonEncode({
                'method': method,
                'arguments': ?arguments,
                'tag': 1,
              }),
            )
            .timeout(const Duration(seconds: 30));
      } catch (e, st) {
        Log.e('TransmissionLegacy _call 重试网络错误',
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
    if (data['result'] != 'success') {
      throw DownloaderServiceException(
        'Transmission $method: ${data['result']}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    return (data['arguments'] as Map<String, dynamic>?) ?? {};
  }

  // ─── TransmissionRpcAdapter 实现 ──────────────────────────────

  @override
  Future<ConnectionResult> testConnection() async {
    try {
      final result = await _call('session-get');
      final semver = result['rpc-version-semver']?.toString() ?? '';
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
    final result = await _call('torrent-get', {
      'fields': [
        'id',
        'hashString',
        'name',
        'totalSize',
        'percentDone',
        'rateDownload',
        'rateUpload',
        'status',
        'eta',
        'peersSendingToUs',
        'peersGettingFromUs',
        'addedDate',
        'doneDate',
        'downloadDir',
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
    final result = await _call('torrent-get', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'fields': [
        'id',
        'hashString',
        'name',
        'totalSize',
        'percentDone',
        'rateDownload',
        'rateUpload',
        'status',
        'eta',
        'peersSendingToUs',
        'peersGettingFromUs',
        'addedDate',
        'doneDate',
        'downloadDir',
        'peersConnected',
        'trackers',
      ],
    });

    final torrents = result['torrents'] as List<dynamic>?;
    if (torrents == null || torrents.isEmpty) return null;
    return _parseTask(torrents.first as Map<String, dynamic>);
  }

  @override
  Future<TransmissionTaskDetail> getTaskFullDetail(String taskId) async {
    final result = await _call('torrent-get', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'fields': [
        'id',
        'hashString',
        'name',
        'totalSize',
        'pieceCount',
        'pieceSize',
        'downloadDir',
        'isPrivate',
        'creator',
        'dateCreated',
        'magnetLink',
        'desiredAvailable',
        'haveValid',
        'haveUnchecked',
        'downloadedEver',
        'uploadedEver',
        'uploadRatio',
        'rateDownload',
        'addedDate',
        'doneDate',
        'activityDate',
        'secondsDownloading',
        'secondsSeeding',
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
    final totalSize = json['totalSize'] as int? ?? 0;
    final desiredAvailable = (json['desiredAvailable'] as num?)?.toInt() ?? 0;
    return TransmissionTaskDetail(
      taskId: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? 'Unknown',
      downloaderId: downloader.id,
      totalSize: totalSize,
      pieceCount: json['pieceCount'] as int? ?? 0,
      pieceSize: json['pieceSize'] as int? ?? 0,
      savePath: json['downloadDir'] as String? ?? '',
      isPrivate: json['isPrivate'] as bool? ?? false,
      creator: json['creator'] as String?,
      createdAt: _timestampOrNull(json['dateCreated']),
      magnet: json['magnetLink'] as String?,
      availablePercent: totalSize > 0
          ? (totalSize - desiredAvailable) / totalSize
          : 0,
      downloadedEver: (json['haveValid'] as int? ?? 0) +
          (json['haveUnchecked'] as int? ?? 0),
      uploadedEver: json['uploadedEver'] as int? ?? 0,
      ratio: (json['uploadRatio'] as num?)?.toDouble() ?? 0,
      averageSpeed: json['rateDownload'] as int? ?? 0,
      addedAt: _timestampOrNull(json['addedDate']),
      completedAt: _timestampOrNull(json['doneDate']),
      lastActivityAt: _timestampOrNull(json['activityDate']),
      downloadDuration:
          Duration(seconds: json['secondsDownloading'] as int? ?? 0),
      seedingDuration: Duration(seconds: json['secondsSeeding'] as int? ?? 0),
      fileCount: (json['files'] as List?)?.length ?? 0,
      trackerCount: (json['trackers'] as List?)?.length ?? 0,
      peerCount: (json['peers'] as List?)?.length ?? 0,
      optionsEditable: true,
    );
  }

  @override
  Future<TransmissionRealtimeSnapshot> getRealtimeSnapshot() async {
    final result = await _call('torrent-get', {
      'fields': [
        'id',
        'name',
        'status',
        'percentDone',
        'totalSize',
        'leftUntilDone',
        'rateDownload',
        'rateUpload',
        'downloadDir',
        'peersSendingToUs',
        'peersGettingFromUs',
        'trackerStats',
        'addedDate',
        'doneDate',
        'activityDate',
        'secondsDownloading',
        'secondsSeeding',
        'pieceCount',
        'downloadedEver',
        'uploadedEver',
        'uploadRatio',
        'error',
        'errorString',
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
    final result = await _call('session-stats');
    return {
      'downloadSpeed': result['downloadSpeed'] ?? 0,
      'uploadSpeed': result['uploadSpeed'] ?? 0,
      'torrentCount': result['torrentCount'] ??
          result['activeTorrentCount'] ??
          0,
    };
  }

  @override
  Future<String> addTask(AddTaskRequest request) async {
    if (request.hasUrlSource) {
      return _addDownload(request.url!, savePath: request.savePath);
    }

    final result = await _call('torrent-add', {
      'metainfo': base64Encode(request.torrentFileBytes!),
      if (request.savePath != null) 'download-dir': request.savePath,
    });

    return result['torrent-added']?['id']?.toString() ??
        result['torrent-duplicate']?['id']?.toString() ??
        '';
  }

  Future<String> _addDownload(String url, {String? savePath}) async {
    final result = await _call('torrent-add', {
      'filename': url,
      'download-dir': ?savePath,
    });

    return result['torrent-added']?['id']?.toString() ??
        result['torrent-duplicate']?['id']?.toString() ??
        '';
  }

  @override
  Future<void> pauseTask(String taskId) async {
    await _call('torrent-stop', {
      'ids': [int.tryParse(taskId) ?? 0],
    });
  }

  @override
  Future<void> resumeTask(String taskId) async {
    await _call('torrent-start', {
      'ids': [int.tryParse(taskId) ?? 0],
    });
  }

  @override
  Future<void> removeTask(String taskId, {bool deleteFiles = false}) async {
    await _call('torrent-remove', {
      'ids': [int.tryParse(taskId) ?? 0],
      'delete-local-data': deleteFiles,
    });
  }

  @override
  Future<DownloaderSpeedConfig> getSpeedConfig() async {
    final result = await _call('session-get');
    return DownloaderSpeedConfig(
      speedLimitModeEnabled: result['alt-speed-enabled'] as bool? ?? false,
      downloadLimitKB: result['speed-limit-down'] as int? ?? 0,
      uploadLimitKB: result['speed-limit-up'] as int? ?? 0,
      altDownloadLimitKB: result['alt-speed-down'] as int? ?? 0,
      altUploadLimitKB: result['alt-speed-up'] as int? ?? 0,
    );
  }

  @override
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config) async {
    await _call('session-set', {
      'speed-limit-down-enabled': true,
      'speed-limit-down': config.downloadLimitKB,
      'speed-limit-up-enabled': true,
      'speed-limit-up': config.uploadLimitKB,
      'alt-speed-enabled': config.speedLimitModeEnabled,
      'alt-speed-down': config.altDownloadLimitKB,
      'alt-speed-up': config.altUploadLimitKB,
    });
    return true;
  }

  // ─── 子页面数据方法 ──────────────────────────────────────────

  @override
  Future<List<TransmissionTaskFileNode>> getTaskFiles(String taskId) async {
    final result = await _call('torrent-get', {
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
    final result = await _call('torrent-get', {
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
    final result = await _call('torrent-get', {
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
    final result = await _call('torrent-get', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'fields': [
        'bandwidthPriority',
        'honorsSessionLimits',
        'downloadLimited',
        'downloadLimit',
        'uploadLimited',
        'uploadLimit',
        'seedRatioMode',
        'seedRatioLimit',
        'idleSeedingLimitMode',
        'idleSeedingLimit',
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
    await _call('torrent-set', {
      'ids': [int.tryParse(taskId) ?? taskId],
      'bandwidthPriority': update.bandwidthPriority,
      'honorsSessionLimits': update.honorsSessionLimits,
      'downloadLimited': update.downloadLimited,
      'downloadLimit': update.downloadLimitKBps,
      'uploadLimited': update.uploadLimited,
      'uploadLimit': update.uploadLimitKBps,
      'seedRatioMode': update.seedRatioMode.rpcValue,
      'seedRatioLimit': update.seedRatioLimit,
      'idleSeedingLimitMode': update.idleLimitMode.rpcValue,
      'idleSeedingLimit': update.idleLimitMinutes,
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
    final totalSize = json['totalSize'] as int? ?? 0;
    final percentDone = (json['percentDone'] ?? 0).toDouble();

    return DownloadTask(
      id: json['id']?.toString() ?? '',
      gid: json['hashString']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      totalSize: totalSize,
      downloaded: (totalSize * percentDone).toInt(),
      progress: percentDone,
      downloadSpeed: json['rateDownload'] ?? 0,
      uploadSpeed: json['rateUpload'] ?? 0,
      status: _parseStatus(json['status']),
      savePath: json['downloadDir'] ?? '',
      downloaderId: downloader.id,
      addedAt: json['addedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['addedDate'] * 1000)
          : null,
      doneAt: json['doneDate'] != null && json['doneDate'] > 0
          ? DateTime.fromMillisecondsSinceEpoch(json['doneDate'] * 1000)
          : null,
      seeders: json['peersSendingToUs'],
      peers: json['peersGettingFromUs'],
      connections: json['peersConnected'],
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
      final bytesCompleted = file['bytesCompleted'] as int? ?? 0;
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
        lastAnnounceAt: _timestampOrNull(tracker['lastAnnounceTime']),
        nextAnnounceAt: _timestampOrNull(tracker['nextAnnounceTime']),
        lastScrapeAt: _timestampOrNull(tracker['lastScrapeTime']),
        seederCount: tracker['seederCount'] as int? ?? 0,
        leecherCount: tracker['leecherCount'] as int? ?? 0,
        downloadCount: tracker['downloadCount'] as int? ?? 0,
        status: tracker['lastAnnounceResult'] as String?,
        errorMessage: tracker['lastAnnouncePeerCount'] != null
            ? null
            : tracker['lastAnnounceResult'] as String?,
      );
    }).toList();
  }

  List<TransmissionTaskPeer> _parsePeers(dynamic peersJson) {
    if (peersJson is! List) return [];
    return peersJson.map((p) {
      final peer = p as Map<String, dynamic>;
      return TransmissionTaskPeer(
        address: peer['address'] as String? ?? '',
        clientName: peer['clientName'] as String? ?? '',
        port: peer['port'] as int? ?? 0,
        progress: (peer['progress'] as num?)?.toDouble() ?? 0,
        downloadSpeed: peer['rateToClient'] as int? ?? 0,
        uploadSpeed: peer['rateToPeer'] as int? ?? 0,
        isDownloadingToUs: peer['isDownloadingFromUs'] as bool? ?? false,
        isUploadingFromUs: peer['isUploadingToUs'] as bool? ?? false,
      );
    }).toList();
  }

  TransmissionTaskOptions _parseOptions(Map<String, dynamic> json) {
    return TransmissionTaskOptions(
      bandwidthPriority: json['bandwidthPriority'] as int? ?? 0,
      honorsSessionLimits: json['honorsSessionLimits'] as bool? ?? true,
      downloadLimited: json['downloadLimited'] as bool? ?? false,
      downloadLimitKBps: json['downloadLimit'] as int? ?? 0,
      uploadLimited: json['uploadLimited'] as bool? ?? false,
      uploadLimitKBps: json['uploadLimit'] as int? ?? 0,
      seedRatioMode: TransmissionLimitMode.fromRpcValue(
        json['seedRatioMode'] as int? ?? 0,
      ),
      seedRatioLimit: (json['seedRatioLimit'] as num?)?.toDouble() ?? 0,
      idleLimitMode: TransmissionLimitMode.fromRpcValue(
        json['idleSeedingLimitMode'] as int? ?? 0,
      ),
      idleLimitMinutes: json['idleSeedingLimit'] as int? ?? 0,
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
