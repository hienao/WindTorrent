import 'package:windwalker/services/qbit/qbit_api_generation.dart';

/// 不可变的服务端检测结果。
///
/// 携带解析后的版本与推断出的 [apiGeneration]，供 QBitService 选择对应 adapter。
class QBitServerProfile {
  final String appVersion;
  final String webApiVersion;
  final QBitApiGeneration apiGeneration;
  final String rawAppVersion;
  final String rawWebApiVersion;

  const QBitServerProfile({
    required this.appVersion,
    required this.webApiVersion,
    required this.apiGeneration,
    required this.rawAppVersion,
    required this.rawWebApiVersion,
  });
}
