import 'dart:convert';

import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/backup/data/backup_storage_api.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/models/downloader_backup_version.dart';
import 'package:windwalker/services/analytics_service.dart';

/// 备份编排服务：导出下载器配置到云端、从云端恢复。
class DownloaderBackupService {
  DownloaderBackupService({
    required BackupStorageApi storageApi,
    required DownloaderController downloaderController,
    required Future<String> Function() currentAppVersion,
  }) : _storageApi = storageApi,
       _downloaderController = downloaderController,
       _currentAppVersion = currentAppVersion;

  final BackupStorageApi _storageApi;
  final DownloaderController _downloaderController;
  final Future<String> Function() _currentAppVersion;

  /// 埋点入口（子类可覆盖以便测试注入）。
  AnalyticsService get analyticsService => AnalyticsService.instance;

  /// 导出当前下载器配置到远端存储。
  ///
  /// 上传前删除旧版本，保留最新两个。
  Future<void> exportBackup() async {
    final now = DateTime.now().toUtc();
    final bundle = DownloaderBackupBundle(
      schemaVersion: DownloaderBackupBundle.supportedSchemaVersion,
      backupId: _buildBackupId(now),
      createdAt: now,
      appVersion: await _currentAppVersion(),
      downloaders: _downloaderController.downloaders,
    );

    final versionsBefore = await _storageApi.listVersions();

    try {
      // 先上传新版本，再删除旧版本——避免上传失败时丢失所有备份。
      await _storageApi.uploadBackup(bundle);
      final versionsAfter = await _storageApi.listVersions();
      for (final version in pickFilesToDeleteBeforeUpload(versionsAfter)) {
        await _storageApi.deleteBackup(version.fileId);
      }

      Log.i(
        'Backup exported: backupId=${bundle.backupId}, '
        'downloaderCount=${bundle.downloaders.length}',
      );

      await analyticsService.track(
        'downloader_backup_export_result',
        params: <String, Object>{
          'result': 'success',
          'downloader_count': bundle.downloaders.length,
          'cloud_version_count_before': versionsBefore.length,
          'cloud_version_count_after': versionsAfter.length >= 2
              ? 2
              : versionsAfter.length,
        },
      );
    } catch (e) {
      await analyticsService.track(
        'downloader_backup_export_result',
        params: <String, Object>{'result': 'failure'},
      );
      rethrow;
    }
  }

  /// 从远端恢复备份。
  ///
  /// 下载备份 JSON，解析后原子替换当前下载器列表。
  Future<void> restoreBackup({required String fileId}) async {
    try {
      final bytes = await _storageApi.downloadBackup(fileId);
      final bundle = DownloaderBackupBundle.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
      await _downloaderController.replaceAllDownloadersFromBackup(
        downloaders: bundle.downloaders,
        sourceBackupId: bundle.backupId,
      );

      Log.i(
        'Backup restored: backupId=${bundle.backupId}, '
        'downloaderCount=${bundle.downloaders.length}',
      );

      await analyticsService.track(
        'downloader_backup_import_result',
        params: <String, Object>{
          'result': 'success',
          'downloader_count': bundle.downloaders.length,
        },
      );
    } catch (e) {
      await analyticsService.track(
        'downloader_backup_import_result',
        params: <String, Object>{'result': 'failure'},
      );
      rethrow;
    }
  }

  /// 列出远端存储中的所有备份版本。
  Future<List<DownloaderBackupVersion>> listVersions() {
    return _storageApi.listVersions();
  }

  Future<void> deleteBackup({required String fileId}) {
    return _storageApi.deleteBackup(fileId);
  }

  Future<void> testConnection() {
    return _storageApi.testConnection();
  }

  /// 生成备份 ID：ISO 时间戳 + 5 位随机后缀。
  static String _buildBackupId(DateTime now) {
    final iso = now.toUtc().toIso8601String().replaceAll(':', '');
    // 简单随机后缀，足够用于去重
    final suffix = (now.microsecondsSinceEpoch % 100000).toString().padLeft(
      5,
      '0',
    );
    return '${iso}_$suffix';
  }

  /// 返回上传前应删除的旧版本列表（保留最新两个）。
  static List<DownloaderBackupVersion> pickFilesToDeleteBeforeUpload(
    List<DownloaderBackupVersion> versions,
  ) {
    final sorted = List<DownloaderBackupVersion>.from(versions)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.length < 3) return const [];
    return sorted.take(sorted.length - 2).toList();
  }
}
