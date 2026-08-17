import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:windwalker/features/backup/data/backup_exceptions.dart';
import 'package:windwalker/features/backup/data/backup_storage_api.dart';
import 'package:windwalker/features/backup/data/webdav_config.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';
import 'package:windwalker/models/downloader_backup_version.dart';

class WebDavBackupStorageApi implements BackupStorageApi {
  WebDavBackupStorageApi({
    required WebDavConfig? Function() readConfig,
    http.Client? client,
  }) : _readConfig = readConfig,
       _client = client ?? http.Client();

  static const filePrefix = 'windwalker_downloaders_backup_';

  final WebDavConfig? Function() _readConfig;
  final http.Client _client;

  @override
  Future<void> testConnection() async {
    final config = _requireConfig();
    await _propfind(_rootUri(config), depth: '0', config: config);
    await _ensureDirectoryExists(config);
    await _propfind(_directoryUri(config), depth: '0', config: config);
  }

  @override
  Future<List<DownloaderBackupVersion>> listVersions() async {
    final config = _requireConfig();
    final directoryUri = _directoryUri(config);
    await _ensureDirectoryExists(config);
    final response = await _propfind(directoryUri, depth: '1', config: config);
    final entries = _parseEntries(response.body, directoryUri);
    final fileEntries = entries
        .where((entry) => !entry.isCollection)
        .where((entry) => entry.fileName.startsWith(filePrefix))
        .where((entry) => entry.fileName.endsWith('.json'))
        .toList();

    final versions = <DownloaderBackupVersion>[];
    for (final entry in fileEntries) {
      final bytes = await downloadBackup(entry.uri.toString());
      final bundle = _parseBundle(bytes);
      versions.add(
        DownloaderBackupVersion(
          fileId: entry.uri.toString(),
          fileName: entry.fileName,
          backupId: bundle.backupId,
          createdAt: bundle.createdAt,
          appVersion: bundle.appVersion,
          downloaderCount: bundle.downloaders.length,
          isLatest: false,
        ),
      );
    }

    versions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (versions.isEmpty) {
      return const [];
    }

    return [
      DownloaderBackupVersion(
        fileId: versions.first.fileId,
        fileName: versions.first.fileName,
        backupId: versions.first.backupId,
        createdAt: versions.first.createdAt,
        appVersion: versions.first.appVersion,
        downloaderCount: versions.first.downloaderCount,
        isLatest: true,
      ),
      ...versions.skip(1),
    ];
  }

  @override
  Future<void> uploadBackup(DownloaderBackupBundle bundle) async {
    final config = _requireConfig();
    await _ensureDirectoryExists(config);
    final fileUri = _directoryUri(
      config,
      extraSegments: <String>[_buildBackupFileName(bundle.createdAt)],
      trailingSlash: false,
    );
    final response = await _send(
      'PUT',
      fileUri,
      config: config,
      body: utf8.encode(jsonEncode(bundle.toJson())),
      contentType: 'application/json; charset=utf-8',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpException(
        response.statusCode,
        message: 'webdav upload failed',
      );
    }
  }

  @override
  Future<List<int>> downloadBackup(String fileId) async {
    final config = _requireConfig();
    final response = await _send('GET', Uri.parse(fileId), config: config);
    if (response.statusCode != 200) {
      throw _mapHttpException(
        response.statusCode,
        message: 'webdav download failed',
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<void> deleteBackup(String fileId) async {
    final config = _requireConfig();
    final response = await _send('DELETE', Uri.parse(fileId), config: config);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapHttpException(
        response.statusCode,
        message: 'webdav delete failed',
      );
    }
  }

  Future<http.Response> _propfind(
    Uri uri, {
    required String depth,
    required WebDavConfig config,
  }) {
    return _send(
      'PROPFIND',
      uri,
      config: config,
      headers: <String, String>{'Depth': depth},
      body: utf8.encode(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<d:propfind xmlns:d="DAV:"><d:allprop /></d:propfind>',
      ),
      contentType: 'application/xml; charset=utf-8',
    );
  }

  Future<void> _ensureDirectoryExists(WebDavConfig config) async {
    final segments = config.normalizedRemoteDirectory
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final builtSegments = <String>[];
    for (final segment in segments) {
      builtSegments.add(segment);
      final uri = _resolveRelativeUri(
        config,
        builtSegments,
        trailingSlash: true,
      );
      final probe = await _propfind(uri, depth: '0', config: config);
      if (probe.statusCode == 207) {
        continue;
      }
      if (probe.statusCode != 404) {
        throw _mapHttpException(
          probe.statusCode,
          message: 'webdav directory probe failed',
        );
      }
      final response = await _send('MKCOL', uri, config: config);
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 405) {
        continue;
      }
      throw _mapHttpException(
        response.statusCode,
        message: 'webdav mkcol failed for ${uri.toString()}',
      );
    }
  }

  List<_WebDavEntry> _parseEntries(String body, Uri directoryUri) {
    try {
      final document = XmlDocument.parse(body);
      return document.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'response')
          .map((element) => _toEntry(element, directoryUri))
          .whereType<_WebDavEntry>()
          .toList();
    } on XmlParserException catch (e) {
      throw BackupException(
        reason: BackupFailureReason.parseFailed,
        message: e.message,
      );
    }
  }

