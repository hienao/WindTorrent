import 'package:flutter/foundation.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/backup/data/backup_exceptions.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/services/downloader_backup_service.dart';

class SettingsBackupController extends ChangeNotifier {
  DownloaderBackupService? _backupService;
  DownloaderController? _downloaderController;

  bool _isExporting = false;
  bool _isImporting = false;
  String? _errorMessage;
  String? _lastOperationSummary;

  bool get isExporting => _isExporting;
  bool get isImporting => _isImporting;
  String? get errorMessage => _errorMessage;
  String? get lastOperationSummary => _lastOperationSummary;
  bool get canUndoLastRestore =>
      _downloaderController?.hasRollbackSnapshot ?? false;

  void attach({
    required DownloaderBackupService backupService,
    required DownloaderController downloaderController,
  }) {
    _backupService = backupService;
    _downloaderController = downloaderController;
  }

  Future<void> exportBackup() async {
    final service = _requireBackupService();
    _isExporting = true;
    _errorMessage = null;
    _lastOperationSummary = null;
    notifyListeners();

    try {
      final saved = await service.exportBackup();
      if (saved) {
        _lastOperationSummary = '配置备份已导出';
      }
    } catch (e, st) {
      _errorMessage = '导出配置备份失败，请重试';
      Log.e('exportBackup failed', error: e, stackTrace: st);
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> importBackup() async {
    final service = _requireBackupService();
    _isImporting = true;
    _errorMessage = null;
    _lastOperationSummary = null;
    notifyListeners();

    try {
      final bundle = await service.importBackup();
      if (bundle != null) {
        _lastOperationSummary = '已导入 ${bundle.downloaders.length} 个下载器配置';
      }
    } on BackupException catch (e, st) {
      _errorMessage = _messageForBackupException(e);
      Log.e('importBackup failed', error: e, stackTrace: st);
    } catch (e, st) {
      _errorMessage = '导入配置备份失败，请重试';
      Log.e('importBackup failed', error: e, stackTrace: st);
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> undoLastRestore() async {
    final controller = _downloaderController;
    if (controller == null) {
      throw StateError('SettingsBackupController is not attached');
    }

    _errorMessage = null;
    _lastOperationSummary = null;
    notifyListeners();

    try {
      final restored = await controller.restoreRollbackSnapshot();
      _lastOperationSummary = restored ? '已撤销导入' : '无可撤销的配置快照';
    } catch (e, st) {
      _errorMessage = '撤销导入失败，请重试';
      Log.e('undoLastRestore failed', error: e, stackTrace: st);
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  DownloaderBackupService _requireBackupService() {
    final service = _backupService;
    if (service == null) {
      throw StateError('SettingsBackupController is not attached');
    }
    return service;
  }

  String _messageForBackupException(BackupException exception) {
    switch (exception.reason) {
      case BackupFailureReason.parseFailed:
        return '所选文件不是有效的 WindTorrent 配置备份';
      case BackupFailureReason.fileAccess:
        return '无法读取所选文件';
      case BackupFailureReason.unknown:
        return '导入配置备份失败，请重试';
    }
  }
}
