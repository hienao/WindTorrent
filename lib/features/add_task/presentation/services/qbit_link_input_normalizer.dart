/// 归一化 qBittorrent 批量磁力链接输入。
///
/// 按行 trim、丢弃空行，再用 `\n` 重新拼接。仅用于 qBittorrent 多行输入态；
/// 单行链接由调用方自行 trim。
String normalizeQBitBulkInput(String raw) {
  final lines = raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  return lines.join('\n');
}
