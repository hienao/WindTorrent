import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/services/connection_result.dart';

void main() {
  group('ConnectionSuccess', () {
    test('isSuccess 为 true，携带 serverVersion', () {
      const result = ConnectionSuccess(serverVersion: '1.36.0');
      expect(result.isSuccess, isTrue);
      expect(result.serverVersion, '1.36.0');
    });

    test('serverVersion 可为 null', () {
      const result = ConnectionSuccess();
      expect(result.isSuccess, isTrue);
      expect(result.serverVersion, isNull);
    });
  });

  group('ConnectionFailure', () {
    test('versionUnsupported 携带实际与最低版本', () {
      const result = ConnectionFailure(
        ConnectionFailureCategory.versionUnsupported,
        '版本过低',
        actualVersion: '1.35.0',
        minVersion: '1.36',
      );
      expect(result.isSuccess, isFalse);
      expect(result.category, ConnectionFailureCategory.versionUnsupported);
      expect(result.isVersionUnsupported, isTrue);
      expect(result.actualVersion, '1.35.0');
      expect(result.minVersion, '1.36');
    });

    test('非版本失败时 isVersionUnsupported 为 false', () {
      const result = ConnectionFailure(
        ConnectionFailureCategory.authFailed,
        '认证失败',
      );
      expect(result.isVersionUnsupported, isFalse);
      expect(result.actualVersion, isNull);
      expect(result.minVersion, isNull);
    });
  });
}
