import 'dart:core';

import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/services/analytics_service.dart';

/// 冷启动链路打点工具（毫秒级）。
class StartupTrace {
  StartupTrace._();

  static final Stopwatch _sw = Stopwatch()..start();

  static bool _firstFrameBuiltLogged = false;
  static bool _firstFrameRasterizedLogged = false;
  static bool _launchReported = false;

  static int get elapsedMs => _sw.elapsedMilliseconds;

  static void mark(String label) {
    Log.i('[StartupTrace] $label | t=${elapsedMs}ms');
  }

  static void markFirstFrameBuilt() {
    if (_firstFrameBuiltLogged) return;
    _firstFrameBuiltLogged = true;
    final durationMs = elapsedMs;
    mark('first_frame_built');
    _reportLaunchIfNeeded(durationMs);
  }

  static void markFirstFrameRasterized() {
    if (_firstFrameRasterizedLogged) return;
    _firstFrameRasterizedLogged = true;
    mark('first_frame_rasterized');
  }

  /// 上报 app_launch 事件（首帧构建完成时调用一次）。
  static Future<void> _reportLaunchIfNeeded(int durationMs) async {
    if (_launchReported) return;
    _launchReported = true;

    await AnalyticsService.instance.track(
      'app_launch',
      params: <String, Object>{
        'launch_duration_ms': durationMs,
        'init_phase': 'completed',
        'cold_start': 'true',
      },
    );
  }
}
