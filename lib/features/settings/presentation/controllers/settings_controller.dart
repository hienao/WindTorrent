import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/utils/native_theme_mode_sync.dart';
import 'package:windwalker/services/analytics_service.dart';

/// 支持的语言选项
enum AppLocale {
  system('system'),
  en('en'),
  zh('zh'),
  ja('ja');

  final String code;
  const AppLocale(this.code);

  /// 从存储值解析，未知值回退为 system
  static AppLocale fromCode(String? code) {
    return AppLocale.values.where((e) => e.code == code).firstOrNull ??
        AppLocale.system;
  }
}

/// 主题模式选项（浅色 / 深色 / 跟随系统）
enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  final String code;
  const AppThemeMode(this.code);

  /// 从存储值解析，未知值回退为 system
  static AppThemeMode fromCode(String? code) {
    return AppThemeMode.values.where((e) => e.code == code).firstOrNull ??
        AppThemeMode.system;
  }
}

/// 设置控制器
/// 按照 flutter-managing-state skill 使用 ChangeNotifier
class SettingsController extends ChangeNotifier {
  final GetStorage _storage;

  // 设置项
  AppLocale _appLocale = AppLocale.system;
  AppThemeMode _appThemeMode = AppThemeMode.system;

  SettingsController({GetStorage? storage})
    : _storage = storage ?? GetStorage() {
    _loadSettings();
  }

  // Getters
  AppLocale get appLocale => _appLocale;
  AppThemeMode get appThemeMode => _appThemeMode;

  /// 获取实际生效的 Locale（null 表示跟随系统）
  Locale? get effectiveLocale {
    switch (_appLocale) {
      case AppLocale.system:
        return null;
      case AppLocale.en:
        return const Locale('en');
      case AppLocale.zh:
        return const Locale('zh');
      case AppLocale.ja:
        return const Locale('ja');
    }
  }

  /// 获取实际生效的 Material ThemeMode
  ThemeMode get effectiveThemeMode {
    switch (_appThemeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  void _loadSettings() {
    // main() 已 await GetStorage.init() 完成才创建控制器，此处不会因未初始化失败。
    _appLocale = AppLocale.fromCode(_storage.read('appLocale'));
    _appThemeMode = AppThemeMode.fromCode(_storage.read('appThemeMode'));
    unawaited(NativeThemeModeSync.sync(_appThemeMode.code));
    notifyListeners();

    // 初始化 user_property（App 启动时同步当前偏好状态）
    AnalyticsService.instance.setUserProperty('theme_mode', _appThemeMode.code);
    AnalyticsService.instance.setUserProperty('app_locale', _appLocale.code);
  }

  void setAppLocale(AppLocale value) {
    final from = _appLocale;
    _appLocale = value;
    _storage.write('appLocale', value.code);
    notifyListeners();

    if (from != value) {
      AnalyticsService.instance.track(
        'settings_language_changed',
        params: <String, Object>{'from': from.code, 'to': value.code},
      );
      AnalyticsService.instance.setUserProperty('app_locale', value.code);
    }
  }

  void setAppThemeMode(AppThemeMode value) {
    final from = _appThemeMode;
    _appThemeMode = value;
    _storage.write('appThemeMode', value.code);
    unawaited(NativeThemeModeSync.sync(value.code));
    notifyListeners();

    if (from != value) {
      AnalyticsService.instance.track(
        'settings_theme_mode_changed',
        params: <String, Object>{'from': from.code, 'to': value.code},
      );
      AnalyticsService.instance.setUserProperty('theme_mode', value.code);
    }
  }
}
