import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  AppVersion._();

  static Future<PackageInfo>? _cached;

  static Future<PackageInfo> info() {
    return _cached ??= PackageInfo.fromPlatform();
  }

  static Future<String> displayVersion() async {
    final info = await AppVersion.info();
    return 'v${info.version}';
  }
}
