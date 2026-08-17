import 'package:http/http.dart' as http;
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/downloader_service_exception.dart';

/// qBittorrent 会话：负责登录、SID 维护与统一请求发送。
///
/// 作为版本检测器与各版本 adapter 的共享底层。网络 I/O 异常统一转换为
/// [DownloaderServiceException]（network 类别），非 200 响应转换为 protocol，
/// 对齐 CLAUDE.md「编码规范：禁止防御性编程」的分层异常范式。
class QBitSession {
  final Downloader downloader;
  final http.Client _client;
  String? _sid;

  QBitSession(this.downloader, {http.Client? client})
      : _client = client ?? http.Client();

  String get baseUrl => downloader.rpcUrl;

  Map<String, String> get headers => {
        'Referer': baseUrl,
        'Cookie': ?_sid,
      };

  /// 执行 HTTP 请求，将网络 I/O 异常（Socket/Timeout）转换为
  /// [DownloaderServiceException]（network）。
  Future<T> _send<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw DownloaderServiceException(
        'qBittorrent 网络错误: $e',
        category: DownloaderServiceErrorCategory.network,
      );
    }
  }

  /// 登录获取 SID。
  ///
  /// 缺少凭据 / 认证失败 → auth；响应缺 SID → protocol。
  Future<void> login() async {
    if (downloader.username == null || downloader.password == null) {
      throw DownloaderServiceException(
        'qBittorrent 缺少用户名/密码',
        category: DownloaderServiceErrorCategory.auth,
      );
    }

    final response = await _send(() => _client
        .post(
          Uri.parse('$baseUrl/api/v2/auth/login'),
          body: {
            'username': downloader.username!,
            'password': downloader.password!,
          },
          headers: {'Referer': baseUrl},
        )
        .timeout(const Duration(seconds: 10)));

    // qBittorrent 返回 200 但 body 为 "Ok." 或 "Fails."，必须检查 body
    if (response.body.trim() != 'Ok.') {
      throw DownloaderServiceException(
        'qBittorrent 用户名/密码错误',
        category: DownloaderServiceErrorCategory.auth,
      );
    }

    final cookie = response.headers['set-cookie'];
    if (cookie == null) {
      throw DownloaderServiceException(
        'qBittorrent SID 缺失',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    _sid = cookie.split(';').first;
  }

  /// GET 文本响应。未登录时自动登录；非 200 抛 protocol 异常。
  Future<String> getText(String path) async {
    if (_sid == null) {
      await login();
    }
    final response = await _send(() => _client
        .get(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(const Duration(seconds: 10)));
    if (response.statusCode != 200) {
      throw DownloaderServiceException(
        'qBittorrent GET $path 失败: HTTP ${response.statusCode}',
        category: DownloaderServiceErrorCategory.protocol,
      );
    }
    return response.body;
  }

  /// POST application/x-www-form-urlencoded。未登录时自动登录。
  ///
  /// 返回原始响应，由调用方判断 statusCode。遇到 403（SID 过期）时
  /// 自动重新登录并重试一次。
  Future<http.Response> postForm(String path, Map<String, String> body) async {
    if (_sid == null) {
      await login();
    }
    var response = await _postFormOnce(path, body);
    if (response.statusCode == 403) {
      _sid = null;
      await login();
      response = await _postFormOnce(path, body);
    }
    return response;
  }

  Future<http.Response> _postFormOnce(String path, Map<String, String> body) {
    return _send(() => _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            ...headers,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 10)));
  }

  /// 发送 multipart 请求（torrent 文件上传等）。未登录时自动登录，
  /// 自动附加 Referer 与 SID cookie。网络 I/O 异常转换为
  /// [DownloaderServiceException]（network）。
  Future<http.Response> sendMultipart(http.MultipartRequest request) async {
    if (_sid == null) {
      await login();
    }
    request.headers.addAll(headers);
    return _send(() async => http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 30))));
  }
}
