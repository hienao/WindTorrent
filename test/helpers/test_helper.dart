import 'package:flutter_test/flutter_test.dart';

/// 测试初始化辅助
///
/// 为需要特定环境的测试提供初始化
class TestHelper {
  static bool _initialized = false;

  /// 初始化（如果需要）
  static Future<void> initialize() async {
    if (_initialized) return;

    _initialized = true;
    // 可以在这里初始化测试所需的环境
  }

  /// 清理
  static void cleanup() {
    _initialized = false;
  }
}
