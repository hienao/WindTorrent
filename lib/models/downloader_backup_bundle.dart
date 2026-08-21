import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';

class DownloaderBackupBundle {
  const DownloaderBackupBundle({
    required this.schemaVersion,
    required this.backupId,
    required this.createdAt,
    required this.appVersion,
    required this.downloaders,
  });

  final int schemaVersion;
  final String backupId;
  final DateTime createdAt;
  final String appVersion;
  final List<Downloader> downloaders;

  static const supportedSchemaVersion = 1;

  factory DownloaderBackupBundle.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int) {
      throw const FormatException('schemaVersion must be an integer');
    }
    if (schemaVersion != supportedSchemaVersion) {
      throw FormatException('Unsupported schemaVersion: $schemaVersion');
    }

    final backupId = _requiredNonEmptyString(json, 'backupId');
    final createdAtText = _requiredNonEmptyString(json, 'createdAt');
    final createdAt = DateTime.tryParse(createdAtText);
    if (createdAt == null) {
      throw const FormatException('createdAt must be an ISO-8601 timestamp');
    }
    final appVersion = _requiredNonEmptyString(json, 'appVersion');
    final rawDownloaders = json['downloaders'];
    if (rawDownloaders is! List<dynamic>) {
      throw const FormatException('downloaders must be a list');
    }

    final ids = <String>{};
    final downloaders = <Downloader>[];
    for (var index = 0; index < rawDownloaders.length; index++) {
      final downloader = _parseDownloader(rawDownloaders[index], index);
      if (!ids.add(downloader.id)) {
        throw FormatException('Duplicate downloader id: ${downloader.id}');
      }
      downloaders.add(downloader);
    }

    return DownloaderBackupBundle(
      schemaVersion: schemaVersion,
      backupId: backupId,
      createdAt: createdAt,
      appVersion: appVersion,
      downloaders: downloaders,
    );
  }

  static Downloader _parseDownloader(Object? value, int index) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('downloaders[$index] must be an object');
    }

    final id = _requiredNonEmptyString(
      value,
      'id',
      prefix: 'downloaders[$index]',
    );
    final name = _requiredNonEmptyString(
      value,
      'name',
      prefix: 'downloaders[$index]',
    );
    final host = _requiredNonEmptyString(
      value,
      'host',
      prefix: 'downloaders[$index]',
    );
    final rawType = _requiredNonEmptyString(
      value,
      'type',
      prefix: 'downloaders[$index]',
    );
    final type = DownloaderType.values
        .where((candidate) => candidate.name == rawType)
        .firstOrNull;
    if (type == null) {
      throw FormatException('downloaders[$index].type is not supported');
    }

    final port = value['port'];
    if (port is! int || port < 1 || port > 65535) {
      throw FormatException(
        'downloaders[$index].port must be an integer between 1 and 65535',
      );
    }
    final useHttps = value['useHttps'];
    if (useHttps is! bool) {
      throw FormatException('downloaders[$index].useHttps must be a boolean');
    }

    return Downloader(
      id: id,
      name: name,
      type: type,
      host: host,
      port: port,
      secret: _optionalString(value, 'secret', index),
      username: _optionalString(value, 'username', index),
      password: _optionalString(value, 'password', index),
      useHttps: useHttps,
      version: _optionalString(value, 'version', index),
    );
  }

  static String _requiredNonEmptyString(
    Map<String, dynamic> json,
    String key, {
    String? prefix,
  }) {
    final value = json[key];
    final field = prefix == null ? key : '$prefix.$key';
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a non-empty string');
    }
    return value;
  }

  static String? _optionalString(
    Map<String, dynamic> json,
    String key,
    int index,
  ) {
    final value = json[key];
    if (value != null && value is! String) {
      throw FormatException(
        'downloaders[$index].$key must be a string or null',
      );
    }
    return value as String?;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'backupId': backupId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'downloaders': downloaders.map((d) => d.toJson()).toList(),
  };
}
