import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/backup/data/backup_exceptions.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';
import 'package:windwalker/features/backup/data/webdav_config_store.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/models/downloader_backup_version.dart';
import 'package:windwalker/services/downloader_backup_service.dart';

class SettingsBackupController extends ChangeNotifier {
  SettingsBackupController({
    http.Client? httpClient,
    WebDavConfigStore? configStore,
  }) : _httpClient = httpClient ?? http.Client(),
       _configStore = configStore ?? WebDavConfigStore();

  final http.Client _httpClient;
  final WebDavConfigStore _configStore;

  http.Client get httpClient => _httpClient;

  DownloaderBackupService? _backupService;
  DownloaderController? _downloaderController;
  WebDavConfig? _config;

  bool _isExporting = false;
  bool _isImporting = false;
  bool _isLoadingVersions = false;
  bool _isSavingConfig = false;
  bool _isTestingConfig = false;
  bool _isDeletingBackup = false;
  String? _errorMessage;
  String? _lastOperationSummary;
  List<DownloaderBackupVersion> _availableBackups = const [];

  bool get isExporting => _isExporting;
  bool get isImporting => _isImporting;
  bool get isLoadingVersions => _isLoadingVersions;
  bool get isSavingConfig => _isSavingConfig;
  bool get isTestingConfig => _isTestingConfig;
  bool get isDeletingBackup => _isDeletingBackup;
  String? get errorMessage => _errorMessage;
  String? get lastOperationSummary => _lastOperationSummary;
  List<DownloaderBackupVersion> get availableBackups => _availableBackups;
  WebDavConfig? get config => _config;
  bool get hasConfig => _config != null;
  bool get canUndoLastRestore =>
      _downloaderController?.hasRollbackSnapshot ?? false;
  bool get canUseBackup => hasConfig;
  String? get configSummary => _config?.maskedSummary;

  WebDavConfig? readConfig() => _config;

  void attach({
    required DownloaderBackupService backupService,
    required DownloaderController downloaderController,
  }) {
    _backupService = backupService;
    _downloaderController = downloaderController;
  }

  void loadConfig() {
    final next = _configStore.readConfig();
    if (next?.toJson().toString() == _config?.toJson().toString()) {
      return;
    }
    _config = next;
    notifyListeners();
  }

  Future<void> saveConfig(WebDavConfig config) async {
    _isSavingConfig = true;
    _errorMessage = null;
    _lastOperationSummary = null;
    notifyListeners();

    try {
      await _configStore.saveConfig(config);
      _config = config;
      _lastOperationSummary = 'WebDAV 配置已保存';
    } catch (e, st) {
      _errorMessage = '保存 WebDAV 配置失败: $e';
      Log.e('saveConfig failed', error: e, stackTrace: st);
    } finally {
      _isSavingConfig = false;
      notifyListeners();
    }
  }

  Future<void> testConnection(WebDavConfig draftConfig) async {
    final service = _backupService;
    if (service == null) {
      _errorMessage = '备份服务未初始化';
      notifyListeners();
      return;
    }

    final previous = _config;
    _isTestingConfig = true;
    _errorMessage = null;
    _lastOperationSummary = null;
    _config = draftConfig;
    notifyListeners();

    try {
      await service.testConnection();
      _lastOperationSummary = 'WebDAV 连接正常';
    } on BackupException catch (e, st) {
      _errorMessage = _messageForBackupException(e);
      Log.e('testConnection failed', error: e, stackTrace: st);
    } catch (e, st) {
      _errorMessage = '测试 WebDAV 连接失败: $e';
      Log.e('testConnection failed', error: e, stackTrace: st);
    } finally {
      _config = previous;
      _isTestingConfig = false;
      notifyListeners();
    }
  }

