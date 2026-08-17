import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/models/downloader_backup_version.dart';

abstract class BackupStorageApi {
  Future<void> testConnection();

  Future<List<DownloaderBackupVersion>> listVersions();

  Future<void> uploadBackup(DownloaderBackupBundle bundle);

  Future<List<int>> downloadBackup(String fileId);

  Future<void> deleteBackup(String fileId);
}
