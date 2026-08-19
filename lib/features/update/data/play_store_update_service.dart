import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/data/update_service.dart';

class PlayUpdateSnapshot {
  const PlayUpdateSnapshot({
    required this.isUpdateAvailable,
    required this.availableVersionCode,
  });

  final bool isUpdateAvailable;
  final int? availableVersionCode;
}

/// Google Play 商店的固定 installer store 标识（Android 官方约定值）。
const String googlePlayInstallerStore = 'com.android.vending';

/// 判断应用是否从 Google Play 商店安装。
///
/// 抽成纯函数以便单测覆盖 installer 判定（`_defaultIsSupportedBuild`
/// 仅依赖平台与 installer，不依赖 `kDebugMode`，可在 `flutter test` 下断言）。
bool isInstalledFromGooglePlay(PackageInfo packageInfo) =>
    packageInfo.installerStore == googlePlayInstallerStore;

typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef PlayUpdateCheck = Future<PlayUpdateSnapshot> Function();
typedef SupportedBuildCheck = bool Function(PackageInfo packageInfo);
typedef OpenStoreListing = Future<void> Function();

class PlayStoreUpdateService implements UpdateService {
  PlayStoreUpdateService({
    PackageInfoLoader? packageInfoLoader,
    PlayUpdateCheck? checkForUpdate,
    SupportedBuildCheck? isSupportedBuild,
    OpenStoreListing? openStoreListing,
  }) : _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _checkForUpdate = checkForUpdate ?? _defaultCheckForUpdate,
       _isSupportedBuild = isSupportedBuild ?? _defaultIsSupportedBuild,
       _openStoreListing =
           openStoreListing ?? InAppReview.instance.openStoreListing;

  final PackageInfoLoader _packageInfoLoader;
  final PlayUpdateCheck _checkForUpdate;
  final SupportedBuildCheck _isSupportedBuild;
  final OpenStoreListing _openStoreListing;

  @override
  UpdateSource get source => UpdateSource.playStore;

  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    final packageInfo = await _packageInfoLoader();

    if (!_isSupportedBuild(packageInfo)) {
      return const UpdateCheckResult.unsupported();
    }

    try {
      final snapshot = await _checkForUpdate();
      if (!snapshot.isUpdateAvailable ||
          snapshot.availableVersionCode == null) {
        return const UpdateCheckResult.upToDate();
      }
      return UpdateCheckResult.available(snapshot.availableVersionCode!);
    } catch (e, st) {
      Log.e('Play update check failed', error: e, stackTrace: st);
      return const UpdateCheckResult.unknown();
    }
  }

  @override
  Future<void> openUpdatePage(UpdateCheckResult result) {
    return _openStoreListing();
  }

  static bool _defaultIsSupportedBuild(PackageInfo packageInfo) {
    return defaultTargetPlatform == TargetPlatform.android &&
        isInstalledFromGooglePlay(packageInfo);
  }

  static Future<PlayUpdateSnapshot> _defaultCheckForUpdate() async {
    final info = await InAppUpdate.checkForUpdate();
    return PlayUpdateSnapshot(
      isUpdateAvailable:
          info.updateAvailability == UpdateAvailability.updateAvailable,
      availableVersionCode: info.availableVersionCode,
    );
  }
}
