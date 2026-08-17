/// 应用常量
class AppConstants {
  AppConstants._();

  static const String appName = 'WindTorrent';
  static const String appNameEn = 'WindTorrent';

  // 路由
  static const String homeRoute = '/';
  static const String tasksRoute = '/tasks';
  static const String addTaskRoute = '/add-task';
  static const String filesRoute = '/files';
  static const String downloadersRoute = '/downloaders';
  static const String settingsRoute = '/settings';
  static const String aboutRoute = '/about';
  static const String upgradeRoute = '/upgrade';

  // 外部链接与联系信息
  static const String privacyPolicyUrl =
      'https://windtorrent-hienao.web.app/privacy-policy';
  static const String developerEmail = 'shiwentao666@gmail.com';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.hienao.windtorrent';

  // 下载器类型
  static const String aria2 = 'aria2';
  static const String qbittorrent = 'qbittorrent';
  static const String transmission = 'transmission';

  // 默认端口
  static const Map<String, int> defaultPorts = {
    aria2: 6800,
    qbittorrent: 8080,
    transmission: 9091,
  };
}

/// 下载器类型枚举
enum DownloaderType {
  aria2('Aria2', '🔶'),
  qbittorrent('qBittorrent', '🟢'),
  transmission('Transmission', '🔵');

  final String label;
  final String icon;

  const DownloaderType(this.label, this.icon);
}

/// 下载器状态
enum DownloaderStatus {
  online('在线', '●'),
  offline('离线', '○'),
  error('错误', '⚠️');

  final String label;
  final String icon;

  const DownloaderStatus(this.label, this.icon);
}

/// 下载任务状态
enum TaskStatus {
  downloading('下载中', '⬇️'),
  waiting('等待中', '⏳'),
  paused('已暂停', '⏸'),
  seeding('做种中', '🌱'),
  completed('已完成', '✅'),
  removed('已移除', '🗑'),
  error('错误', '❌'),
  unknown('未知', '❓');

  final String label;
  final String icon;

  const TaskStatus(this.label, this.icon);
}
