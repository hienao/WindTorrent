/// 配置字段类型
enum ConfigFieldType {
  /// 开关 (Switch)
  toggle,

  /// 数值输入 (KB/s)
  kbps,
}

/// 单个配置字段描述
class ConfigField {
  /// 字段 key，对应 DownloaderSpeedConfig 中的属性名
  final String key;

  /// 显示标签
  final String label;

  /// 字段类型
  final ConfigFieldType type;

  /// 提示文本
  final String? hint;

  /// 依赖的字段 key（当依赖字段为 true 时才启用）
  final String? dependsOn;

  const ConfigField({
    required this.key,
    required this.label,
    required this.type,
    this.hint,
    this.dependsOn,
  });
}

/// 配置分组（卡片）
class ConfigSection {
  /// 分组标题
  final String title;

  /// 分组描述（可选，显示在标题下方）
  final String? description;

  /// 分组内的配置字段
  final List<ConfigField> fields;

  /// 当此字段 key 对应的 toggle 为 true 时，此 section 才启用
  final String? enabledBy;

  const ConfigSection({
    required this.title,
    this.description,
    required this.fields,
    this.enabledBy,
  });
}

/// 速度配置描述符
///
/// 每个 Service 通过此描述符声明自己支持哪些配置项，
/// 配置页据此动态渲染，无需感知下载器类型。
class SpeedConfigDescriptor {
  /// 所有配置分组
  final List<ConfigSection> sections;

  const SpeedConfigDescriptor({
    required this.sections,
  });
}
