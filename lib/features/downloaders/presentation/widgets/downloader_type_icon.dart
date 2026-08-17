import 'package:flutter/material.dart';
import 'package:windwalker/core/constants/app_constants.dart';

/// 下载器类型图标的尺寸层级。
enum DownloaderTypeIconSize { small, medium, large }

/// 统一的下载器类型图标组件。
///
/// 当前实现使用静态图片资产承载最终视觉稿，避免复杂 painter 在
/// qBittorrent / Aria2 上反复偏离设计要求。
class DownloaderTypeIcon extends StatelessWidget {
  final DownloaderType type;
  final DownloaderTypeIconSize size;

  const DownloaderTypeIcon({
    super.key,
    required this.type,
    this.size = DownloaderTypeIconSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final dimension = switch (size) {
      DownloaderTypeIconSize.large => 48.0,
      DownloaderTypeIconSize.medium => 44.0,
      DownloaderTypeIconSize.small => 28.0,
    };

    return SizedBox.square(
      key: Key('downloader-type-icon-${type.name}-${size.name}'),
      dimension: dimension,
      child: Image.asset(
        _assetName(type),
        key: Key('downloader-type-asset-${type.name}'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  String _assetName(DownloaderType type) {
    return switch (type) {
      DownloaderType.aria2 =>
        'assets/branding/downloader_types/downloader_type_aria2.png',
      DownloaderType.qbittorrent =>
        'assets/branding/downloader_types/downloader_type_qbittorrent.png',
      DownloaderType.transmission =>
        'assets/branding/downloader_types/downloader_type_transmission.png',
    };
  }
}
