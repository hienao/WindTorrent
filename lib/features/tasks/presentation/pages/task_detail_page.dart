import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/pages/aria2/aria2_task_detail_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_detail_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_detail_page.dart';

/// 任务详情路由分发器。
///
/// 按 [DownloaderType] 选择具体实现：
/// - Transmission → [TransmissionTaskDetailPage]（信息主页 + 子页面）
/// - qBittorrent → [QBitTaskDetailPage]（信息主页 + 子页面）
/// - Aria2 → [Aria2TaskDetailPage]（信息主页 + 子页面）
///
/// 下载器不存在时显示占位态。
class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({
    super.key,
    required this.taskId,
    required this.downloaderId,
    required this.taskName,
  });

  final String taskId;
  final String downloaderId;
  final String taskName;

  @override
  Widget build(BuildContext context) {
    final downloader =
        context.watch<DownloaderController>().getDownloader(downloaderId);

    if (downloader == null) {
      return const Scaffold(
        body: Center(child: Text('Downloader not found')),
      );
    }

    switch (downloader.type) {
      case DownloaderType.transmission:
        return TransmissionTaskDetailPage(
          taskId: taskId,
          downloaderId: downloaderId,
          taskName: taskName,
        );
      case DownloaderType.qbittorrent:
        return QBitTaskDetailPage(
          taskId: taskId,
          downloaderId: downloaderId,
          taskName: taskName,
        );
      case DownloaderType.aria2:
        return Aria2TaskDetailPage(
          taskId: taskId,
          downloaderId: downloaderId,
          taskName: taskName,
        );
    }
  }
}
