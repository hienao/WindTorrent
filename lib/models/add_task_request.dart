import 'dart:typed_data';

/// 统一的添加任务请求模型
///
/// 将 URL 提交和 torrent 文件提交统一为一种请求结构，
/// 通过 [hasUrlSource] / [hasTorrentSource] 判断来源类型，
/// 通过 [isValidSourceSelection] 确保恰好选择了一种来源。
class AddTaskRequest {
  final String downloaderId;
  final String? url;
  final Uint8List? torrentFileBytes;
  final String? torrentFileName;
  final String? savePath;

  const AddTaskRequest({
    required this.downloaderId,
    this.url,
    this.torrentFileBytes,
    this.torrentFileName,
    this.savePath,
  });

  /// 是否以 URL 作为下载来源
  bool get hasUrlSource => url != null && url!.trim().isNotEmpty;

  /// 是否以 torrent 文件作为下载来源
  bool get hasTorrentSource =>
      torrentFileBytes != null &&
      torrentFileBytes!.isNotEmpty &&
      torrentFileName != null &&
      torrentFileName!.trim().isNotEmpty;

  /// 来源选择是否合法（恰好选了一种）
  bool get isValidSourceSelection => hasUrlSource != hasTorrentSource;

  /// Creates a copy with the given fields replaced.
  ///
  /// [clearUrl] and [clearTorrent] take priority: when set to `true`,
  /// the corresponding field is set to `null` regardless of other parameters.
  ///
  /// [clearUrl] 为 true 时将 [url] 置为 null；
  /// [clearTorrent] 为 true 时将 [torrentFileBytes] 和 [torrentFileName] 置为 null。
  AddTaskRequest copyWith({
    String? downloaderId,
    String? url,
    Uint8List? torrentFileBytes,
    String? torrentFileName,
    String? savePath,
    bool clearUrl = false,
    bool clearTorrent = false,
  }) {
    return AddTaskRequest(
      downloaderId: downloaderId ?? this.downloaderId,
      url: clearUrl ? null : (url ?? this.url),
      torrentFileBytes:
          clearTorrent ? null : (torrentFileBytes ?? this.torrentFileBytes),
      torrentFileName:
          clearTorrent ? null : (torrentFileName ?? this.torrentFileName),
      savePath: savePath ?? this.savePath,
    );
  }
}
