/// Transmission 协议类型枚举。
enum TransmissionProtocol {
  /// JSON-RPC 2.0 + snake_case（Transmission 4.1.0+）
  modern,

  /// legacy RPC + kebab-case / camelCase（Transmission <4.1.0）
  legacy,
}

/// Transmission 协议探测失败类别。
enum TransmissionDetectionFailure {
  /// 认证失败（401）
  authFailed,

  /// 网络错误 / 超时 / 不可达
  networkError,

  /// 有响应但无法判定协议或关键字段异常
  unknown,
}

/// 协议探测成功后的信息载体。
class TransmissionProtocolInfo {
  const TransmissionProtocolInfo({
    required this.protocol,
    required this.appVersion,
    this.rpcSemver,
    this.rpcVersion,
    this.sessionId,
  });

  final TransmissionProtocol protocol;
  final String appVersion;
  final String? rpcSemver;
  final int? rpcVersion;
  final String? sessionId;
}

/// 协议探测结果——成功或失败。
class TransmissionDetectionResult {
  const TransmissionDetectionResult.success(this.info)
      : failureCategory = null;

  const TransmissionDetectionResult.failure(this.failureCategory)
      : info = null;

  final TransmissionProtocolInfo? info;
  final TransmissionDetectionFailure? failureCategory;

  bool get isSuccess => info != null;
  TransmissionProtocol get protocol => info!.protocol;
}
