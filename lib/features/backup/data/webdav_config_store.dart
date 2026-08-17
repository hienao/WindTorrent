import 'package:get_storage/get_storage.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';

class WebDavConfigStore {
  WebDavConfigStore({GetStorage? storage}) : _storage = storage ?? GetStorage();

  static const _configKey = 'webdav_backup_config';

  final GetStorage _storage;

  WebDavConfig? readConfig() {
    final raw = _storage.read(_configKey);
    if (raw is! Map) {
      return null;
    }
    return WebDavConfig.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> saveConfig(WebDavConfig config) {
    return _storage.write(_configKey, config.toJson());
  }

  Future<void> clear() {
    return _storage.remove(_configKey);
  }
}
