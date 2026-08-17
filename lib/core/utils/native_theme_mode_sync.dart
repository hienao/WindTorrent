import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:windwalker/core/utils/log.dart';

class NativeThemeModeSync {
  static const MethodChannel _channel = MethodChannel('com.windtorrent/theme');

  static Future<void> sync(String mode) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await _channel.invokeMethod<void>('setThemeMode', {'mode': mode});
    } on MissingPluginException catch (e) {
      Log.w('Native theme sync channel unavailable: $e');
    }
  }
}
