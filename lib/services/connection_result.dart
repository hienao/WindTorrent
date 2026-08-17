/// 下载器连接 / 版本校验结果。
///
/// 让 `testConnection()` 从 `bool` 升级为"成功 / 失败 + 类别 + 原因"，
/// 使"版本不符"能与"认证失败 / 无法连接"区分开。
sealed class ConnectionResult {
  const ConnectionResult();

  /// 是否连接成功（含版本达标）。
  bool get isSuccess => false;
}

/// 连接成功且版本达标。
///
/// [serverVersion] 为服务端实际版本字符串，供 controller 写入
/// `Downloader.version`。
class ConnectionSuccess extends ConnectionResult {
  const ConnectionSuccess({this.serverVersion});

  final String? serverVersion;

  @override
  bool get isSuccess => true;
}

/// 连接失败的类别。
enum ConnectionFailureCategory {
  /// 服务端版本低于最低要求。
  versionUnsupported,

  /// 认证失败（用户名 / 密码 / RPC secret 错误）。
  authFailed,

  /// 网络 / 超时 / 不可达。
  networkError,

  /// 其他未分类错误。
  unknown,
}

/// 连接失败，携带类别与人类可读原因。
class ConnectionFailure extends ConnectionResult {
  final ConnectionFailureCategory category;
  final String reason;

  /// 服务端实际版本（仅 [ConnectionFailureCategory.versionUnsupported]）。
  final String? actualVersion;

  /// 要求的最低版本（仅 [ConnectionFailureCategory.versionUnsupported]）。
  final String? minVersion;

  const ConnectionFailure(
    this.category,
    this.reason, {
    this.actualVersion,
    this.minVersion,
  });

  /// 是否为版本不符。
  bool get isVersionUnsupported =>
      category == ConnectionFailureCategory.versionUnsupported;
}
