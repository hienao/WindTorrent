import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Unified logging utility for WindTorrent
///
/// This class provides a centralized logging interface that can:
///
/// - Route logs to different backends (debugPrint, Android Log, iOS os_log, etc.)
/// - Be easily swapped out for different implementations later
/// - Support log levels (debug, info, warn, error)
///
/// Usage:
/// ```dart
/// Log.d('Debug message');      // Debug level
/// Log.i('Info message');       // Info level
/// Log.w('Warning message');    // Warning level
/// Log.e('Error message');      // Error level
/// ```
class Log {
  Log._();

  /// Channel name for platform-specific logging
  static const String _channelName = 'com.windtorrent/log';

  /// Cached MethodChannel instance
  static MethodChannel? _channel;

  /// Whether to use platform-native logging (Android Log, iOS os_log)
  /// When false, falls back to debugPrint
  static bool _usePlatformLogging = !kDebugMode;

  /// Tag used for Android/iOS platform logs
  static String _tag = 'WindTorrent';

  /// Initialize the logging system
  ///
  /// [tag] - Custom tag for platform logs (default: 'WindTorrent')
  /// [usePlatformLogging] - Whether to use platform-native logging
  static void init({String? tag, bool? usePlatformLogging}) {
    _tag = tag ?? _tag;
    _usePlatformLogging = usePlatformLogging ?? !kDebugMode;

    if (_usePlatformLogging && _channel == null) {
      _channel = const MethodChannel(_channelName);
    }

    i('Log system initialized', tag: _tag);
  }

  /// Debug level log
  static void d(String message, {String? tag}) {
    _log(Level.debug, message, tag: tag);
  }

  /// Info level log
  static void i(String message, {String? tag}) {
    _log(Level.info, message, tag: tag);
  }

  /// Warning level log
  static void w(String message, {String? tag}) {
    _log(Level.warn, message, tag: tag);
  }

  /// Error level log
  static void e(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(Level.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Internal log dispatcher
  static void _log(
    Level level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final effectiveTag = tag ?? _tag;
    final fullMessage = error != null
        ? '$message\nError: $error${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}'
        : message;

    // Always print to debugPrint in debug mode
    if (kDebugMode) {
      debugPrint('[$effectiveTag][${level.name}] $fullMessage');
    }

    // Route to platform-native logging in release mode or when explicitly enabled
    if (_usePlatformLogging) {
      _sendToPlatform(level, effectiveTag, fullMessage);
    }
  }

  /// Send log to platform-specific logging system
  static Future<void> _sendToPlatform(
    Level level,
    String tag,
    String message,
  ) async {
    if (_channel == null) return;

    try {
      await _channel!.invokeMethod('log', {
        'level': level.name,
        'tag': tag,
        'message': message,
      });
    } on PlatformException catch (e) {
      // Silently fail if platform logging fails
      debugPrint('Failed to send log to platform: ${e.message}');
    }
  }
}

/// Log levels
enum Level { debug, info, warn, error }
