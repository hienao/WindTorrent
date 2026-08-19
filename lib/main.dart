import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/app.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/core/utils/startup_trace.dart';
import 'package:windwalker/services/analytics_service.dart';

void main() async {
  StartupTrace.mark('main_enter');
  WidgetsFlutterBinding.ensureInitialized();
  StartupTrace.mark('binding_ready');

  // Android 15+ enforces edge-to-edge for targetSdk 35+ apps. Opt in
  // explicitly so older supported Android versions follow the same layout
  // contract, and avoid relying on deprecated system bar color APIs.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  StartupTrace.mark('edge_to_edge_ready');

  Log.init(tag: 'WindTorrent', usePlatformLogging: !kDebugMode);
  StartupTrace.mark('log_ready');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    StartupTrace.markFirstFrameBuilt();
  });
  WidgetsBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    if (timings.isNotEmpty) {
      StartupTrace.markFirstFrameRasterized();
    }
  });

  StartupTrace.mark('firebase_init_start');
  // 致命初始化错误 fail-fast：Firebase 失败应让应用崩溃暴露问题，
  // 而非 catch 后带隐性故障继续 runApp。参见 CLAUDE.md「禁止防御性编程」。
  // 此处 try/catch 仅用于上报 app_init_failed 埋点，随后 rethrow 保持 fail-fast。
  try {
    await Firebase.initializeApp();
    await AnalyticsService.instance.syncBuildUserProperties();
    StartupTrace.mark('firebase_init_done');
  } catch (e) {
    await AnalyticsService.instance.track(
      'app_init_failed',
      params: <String, Object>{
        'phase': 'firebase',
        'error_type': e.runtimeType.toString(),
      },
    );
    rethrow;
  }

  StartupTrace.mark('get_storage_init_start');
  // 同上：GetStorage 是所有控制器持久化基础，失败必须 fail-fast。
  try {
    await GetStorage.init();
    StartupTrace.mark('get_storage_init_done');
  } catch (e) {
    await AnalyticsService.instance.track(
      'app_init_failed',
      params: <String, Object>{
        'phase': 'get_storage',
        'error_type': e.runtimeType.toString(),
      },
    );
    rethrow;
  }

  // first_open 上报（基于 GetStorage 标记位，必须在 GetStorage.init() 之后）
  await _trackFirstOpenIfNeeded();

  StartupTrace.mark('run_app');
  runApp(const WindTorrentApp());
}

/// 首次安装上报。基于 GetStorage 的 app_first_open 标记位，
/// 补 Firebase first_open 在卸装重装时失效的场景。
Future<void> _trackFirstOpenIfNeeded() async {
  try {
    final storage = GetStorage();
    final flagged = storage.read<bool>('app_first_open') ?? false;
    if (!flagged) {
      await storage.write('app_first_open', true);
      await AnalyticsService.instance.track('app_first_open_tracked');
    }
  } catch (e) {
    // first_open 是软标记，失败不影响启动
    Log.w('首次安装标记上报失败: $e');
  }
}
