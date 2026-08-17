import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:windwalker/features/update/data/play_store_update_service.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

PackageInfo _packageInfo({String? installerStore}) => PackageInfo(
  appName: 'WindTorrent',
  packageName: 'com.windwalker.app',
  version: '0.0.7',
  buildNumber: '2026060702',
  buildSignature: '',
  installerStore: installerStore,
);

Future<void> _withAndroidPlatform(Future<void> Function() body) async {
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

void main() {
  group('PlayStoreUpdateService', () {
    test(
      'unsupported build returns unsupported without calling Play API',
      () async {
        var called = false;
        final service = PlayStoreUpdateService(
          packageInfoLoader: () async =>
              _packageInfo(installerStore: 'com.android.vending'),
          checkForUpdate: () async {
            called = true;
            return const PlayUpdateSnapshot(
              isUpdateAvailable: true,
              availableVersionCode: 2026061501,
            );
          },
          isSupportedBuild: (_) => false,
        );

        final result = await service.checkForUpdate();
        expect(result.status, UpdateCheckStatus.unsupported);
        expect(called, isFalse);
      },
    );

    test('available update returns available with version code', () async {
      final service = PlayStoreUpdateService(
        packageInfoLoader: () async =>
            _packageInfo(installerStore: 'com.android.vending'),
        checkForUpdate: () async => const PlayUpdateSnapshot(
          isUpdateAvailable: true,
          availableVersionCode: 2026061501,
        ),
        isSupportedBuild: (_) => true,
      );

      final result = await service.checkForUpdate();
      expect(result.status, UpdateCheckStatus.available);
      expect(result.availableVersionCode, 2026061501);
      expect(result.hasUpdate, isTrue);
    });

    test('up-to-date snapshot returns upToDate status', () async {
      final service = PlayStoreUpdateService(
        packageInfoLoader: () async =>
            _packageInfo(installerStore: 'com.android.vending'),
        checkForUpdate: () async => const PlayUpdateSnapshot(
          isUpdateAvailable: false,
          availableVersionCode: null,
        ),
        isSupportedBuild: (_) => true,
      );

      final result = await service.checkForUpdate();
      expect(result.status, UpdateCheckStatus.upToDate);
      expect(result.hasUpdate, isFalse);
    });

    test('service returns unknown when Play check throws', () async {
      final service = PlayStoreUpdateService(
        packageInfoLoader: () async =>
            _packageInfo(installerStore: 'com.android.vending'),
        checkForUpdate: () async => throw Exception('play unavailable'),
        isSupportedBuild: (_) => true,
      );

      final result = await service.checkForUpdate();
      expect(result.status, UpdateCheckStatus.unknown);
      expect(result.hasUpdate, isFalse);
    });

    test('debug build installed from Play proceeds to update flow', () async {
      // flutter test 下 kDebugMode 恒为 true。
      // 不注入 isSupportedBuild → 走真实默认 gate。
      // 改动前（!kDebugMode && ...）：gate 短路为 false → unsupported。
      // 改动后（android && fromPlay）：gate 通过 → 调用快照 → available。
      await _withAndroidPlatform(() async {
        final service = PlayStoreUpdateService(
          packageInfoLoader: () async =>
              _packageInfo(installerStore: 'com.android.vending'),
          checkForUpdate: () async => const PlayUpdateSnapshot(
            isUpdateAvailable: true,
            availableVersionCode: 2026061501,
          ),
        );

        final result = await service.checkForUpdate();
        expect(result.status, UpdateCheckStatus.available);
        expect(result.availableVersionCode, 2026061501);
      });
    });
  });

  group('isInstalledFromGooglePlay', () {
    test('returns true when installer is Google Play', () {
      final info = _packageInfo(installerStore: 'com.android.vending');
      expect(isInstalledFromGooglePlay(info), isTrue);
    });

    test('returns false for other installer stores', () {
      final info = _packageInfo(installerStore: 'com.other.store');
      expect(isInstalledFromGooglePlay(info), isFalse);
    });

    test('returns false when installer is null (sideloaded)', () {
      final info = _packageInfo(installerStore: null);
      expect(isInstalledFromGooglePlay(info), isFalse);
    });
  });
}
