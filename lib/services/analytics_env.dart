import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:windwalker/core/utils/log.dart';

/// 环境参数提供者：注入 app_version/platform/locale/network_type 等公共参数。
///
/// 作为独立服务提供环境参数，便于复用与测试。
/// 除 network_type 外的字段缓存复用。
class AnalyticsEnvProvider {
  AnalyticsEnvProvider();

  static const _tag = 'AnalyticsEnv';
  Map<String, Object>? _cached;

  Future<Map<String, Object>> getEnvParams() async {
    final networkType = await _getNetworkType();
    if (_cached != null) {
      return <String, Object>{..._cached!, 'network_type': networkType};
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final locale = ui.PlatformDispatcher.instance.locale;
    final env = <String, Object>{
      'app_version': packageInfo.version,
      'app_build': packageInfo.buildNumber,
      'platform': Platform.operatingSystem,
      'os_version': _shortOsVersion(Platform.operatingSystemVersion),
      'locale': locale.toLanguageTag(),
      'network_type': networkType,
    };

    if (Platform.isAndroid) {
      try {
        final android = await DeviceInfoPlugin().androidInfo;
        env['android_api_level'] = android.version.sdkInt;
        env['android_release'] = android.version.release;
      } catch (e) {
        Log.w('读取 Android 设备信息失败: $e', tag: _tag);
      }
    }

    _cached = env;
    return env;
  }

  Future<String> _getNetworkType() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty) return 'unknown';
      if (results.length > 1) return 'multi';
      return results.first.name;
    } catch (e) {
      Log.w('读取网络类型失败: $e', tag: _tag);
      return 'unknown';
    }
  }

  String _shortOsVersion(String osVersion) {
    if (osVersion.length <= 80) return osVersion;
    return osVersion.substring(0, 80);
  }
}