  _WebDavEntry? _toEntry(XmlElement element, Uri directoryUri) {
    final hrefText = _firstDescendantText(element, 'href');
    if (hrefText == null || hrefText.trim().isEmpty) {
      return null;
    }
    final hrefUri = _resolveHref(directoryUri, hrefText.trim());
    final isCollection = element.descendants.whereType<XmlElement>().any(
      (child) => child.name.local == 'collection',
    );
    final fileName = hrefUri.pathSegments.isEmpty
        ? ''
        : Uri.decodeComponent(hrefUri.pathSegments.last);
    return _WebDavEntry(
      uri: hrefUri,
      fileName: fileName,
      isCollection: isCollection,
    );
  }

  DownloaderBackupBundle _parseBundle(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return DownloaderBackupBundle.fromJson(json);
    } on FormatException catch (e) {
      throw BackupException(
        reason: BackupFailureReason.parseFailed,
        message: e.message,
      );
    }
  }

  Uri _resolveHref(Uri base, String href) {
    final parsed = Uri.parse(href);
    if (parsed.hasScheme) {
      return parsed;
    }
    return base.resolveUri(parsed);
  }

  Uri _rootUri(WebDavConfig config) => Uri.parse(config.normalizedRootUrl);

  Uri _directoryUri(
    WebDavConfig config, {
    List<String> extraSegments = const <String>[],
    bool trailingSlash = true,
  }) {
    return _resolveRelativeUri(config, <String>[
      ...config.normalizedRemoteDirectory
          .split('/')
          .where((segment) => segment.isNotEmpty),
      ...extraSegments,
    ], trailingSlash: trailingSlash);
  }

  Uri _resolveRelativeUri(
    WebDavConfig config,
    List<String> relativeSegments, {
    required bool trailingSlash,
  }) {
    final root = _rootUri(config);
    final rootSegments = root.pathSegments.where(
      (segment) => segment.isNotEmpty,
    );
    final pathSegments = <String>[...rootSegments, ...relativeSegments];
    final path = '/${pathSegments.map(Uri.encodeComponent).join('/')}';
    return root.replace(path: trailingSlash ? '$path/' : path);
  }

  WebDavConfig _requireConfig() {
    final config = _readConfig();
    if (config == null ||
        config.rootUrl.trim().isEmpty ||
        config.username.trim().isEmpty ||
        config.password.isEmpty) {
      throw const BackupException(reason: BackupFailureReason.notConfigured);
    }
    return config;
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    required WebDavConfig config,
    Map<String, String> headers = const <String, String>{},
    List<int>? body,
    String? contentType,
  }) async {
    try {
      final request = http.Request(method, uri);
      request.headers.addAll(_authHeaders(config));
      request.headers.addAll(headers);
      if (contentType != null) {
        request.headers['Content-Type'] = contentType;
      }
      if (body != null) {
        request.bodyBytes = body;
      }
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    } on SocketException catch (e) {
      throw BackupException(
        reason: BackupFailureReason.network,
        message: e.message,
      );
    } on http.ClientException catch (e) {
      throw BackupException(
        reason: BackupFailureReason.network,
        message: e.message,
      );
    }
  }

  Map<String, String> _authHeaders(WebDavConfig config) {
    final token = base64Encode(
      utf8.encode('${config.username.trim()}:${config.password}'),
    );
    return <String, String>{'Authorization': 'Basic $token'};
  }

  BackupException _mapHttpException(int statusCode, {String? message}) {
    if (statusCode == 401 || statusCode == 403) {
      return BackupException(
        reason: BackupFailureReason.unauthorized,
        statusCode: statusCode,
        message: message,
      );
    }
    if (statusCode >= 500) {
      return BackupException(
        reason: BackupFailureReason.server,
        statusCode: statusCode,
        message: message,
      );
    }
    return BackupException(
      reason: BackupFailureReason.unknown,
      statusCode: statusCode,
      message: message,
    );
  }

  static String _buildBackupFileName(DateTime createdAtUtc) {
    final iso = createdAtUtc.toUtc().toIso8601String().replaceAll(':', '-');
    return '$filePrefix${iso.replaceAll('.000', '')}.json';
  }

  String? _firstDescendantText(XmlElement element, String localName) {
    for (final child in element.descendants.whereType<XmlElement>()) {
      if (child.name.local == localName) {
        return child.innerText;
      }
    }
    return null;
  }
}

class _WebDavEntry {
  const _WebDavEntry({
    required this.uri,
    required this.fileName,
    required this.isCollection,
  });

  final Uri uri;
  final String fileName;
  final bool isCollection;
}
