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
    final schemaVersion = json['schemaVersion'] as int;
    if (schemaVersion != supportedSchemaVersion) {
      throw FormatException('Unsupported schemaVersion: $schemaVersion');
    }

    return DownloaderBackupBundle(
      schemaVersion: schemaVersion,
      backupId: json['backupId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      appVersion: json['appVersion'] as String,
      downloaders: (json['downloaders'] as List<dynamic>)
          .map((e) => Downloader.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'backupId': backupId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'downloaders': downloaders.map((d) => d.toJson()).toList(),
  };
}
