import '../core/constants/app_constants.dart';

/// 下载器模型
class Downloader {
  final String id;
  final String name;
  final DownloaderType type;
  final String host;
  final int port;
  final String? secret; // Aria2 RPC 密钥
  final String? username; // qBit/Trans 用户名
  final String? password; // qBit/Trans 密码
  final bool useHttps; // 是否使用 HTTPS
  DownloaderStatus status;
  int taskCount;
  int downloadSpeed;
  int uploadSpeed;
  Map<String, int> taskStats;
  final String? version; // 服务端版本号（添加/编辑时获取）

  Downloader({
    required this.id,
    required this.name,
    required this.type,
    required this.host,
    required this.port,
    this.secret,
    this.username,
    this.password,
    this.useHttps = false,
    this.status = DownloaderStatus.offline,
    this.taskCount = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.taskStats = const {},
    this.version,
  });

  /// 获取 RPC 地址
  String get rpcUrl {
    final protocol = useHttps ? 'https' : 'http';
    switch (type) {
      case DownloaderType.aria2:
        return '$protocol://$host:$port/jsonrpc';
      case DownloaderType.qbittorrent:
        return '$protocol://$host:$port';
      case DownloaderType.transmission:
        return '$protocol://$host:$port/transmission/rpc';
    }
  }

  /// 从 JSON 创建
  factory Downloader.fromJson(Map<String, dynamic> json) {
    return Downloader(
      id: json['id'],
      name: json['name'],
      type: DownloaderType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DownloaderType.aria2,
      ),
      host: json['host'],
      port: _parsePort(json['port']),
      secret: json['secret'],
      username: json['username'],
      password: json['password'],
      useHttps: json['useHttps'] ?? false,
      status: DownloaderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloaderStatus.offline,
      ),
      version: json['version'] as String?,
    );
  }

  /// 解析 port 字段（fail-fast：缺失或类型错则抛出）
  static int _parsePort(dynamic value) {
    if (value == null) {
      throw FormatException('Downloader.fromJson: port 字段缺失');
    }
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    if (parsed == null) {
      throw FormatException('Downloader.fromJson: port 字段类型错误: $value');
    }
    return parsed;
  }

  /// 转为 JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'host': host,
    'port': port,
    'secret': secret,
    'username': username,
    'password': password,
    'useHttps': useHttps,
    'version': version,
  };

  Downloader copyWith({
    String? id,
    String? name,
    DownloaderType? type,
    String? host,
    int? port,
    String? secret,
    String? username,
    String? password,
    bool? useHttps,
    DownloaderStatus? status,
    int? taskCount,
    int? downloadSpeed,
    int? uploadSpeed,
    Map<String, int>? taskStats,
    String? version,
  }) {
    return Downloader(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      secret: secret ?? this.secret,
      username: username ?? this.username,
      password: password ?? this.password,
      useHttps: useHttps ?? this.useHttps,
      status: status ?? this.status,
      taskCount: taskCount ?? this.taskCount,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      taskStats: taskStats ?? this.taskStats,
      version: version ?? this.version,
    );
  }
}
