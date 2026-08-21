import 'dart:convert';
import 'dart:typed_data';

import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/backup/data/backup_exceptions.dart';
import 'package:windwalker/features/backup/data/backup_file_api.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/services/analytics_service.dart';

/// Creates and restores local JSON backups selected through the system picker.
class DownloaderBackupService {
  DownloaderBackupService({
    required BackupFileApi fileApi,
    required DownloaderController downloaderController,
    required Future<String> Function() currentAppVersion,
  }) : _fileApi = fileApi,
       _downloaderController = downloaderController,
       _currentAppVersion = currentAppVersion;

  static const maxBackupFileBytes = 5 * 1024 * 1024;

  final BackupFileApi _fileApi;
  final DownloaderController _downloaderController;
  final Future<String> Function() _currentAppVersion;

  AnalyticsService get analyticsService => AnalyticsService.instance;

  /// Opens the system save dialog and writes the current configuration as JSON.
  /// Returns false when the user cancels the dialog.
  Future<bool> exportBackup() async {
    final now = DateTime.now().toUtc();
    final bundle = DownloaderBackupBundle(
      schemaVersion: DownloaderBackupBundle.supportedSchemaVersion,
      backupId: _buildBackupId(now),
      createdAt: now,
      appVersion: await _currentAppVersion(),
      downloaders: _downloaderController.downloaders,
    );
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(bundle.toJson())),
    );

    try {
      final saved = await _fileApi.saveBackup(
        fileName: _buildBackupFileName(now),
        bytes: bytes,
      );
      if (!saved) {
        return false;
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
        },
      );
      return true;
    } catch (e) {
      await analyticsService.track(
        'downloader_backup_export_result',
        params: <String, Object>{'result': 'failure'},
      );
      rethrow;
    }
  }

  /// Opens the system file picker, validates the selected JSON completely, and
  /// only then replaces the current downloader configuration.
  /// Returns null when the user cancels the picker.
  Future<DownloaderBackupBundle?> importBackup() async {
    try {
      final picked = await _fileApi.pickBackup();
      if (picked == null) {
        return null;
      }
      final bundle = decodeAndValidate(picked.bytes);
      await _downloaderController.replaceAllDownloadersFromBackup(
        downloaders: bundle.downloaders,
        sourceBackupId: bundle.backupId,
      );

      Log.i(
        'Backup imported: backupId=${bundle.backupId}, '
        'downloaderCount=${bundle.downloaders.length}',
      );
      await analyticsService.track(
        'downloader_backup_import_result',
        params: <String, Object>{
          'result': 'success',
          'downloader_count': bundle.downloaders.length,
        },
      );
      return bundle;
    } on BackupException {
      await _trackImportFailure();
      rethrow;
    } on FormatException catch (e) {
      await _trackImportFailure();
      throw BackupException(
        reason: BackupFailureReason.parseFailed,
        message: e.message,
      );
    } catch (e) {
      await _trackImportFailure();
      rethrow;
    }
  }

  /// Parses and validates an imported backup without mutating app state.
  static DownloaderBackupBundle decodeAndValidate(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const BackupException(
        reason: BackupFailureReason.parseFailed,
        message: 'The file is empty',
      );
    }
    if (bytes.length > maxBackupFileBytes) {
      throw const BackupException(
        reason: BackupFailureReason.parseFailed,
        message: 'The file exceeds the 5 MB limit',
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('The JSON root must be an object');
      }
      return DownloaderBackupBundle.fromJson(decoded);
    } on BackupException {
      rethrow;
    } on FormatException catch (e) {
      throw BackupException(
        reason: BackupFailureReason.parseFailed,
        message: e.message,
      );
    }
  }

  Future<void> _trackImportFailure() {
    return analyticsService.track(
      'downloader_backup_import_result',
      params: <String, Object>{'result': 'failure'},
    );
  }

  static String _buildBackupId(DateTime now) {
    final iso = now.toUtc().toIso8601String().replaceAll(':', '');
    final suffix = (now.microsecondsSinceEpoch % 100000).toString().padLeft(
      5,
      '0',
    );
    return '${iso}_$suffix';
  }

  static String _buildBackupFileName(DateTime createdAtUtc) {
    final stamp = createdAtUtc
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.000', '');
    return 'windtorrent-config-$stamp.json';
  }
}
