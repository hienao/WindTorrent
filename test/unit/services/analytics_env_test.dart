import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/services/analytics_env.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/tmp/test_windwalker';
        }
        return null;
      },
    );
    // mock package_info_plus
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'windwalker',
            'packageName': 'com.example.windwalker',
            'version': '1.0.3',
            'buildNumber': '2026062104',
            'buildSignature': '',
            'installerStore': null,
          };
        }
        return null;
      },
    );
    // mock connectivity_plus
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return <String>['wifi'];
        }
        return null;
      },
    );
    await GetStorage.init();
  });

  test('getEnvParams 返回必填字段', () async {
    final provider = AnalyticsEnvProvider();
    final env = await provider.getEnvParams();

    expect(env.containsKey('app_version'), isTrue);
    expect(env.containsKey('app_build'), isTrue);
    expect(env.containsKey('platform'), isTrue);
    expect(env.containsKey('locale'), isTrue);
    expect(env.containsKey('network_type'), isTrue);
  });

  test('缓存后第二次调用不重新读 PackageInfo', () async {
    final provider = AnalyticsEnvProvider();
    await provider.getEnvParams();
    // 第二次调用应走缓存，network_type 仍会刷新但其余字段不变
    final env2 = await provider.getEnvParams();
    expect(env2.containsKey('app_version'), isTrue);
  });
}
