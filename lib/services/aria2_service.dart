import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/aria2/aria2_task_file.dart';
import 'package:windwalker/models/aria2/aria2_task_options.dart';
import 'package:windwalker/models/aria2/aria2_task_peer.dart';
import 'package:windwalker/models/aria2_realtime_snapshot.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/speed_config_descriptor.dart';
import 'package:windwalker/services/base_downloader_service.dart';
import 'package:windwalker/services/connection_result.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

/// Aria2 下载器服务
class Aria2Service extends DownloaderService {
  final http.Client _client;

  Aria2Service(super.downloader, {http.Client? client})
      : _client = client ?? http.Client();

  String get _rpcUrl => downloader.rpcUrl;
  String get _secret => downloader.secret ?? '';

  static const String _minVersion = '1.36';

  @override
  Future<ConnectionResult> testConnection() async {
    try {
      final response = await _client
          .post(
            Uri.parse(_rpcUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'aria2.getVersion',
              'params': ['token:$_secret'],
              'id': 1,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const ConnectionFailure(
          ConnectionFailureCategory.networkError, '无法连接 Aria2');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;

      // 200 + error（如 secret 错误 Unauthorized）→ 认证失败
      if (data['error'] != null) {
        return const ConnectionFailure(
          ConnectionFailureCategory.authFailed, 'Aria2 RPC secret 错误');
      }

      final result = data['result'];
      if (result is! Map) {
        return const ConnectionFailure(
          ConnectionFailureCategory.unknown, 'Aria2 响应异常');
      }

      final version = result['version']?.toString() ?? '';
      if (_meetsMinVersion(version, _minVersion)) {
        return ConnectionSuccess(serverVersion: version);
      }
      return ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        'Aria2 版本过低',
        actualVersion: version,
        minVersion: _minVersion,
      );
    } catch (e) {
      Log.e('Aria2 testConnection error', error: e);
      return const ConnectionFailure(
        ConnectionFailureCategory.networkError, '无法连接 Aria2');
    }
  }

  /// 比较 major.minor 是否 ≥ [min]（min 形如 "1.36"）。
  bool _meetsMinVersion(String version, String min) {
    int toInt(List<String> parts, int i) =>
        i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0;
    final v = version.split('.');
    final m = min.split('.');
    for (var i = 0; i < 2; i++) {
      if (toInt(v, i) != toInt(m, i)) return toInt(v, i) > toInt(m, i);
    }
    return true; // major.minor 相等即达标
  }

  @override
  Future<List<DownloadTask>> getTasks() async {
    final List<DownloadTask> tasks = [];

    // 获取活跃任务
    final active = await _call('aria2.tellActive', [
      'token:$_secret',
      [
        'gid',
        'name',
        'totalLength',
        'completedLength',
        'downloadSpeed',
        'uploadSpeed',
        'files',
        'numSeeders',
        'status',
        'bittorrent',
      ],
    ]);
    if (active is List) {
      for (final task in active) {
        tasks.add(_parseTask(task, _parseAria2Status(task['status'])));
      }
    }

    // 获取等待中任务
    final waiting = await _call('aria2.tellWaiting', [
      'token:$_secret',
      0,
      100,
      [
        'gid',
        'name',
        'totalLength',
        'completedLength',
        'downloadSpeed',
        'uploadSpeed',
        'files',
        'numSeeders',
        'status',
        'bittorrent',
      ],
    ]);
    if (waiting is List) {
      for (final task in waiting) {
        tasks.add(_parseTask(task, _parseAria2Status(task['status'])));
      }
    }

    // 获取已完成任务
    final stopped = await _call('aria2.tellStopped', [
      'token:$_secret',
      0,
      100,
      [
        'gid',
        'name',
        'totalLength',
        'completedLength',
        'downloadSpeed',
        'uploadSpeed',
        'files',
        'numSeeders',
        'status',
        'bittorrent',
      ],
    ]);
    if (stopped is List) {
      for (final task in stopped) {
        tasks.add(_parseTask(task, _parseAria2Status(task['status'])));
      }
    }

    return tasks;
  }

  @override
  Future<Map<String, dynamic>> getGlobalStat() async {
    return (await _call('aria2.getGlobalStat', ['token:$_secret']))
        as Map<String, dynamic>;
  }

  /// 全量轮询快照：获取所有任务（活跃 + 等待中 + 已停止） + 全局统计。
  ///
  /// 由 [RealtimeSyncController] 定时调用，返回 [Aria2RealtimeSnapshot]。
  /// 与 [getTasks] 一致，查询 `tellActive` + `tellWaiting` + `tellStopped`，
  /// 确保所有状态的任务都能在 UI 中显示。
  Future<Aria2RealtimeSnapshot> getRealtimeSnapshot() async {
    final fields = [
      'gid',
      'name',
      'totalLength',
      'completedLength',
      'downloadSpeed',
      'uploadSpeed',
      'files',
      'numSeeders',
      'status',
      'bittorrent',
    ];

    final tasks = <DownloadTask>[];

    // 获取活跃任务
    final active = await _call('aria2.tellActive', [
      'token:$_secret',
      fields,
    ]);
    if (active is List) {
      for (final task in active) {
        tasks.add(_parseTask(task, _parseAria2Status(task['status'])));
      }
    }

    // 获取等待中任务（包含暂停的任务）
    final waiting = await _call('aria2.tellWaiting', [
      'token:$_secret',
      0,
      100,
      fields,
    ]);
    if (waiting is List) {
      for (final task in waiting) {
        tasks.add(_parseTask(task, _parseAria2Status(task['status'])));
      }
    }

    // 获取已停止任务（已完成/出错/已移除）
    final stopped = await _call('aria2.tellStopped', [
      'token:$_secret',
      0,
      100,
      fields,
    ]);
    if (stopped is List) {
      for (final task in stopped) {
        tasks.add(_parseTask(task, _parseAria2Status(task['status'])));
      }
    }

    final stat = await getGlobalStat();
    final dlSpeed =
        int.tryParse(stat['downloadSpeed']?.toString() ?? '0') ?? 0;
    final ulSpeed =
        int.tryParse(stat['uploadSpeed']?.toString() ?? '0') ?? 0;
    return Aria2RealtimeSnapshot(
      downloaderId: downloader.id,
      tasks: tasks,
      downloadSpeed: dlSpeed,
      uploadSpeed: ulSpeed,
    );
  }

  @override
  Future<String> addTask(AddTaskRequest request) async {
    if (request.hasUrlSource) {
      return addDownload(request.url!, savePath: request.savePath);
    }

    final result = await _call('aria2.addTorrent', [
      'token:$_secret',
      base64Encode(request.torrentFileBytes!),
      [],
      if (request.savePath != null) {'dir': request.savePath},
    ]);

    if (result == null) {
      throw DownloaderServiceException(
        'Aria2 addTorrent 无返回值',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    return result.toString();
  }

  @override
  Future<String> addDownload(String url, {String? savePath}) async {
    final result = await _call('aria2.addUri', [
      'token:$_secret',
      [url],
      if (savePath != null) {'dir': savePath},
    ]);
    if (result == null) {
      throw DownloaderServiceException(
        'Aria2 addUri 无返回值',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    return result.toString();
  }

  @override
  Future<void> pauseTask(String taskId) async {
    await _call('aria2.pause', ['token:$_secret', taskId]);
  }

  @override
  Future<void> resumeTask(String taskId) async {
    await _call('aria2.unpause', ['token:$_secret', taskId]);
  }

  @override
  Future<void> removeTask(String taskId, {bool deleteFiles = false}) async {
    // aria2.remove 停止活跃/等待中的任务，返回 GID
    final resultGid = await _call('aria2.remove', ['token:$_secret', taskId]);
    final gidToPurge = resultGid ?? taskId;

    // 清除下载记录；aria2.remove 后任务可能尚未完全进入已停止结果列表，
    // 若立即调用 removeDownloadResult 失败则短暂等待后重试
    final purged =
        await _call('aria2.removeDownloadResult', ['token:$_secret', gidToPurge]);
    if (purged == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _call('aria2.removeDownloadResult', ['token:$_secret', gidToPurge]);
    }
  }

  @override
  Future<DownloaderSpeedConfig> getSpeedConfig() async {
    final result = await _call('aria2.getGlobalOption', ['token:$_secret']);
    if (result is! Map) {
      throw DownloaderServiceException(
        'Aria2 getSpeedConfig 响应异常',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    final dlLimit = int.tryParse(
            result['max-overall-download-limit']?.toString() ?? '0') ??
        0;
    final ulLimit = int.tryParse(
            result['max-overall-upload-limit']?.toString() ?? '0') ??
        0;
    return DownloaderSpeedConfig(
      speedLimitModeEnabled: dlLimit > 0 || ulLimit > 0,
      downloadLimitKB: dlLimit ~/ 1024,
      uploadLimitKB: ulLimit ~/ 1024,
    );
  }

  @override
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config) async {
    final dlBytes = config.speedLimitModeEnabled
        ? (config.downloadLimitKB * 1024).toString()
        : '0';
    final ulBytes = config.speedLimitModeEnabled
        ? (config.uploadLimitKB * 1024).toString()
        : '0';
    await _call('aria2.changeGlobalOption', [
      'token:$_secret',
      {
        'max-overall-download-limit': dlBytes,
        'max-overall-upload-limit': ulBytes,
      },
    ]);
    return true;
  }

  Future<dynamic> _call(String method, [List? params]) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_rpcUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': method,
              'params': params ?? ['token:$_secret'],
              'id': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      // 网络 I/O 异常（SocketException/Timeout）转换为服务异常抛出
      throw DownloaderServiceException(
        'Aria2 $method 网络错误: $e',
        category: DownloaderServiceErrorCategory.network,
      );
    }

    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'Aria2 $method: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }

    // Aria2 RPC 响应头不含 charset=utf-8，Dart http 包会默认以
    // Latin-1 解码 response.body，导致中文乱码。
    // 显式使用 UTF-8 解码 bodyBytes 解决此问题。
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data['error'] != null) {
      throw DownloaderServiceException(
        'Aria2 $method: ${data['error']}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    return data['result'];
  }

  @override
  Future<DownloadTask?> getTaskDetail(String taskId) async {
    final result = await _call('aria2.tellStatus', [
      'token:$_secret',
      taskId,
      [
        'gid',
        'name',
        'totalLength',
        'completedLength',
        'downloadSpeed',
        'uploadSpeed',
        'files',
        'numSeeders',
        'connections',
        'status',
        'dir',
        'bittorrent',
        'bitfield',
        'numPieces',
      ],
    ]);

    if (result == null) return null;
    final status = _parseAria2Status(result['status']);
    return _parseTask(result, status);
  }

  DownloadTask _parseTask(Map json, TaskStatus defaultStatus) {
    final files = json['files'] as List?;
    String name = (json['name']?.toString().trim() ?? '');
    final bt = json['bittorrent'];

    // 使用 dir 字段作为保存路径（Aria2 tellStatus 返回）
    final savePath = json['dir']?.toString() ?? '';

    if (bt is Map && bt['info'] is Map) {
      final btName = (bt['info']['name']?.toString().trim() ?? '');
      if (btName.isNotEmpty) {
        name = btName;
      }
    }

    if (files != null && files.isNotEmpty) {
      final file = files.first as Map?;
      final path = file?['path'];
      if (path != null) {
        if (name.isEmpty) {
          name = _basenameFromPath(path.toString());
        }
      }
    }

    if (name.isEmpty) {
      name = 'Unknown';
    }

    final totalSize = int.tryParse(json['totalLength']?.toString() ?? '0') ?? 0;
    final downloaded =
        int.tryParse(json['completedLength']?.toString() ?? '0') ?? 0;
    final downloadSpeed =
        int.tryParse(json['downloadSpeed']?.toString() ?? '0') ?? 0;
    final uploadSpeed =
        int.tryParse(json['uploadSpeed']?.toString() ?? '0') ?? 0;

    final status = _normalizeStatus(
      defaultStatus,
      hasBt: bt is Map,
      totalSize: totalSize,
      downloaded: downloaded,
      uploadSpeed: uploadSpeed,
    );

    // 计算健康度：bitfield 中已下载 piece 数 / 总 piece 数
    final numPieces = int.tryParse(json['numPieces']?.toString() ?? '0') ?? 0;
    double? healthPercent;
    final bitfield = json['bitfield']?.toString();
    if (bitfield != null && bitfield.isNotEmpty && numPieces > 0) {
      int piecesHave = 0;
      for (var i = 0; i < bitfield.length; i++) {
        final byte = int.tryParse(bitfield[i], radix: 16) ?? 0;
        // 每个 hex 字符 4 bits
        piecesHave += (byte & 8) >> 3;
        piecesHave += (byte & 4) >> 2;
        piecesHave += (byte & 2) >> 1;
        piecesHave += byte & 1;
      }
      healthPercent = piecesHave / numPieces;
    }

    return DownloadTask(
      id: json['gid'] ?? '',
      gid: json['gid'] ?? '',
      name: name,
      totalSize: totalSize,
      downloaded: downloaded,
      progress: _calcProgress(
        json['completedLength']?.toString() ?? '0',
        json['totalLength']?.toString() ?? '0',
      ),
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      status: status,
      savePath: savePath,
      downloaderId: downloader.id,
      seeders: _toIntOrNull(json['numSeeders']),
      connections: json['connections'] != null
          ? int.tryParse(json['connections'].toString())
          : null,
      tracker: _parseTracker(json['bittorrent']),
      fileCount: files?.length,
      healthPercent: healthPercent,
    );
  }

  /// 从 bittorrent 字段解析主 Tracker URL
  String? _parseTracker(dynamic bittorrent) {
    if (bittorrent == null) return null;
    if (bittorrent is Map) {
      final announce = bittorrent['announce'];
      if (announce != null && announce.toString().isNotEmpty) {
        return announce.toString();
      }
      final announceList = bittorrent['announceList'];
      if (announceList is List && announceList.isNotEmpty) {
        final first = announceList.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
        return first.toString();
      }
    }
    return null;
  }

  double _calcProgress(String completed, String total) {
    final c = int.tryParse(completed) ?? 0;
    final t = int.tryParse(total) ?? 0;
    if (t == 0) return 0;
    return c / t;
  }

  int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  TaskStatus _normalizeStatus(
    TaskStatus base, {
    required bool hasBt,
    required int totalSize,
    required int downloaded,
    required int uploadSpeed,
  }) {
    if (!hasBt) return base;
    if (base != TaskStatus.downloading) return base;
    if (totalSize <= 0) return base;
    if (downloaded < totalSize) return base;
    if (uploadSpeed <= 0) return base;
    return TaskStatus.seeding;
  }

  String _basenameFromPath(String fullPath) {
    if (fullPath.isEmpty) return '';
    final normalized = fullPath.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    if (idx < 0 || idx == normalized.length - 1) return normalized;
    return normalized.substring(idx + 1);
  }

  TaskStatus _parseAria2Status(String? status) {
    switch (status) {
      case 'active':
        return TaskStatus.downloading;
      case 'waiting':
        return TaskStatus.waiting;
      case 'complete':
        return TaskStatus.completed;
      case 'paused':
        return TaskStatus.paused;
      case 'error':
        return TaskStatus.error;
      case 'removed':
        return TaskStatus.removed;
      default:
        return TaskStatus.unknown;
    }
  }

  @override
  SpeedConfigDescriptor getSpeedConfigDescriptor() {
    return const SpeedConfigDescriptor(
      sections: [
        ConfigSection(
          title: '速度限制模式',
          fields: [
            ConfigField(
              key: 'speedLimitModeEnabled',
              label: '速度限制模式',
              type: ConfigFieldType.toggle,
            ),
          ],
        ),
        ConfigSection(
          title: '限速设置',
          enabledBy: 'speedLimitModeEnabled',
          fields: [
            ConfigField(
              key: 'downloadLimitKB',
              label: '下载限速',
              type: ConfigFieldType.kbps,
            ),
            ConfigField(
              key: 'uploadLimitKB',
              label: '上传限速',
              type: ConfigFieldType.kbps,
            ),
          ],
        ),
      ],
    );
  }

  /// 获取任务的文件列表。
  Future<List<Aria2TaskFile>> getTaskFiles(String taskId) async {
    final result = await _call('aria2.getFiles', ['token:$_secret', taskId]);
    if (result is! List) return const [];
    return result
        .whereType<Map<String, dynamic>>()
        .map(Aria2TaskFile.fromJson)
        .toList();
  }

  /// 获取任务的文件列表（原始 JSON）。
  ///
  /// 用于构建目录树，返回原始 Map 列表。
  Future<List<Map<String, dynamic>>> getTaskFilesRaw(String taskId) async {
    final result = await _call('aria2.getFiles', ['token:$_secret', taskId]);
    if (result is! List) return const [];
    return result.whereType<Map<String, dynamic>>().toList();
  }

  /// 获取任务的节点（Peer）列表。
  Future<List<Aria2TaskPeer>> getTaskPeers(String taskId) async {
    final result = await _call('aria2.getPeers', ['token:$_secret', taskId]);
    if (result is! List) return const [];
    return result
        .whereType<Map<String, dynamic>>()
        .map(Aria2TaskPeer.fromJson)
        .toList();
  }

  /// 获取任务的服务器/Tracker 列表。
  ///
  /// 从 `aria2.tellStatus` 的 `bittorrent.announceList` 提取，
  /// 而非 `aria2.getServers`（后者仅返回当前连接的 HTTP/FTP 源）。
  Future<List<String>> getTaskTrackers(String taskId) async {
    final result = await _call('aria2.tellStatus', [
      'token:$_secret',
      taskId,
      ['bittorrent'],
    ]);
    if (result is! Map) return const [];
    final bt = result['bittorrent'];
    if (bt is! Map) return const [];
    final announceList = bt['announceList'];
    if (announceList is! List) return const [];
    final trackers = <String>[];
    for (final entry in announceList) {
      if (entry is List && entry.isNotEmpty) {
        final url = entry.first?.toString();
        if (url != null && url.isNotEmpty) trackers.add(url);
      }
    }
    return trackers;
  }

  /// 获取任务选项。
  Future<Aria2TaskOptions> getTaskOptions(String taskId) async {
    final result =
        await _call('aria2.getOption', ['token:$_secret', taskId]);
    if (result is! Map<String, dynamic>) {
      return const Aria2TaskOptions(options: {});
    }
    return Aria2TaskOptions.fromJson(result);
  }

  /// 更新任务选项。
  Future<void> updateTaskOptions(
      String taskId, Map<String, String> options) async {
    await _call('aria2.changeOption', ['token:$_secret', taskId, options]);
  }
}
