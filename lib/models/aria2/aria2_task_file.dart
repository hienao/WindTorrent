/// Aria2 文件条目模型。
///
/// 对应 `aria2.getFiles` 返回的单个文件信息。
class Aria2TaskFile {
  const Aria2TaskFile({
    required this.index,
    required this.path,
    required this.length,
    required this.completedLength,
    required this.selected,
    required this.uris,
  });

  final int index;
  final String path;
  final int length;
  final int completedLength;
  final bool selected;
  final List<String> uris;

  double get progress => length > 0 ? completedLength / length : 0;

  String get name {
    if (path.isEmpty) return 'Unknown';
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    if (idx < 0 || idx == normalized.length - 1) return normalized;
    return normalized.substring(idx + 1);
  }

  factory Aria2TaskFile.fromJson(Map<String, dynamic> json) {
    final uris = <String>[];
    if (json['uris'] is List) {
      for (final uri in json['uris'] as List) {
        if (uri is Map) {
          final uriStr = uri['uri']?.toString();
          if (uriStr != null && uriStr.isNotEmpty) uris.add(uriStr);
        }
      }
    }
    return Aria2TaskFile(
      index: int.tryParse(json['index']?.toString() ?? '0') ?? 0,
      path: json['path']?.toString() ?? '',
      length: int.tryParse(json['length']?.toString() ?? '0') ?? 0,
      completedLength:
          int.tryParse(json['completedLength']?.toString() ?? '0') ?? 0,
      selected: json['selected']?.toString() == 'true',
      uris: uris,
    );
  }
}
