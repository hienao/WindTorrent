import 'package:flutter/material.dart';

/// 详情页子页面入口卡片。
///
/// 用于「文件 / 服务器(Trackers) / 节点(Peers) / 选项」等入口，
/// 展示标题、副标题与图标，点击跳转子页面。
///
/// 设计为放入 `NeoSection`（带背景色的容器）内的一个条目：
/// 用透明 [Material] 包裹 [ListTile]，使水波纹/点击效果可正常绘制，
/// 同时不覆盖父容器的背景色。
class TaskDetailEntryCard extends StatelessWidget {
  const TaskDetailEntryCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
