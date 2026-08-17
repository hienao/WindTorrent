import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/transmission/transmission_protocol_info.dart';

/// Transmission 协议自动识别器。
///
/// 采用 "modern 优先，legacy 回退" 策略：
/// 1. 先发 JSON-RPC 2.0 `session_get`
/// 2. 若响应为 modern 格式则判定为 modern
/// 3. 否则回退发 legacy `session-get`
/// 4. 两轮均失败则返回失败结果
class TransmissionProtocolDetector {
  TransmissionProtocolDetector(this.downloader, {http.Client? client})
      : _client = client ?? http.Client();

  final Downloader downloader;
  final http.Client _client;

  String get _rpcUrl => downloader.rpcUrl;

  Future<TransmissionDetectionResult> detect() async {
    try {
      final modern = await _detectModern();
      if (modern.isSuccess) return modern;

      // 认证失败直接返回，不回退 legacy（同样会 401）
      if (modern.failureCategory ==
          TransmissionDetectionFailure.authFailed) {
        return modern;
      }

      // 复用 modern 阶段拿到的 sessionId
      final legacy = await _detectLegacy(
        sessionId: modern.info?.sessionId,
      );
      return legacy;
    } catch (e, st) {
      Log.e('TransmissionProtocolDetector.detect error',
          error: e, stackTrace: st);
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.networkError,
      );
    }
  }

  /// Modern 协议探测：JSON-RPC 2.0 `session_get`。
  Future<TransmissionDetectionResult> _detectModern() async {
    var response = await _client.post(
      Uri.parse(_rpcUrl),
      headers: _headers(),
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'session_get',
        'id': 1,
      }),
    );

    String? sessionId;
    if (response.statusCode == 409) {
      sessionId = response.headers['x-transmission-session-id'];
      response = await _client.post(
        Uri.parse(_rpcUrl),
        headers: _headers(sessionId: sessionId),
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'session_get',
          'id': 1,
        }),
      );
    }

    if (response.statusCode == 401) {
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.authFailed,
      );
    }

    if (response.statusCode != 200) {
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.networkError,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final result = body['result'];
    if (body['jsonrpc'] == '2.0' && result is Map<String, dynamic>) {
      return TransmissionDetectionResult.success(
        TransmissionProtocolInfo(
          protocol: TransmissionProtocol.modern,
          appVersion: _normalizeAppVersion(result['version']?.toString()),
          rpcSemver: result['rpc_version_semver']?.toString(),
          sessionId: sessionId,
        ),
      );
    }

    // 响应非 modern 格式 → 需回退 legacy
    return TransmissionDetectionResult.failure(
      TransmissionDetectionFailure.unknown,
    );
  }

  /// Legacy 协议探测：legacy RPC `session-get`。
  Future<TransmissionDetectionResult> _detectLegacy({
    String? sessionId,
  }) async {
    final response = await _client.post(
      Uri.parse(_rpcUrl),
      headers: _headers(sessionId: sessionId),
      body: jsonEncode({
        'method': 'session-get',
        'tag': 1,
      }),
    );

    if (response.statusCode == 401) {
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.authFailed,
      );
    }

    if (response.statusCode != 200) {
      return const TransmissionDetectionResult.failure(
        TransmissionDetectionFailure.networkError,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final arguments = body['arguments'];
    if (body['result'] == 'success' && arguments is Map<String, dynamic>) {
      return TransmissionDetectionResult.success(
        TransmissionProtocolInfo(
          protocol: TransmissionProtocol.legacy,
          appVersion: _normalizeAppVersion(arguments['version']?.toString()),
          rpcSemver: arguments['rpc-version-semver']?.toString(),
          sessionId: sessionId,
        ),
      );
    }

    return const TransmissionDetectionResult.failure(
      TransmissionDetectionFailure.unknown,
    );
  }

  Map<String, String> _headers({String? sessionId}) => {
        'Content-Type': 'application/json',
        'X-Transmission-Session-Id': ?sessionId,
        if (downloader.username != null && downloader.password != null)
          'Authorization': _basicAuth(),
      };

  String _basicAuth() {
    final raw = '${downloader.username}:${downloader.password}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  /// 从 "$version ($revision)" 长字符串中提取版本号首段。
  String _normalizeAppVersion(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw.split(RegExp(r'\s+')).first.trim();
  }
}
