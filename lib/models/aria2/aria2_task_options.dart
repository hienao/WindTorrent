/// Aria2 任务选项模型。
///
/// 对应 `aria2.getOption` 返回的选项键值对。
class Aria2TaskOptions {
  const Aria2TaskOptions({required this.options});

  /// 选项键值对（原始字符串形式）。
  final Map<String, String> options;

  /// 下载限速（bytes/s），0 表示无限制。
  int get maxDownloadLimit =>
      int.tryParse(options['max-download-limit'] ?? '0') ?? 0;

  /// 上传限速（bytes/s），0 表示无限制。
  int get maxUploadLimit =>
      int.tryParse(options['max-upload-limit'] ?? '0') ?? 0;

  /// 最大连接数（来自 bt-max-peers），0 表示无限制。
  int get maxConnectionLimit =>
      int.tryParse(options['bt-max-peers'] ?? '0') ?? 0;

  /// 保存路径。
  String get dir => options['dir'] ?? '';

  /// BT tracker 列表（逗号分隔）。
  String get btTracker => options['bt-tracker'] ?? '';

  factory Aria2TaskOptions.fromJson(Map<String, dynamic> json) {
    final options = <String, String>{};
    json.forEach((key, value) {
      options[key] = value?.toString() ?? '';
    });
    return Aria2TaskOptions(options: options);
  }
}