  Future<void> exportBackup() async {
    final service = _backupService;
    if (service == null) {
      _errorMessage = '备份服务未初始化';
      notifyListeners();
      return;
    }
    if (!hasConfig) {
      _errorMessage = '请先配置 WebDAV';
      notifyListeners();
      return;
    }
    _isExporting = true;
    _errorMessage = null;
    _lastOperationSummary = null;
    notifyListeners();

    try {
      await service.exportBackup();
      _lastOperationSummary = '已备份到 WebDAV';
    } on BackupException catch (e, st) {
      _errorMessage = _messageForBackupException(e);
      Log.e('exportBackup failed', error: e, stackTrace: st);
    } catch (e, st) {
      _errorMessage = '导出失败: $e';
      Log.e('exportBackup failed', error: e, stackTrace: st);
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> loadAvailableBackups() async {
    final service = _backupService;
    if (service == null) {
      _errorMessage = '备份服务未初始化';
      notifyListeners();
      return;
    }
    if (!hasConfig) {
      _errorMessage = '请先配置 WebDAV';
      notifyListeners();
      return;
    }

    _isLoadingVersions = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _availableBackups = await service.listVersions();
    } on BackupException catch (e, st) {
      _availableBackups = const [];
      _errorMessage = _messageForBackupException(e);
      Log.e('loadAvailableBackups failed', error: e, stackTrace: st);
    } catch (e, st) {
      _availableBackups = const [];
      _errorMessage = '加载备份列表失败: $e';
      Log.e('loadAvailableBackups failed', error: e, stackTrace: st);
    } finally {
      _isLoadingVersions = false;
      notifyListeners();
    }
  }

  Future<void> restoreBackup({required String fileId}) async {
    final service = _backupService;
    if (service == null) {
      _errorMessage = '备份服务未初始化';
      notifyListeners();
      return;
    }

    _isImporting = true;
    _errorMessage = null;
    _lastOperationSummary = null;
    notifyListeners();

    try {
      await service.restoreBackup(fileId: fileId);
      _lastOperationSummary = '已从 WebDAV 恢复';
    } on BackupException catch (e, st) {
      _errorMessage = _messageForBackupException(e);
      Log.e('restoreBackup failed', error: e, stackTrace: st);
    } catch (e, st) {
      _errorMessage = '恢复失败: $e';
      Log.e('restoreBackup failed', error: e, stackTrace: st);
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> deleteBackup({required String fileId}) async {
    final service = _backupService;
    if (service == null) {
      _errorMessage = '备份服务未初始化';
      notifyListeners();
      return;
    }

    _isDeletingBackup = true;
    _errorMessage = null;
    _lastOperationSummary = null;
    notifyListeners();

    try {
      await service.deleteBackup(fileId: fileId);
      _availableBackups = _availableBackups
          .where((backup) => backup.fileId != fileId)
          .toList();
      _lastOperationSummary = '已删除备份版本';
    } on BackupException catch (e, st) {
      _errorMessage = _messageForBackupException(e);
      Log.e('deleteBackup failed', error: e, stackTrace: st);
    } catch (e, st) {
      _errorMessage = '删除备份失败: $e';
      Log.e('deleteBackup failed', error: e, stackTrace: st);
    } finally {
      _isDeletingBackup = false;
      notifyListeners();
    }
  }

  Future<void> undoLastRestore() async {
    final controller = _downloaderController;
    if (controller == null) {
      _errorMessage = '控制器未初始化';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _lastOperationSummary = null;
    notifyListeners();

    try {
      final restored = await controller.restoreRollbackSnapshot();
      _lastOperationSummary = restored ? '已撤销恢复' : '无可撤销的快照';
    } catch (e, st) {
      _errorMessage = '撤销失败: $e';
      Log.e('undoLastRestore failed', error: e, stackTrace: st);
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _messageForBackupException(BackupException e) {
    switch (e.reason) {
      case BackupFailureReason.notConfigured:
        return '请先配置 WebDAV';
      case BackupFailureReason.unauthorized:
        return 'WebDAV 用户名或密码错误';
      case BackupFailureReason.network:
        return '无法连接到 WebDAV 服务器';
      case BackupFailureReason.parseFailed:
        return '远端备份文件无法解析';
      case BackupFailureReason.server:
        return 'WebDAV 服务器暂时不可用';
      case BackupFailureReason.unknown:
        return e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : '备份操作失败，请重试';
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}
