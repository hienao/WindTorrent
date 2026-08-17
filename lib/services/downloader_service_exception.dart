/// 下载器服务异常。
///
/// fail-fast 原则：service 层遇到错误时抛出此异常，由 controller 层捕获
/// 并写入 errorState 传播给 UI。参见 CLAUDE.md「编码规范：禁止防御性编程」。
class DownloaderServiceException implements Exception {
  DownloaderServiceException(
    this.message, {
    this.category = DownloaderServiceErrorCategory.unknown,
  });

  /// 错误类别，便于 UI 分类展示。
  final DownloaderServiceErrorCategory category;

  /// 人类可读的错误描述。
  final String message;

  @override
  String toString() => 'DownloaderServiceException($category): $message';
}

/// 下载器服务错误类别。
enum DownloaderServiceErrorCategory {
  /// 网络错误（连接超时、Socket 异常等）
  network,

  /// 认证失败（用户名/密码/secret 错误）
  auth,

  /// 协议错误（HTTP 状态码异常、RPC error、响应格式异常）
  protocol,

  /// 未知错误
  unknown,
}
