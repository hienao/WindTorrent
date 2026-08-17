import 'package:windwalker/services/qbit/qbit_api_generation.dart';
import 'package:windwalker/services/qbit/qbit_server_profile.dart';
import 'package:windwalker/services/qbit/qbit_session.dart';

/// 通过 `app/version` 与 `app/webapiVersion` 探测 qBittorrent 服务端代际。
///
/// 版本不可解析 → [FormatException]；低于 4.1 → [UnsupportedError]。
/// 两者均由上层 [QBitService.testConnection] 捕获并转换为
/// [ConnectionFailure]。
class QBitVersionDetector {
  final QBitSession session;

  QBitVersionDetector(this.session);

  Future<QBitServerProfile> detect() async {
    await session.login();
    final rawAppVersion = await session.getText('/api/v2/app/version');
    final rawWebApiVersion =
        await session.getText('/api/v2/app/webapiVersion');

    final appVersion = _stripVersion(rawAppVersion);
    final webApiVersion = rawWebApiVersion.trim();
    final parts = appVersion.split('.');
    final major = int.tryParse(parts.first);
    if (major == null) {
      throw FormatException('Invalid qBittorrent app version: $rawAppVersion');
    }
    final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    if (major < 4 || (major == 4 && minor < 1)) {
      throw UnsupportedError('Unsupported qBittorrent version: $appVersion');
    }

    return QBitServerProfile(
      appVersion: appVersion,
      webApiVersion: webApiVersion,
      apiGeneration: major >= 5
          ? QBitApiGeneration.v5Modern
          : QBitApiGeneration.v4Legacy,
      rawAppVersion: rawAppVersion,
      rawWebApiVersion: rawWebApiVersion,
    );
  }

  /// 去除版本号前导非数字字符（如 `v4.5.2` → `4.5.2`）。
  /// 不含任何数字时抛 [FormatException]。
  String _stripVersion(String raw) {
    final normalized = raw.trim().replaceFirst(RegExp(r'^[^0-9]+'), '');
    if (normalized.isEmpty) {
      throw FormatException('Empty qBittorrent version: $raw');
    }
    return normalized;
  }
}
