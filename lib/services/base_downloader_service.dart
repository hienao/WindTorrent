import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_speed_config.dart';
import 'package:windwalker/models/speed_config_descriptor.dart';
import 'package:windwalker/services/connection_result.dart';

/// 下载器 API 服务基类
abstract class DownloaderService {
  final Downloader downloader;

  DownloaderService(this.downloader);

  /// 测试连接（含版本校验），返回带原因的结果。
  Future<ConnectionResult> testConnection();

  /// 获取任务列表
  Future<List<DownloadTask>> getTasks();

  /// 获取全局状态
  Future<Map<String, dynamic>> getGlobalStat();

  /// 添加任务（统一入口）
  Future<String> addTask(AddTaskRequest request);

  /// 添加下载
  Future<String> addDownload(String url, {String? savePath});

  /// 暂停任务
  Future<void> pauseTask(String taskId);

  /// 恢复任务
  Future<void> resumeTask(String taskId);

  /// 删除任务
  Future<void> removeTask(String taskId, {bool deleteFiles = false});

  /// 获取速度配置
  Future<DownloaderSpeedConfig> getSpeedConfig();

  /// 设置速度配置
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config);

  /// 获取速度配置描述符 — 由各子类实现，描述自己支持哪些配置项
  SpeedConfigDescriptor getSpeedConfigDescriptor();

  /// 获取单个任务详情
  Future<DownloadTask?> getTaskDetail(String taskId);
}
