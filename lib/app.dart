import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/theme/app_theme.dart';
import 'package:windwalker/core/router/app_router.dart';
import 'package:windwalker/core/utils/app_version.dart';
import 'package:windwalker/features/backup/data/file_picker_backup_file_api.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/realtime/presentation/controllers/realtime_sync_controller.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_controller.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_backup_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/features/tasks/presentation/controllers/transmission_task_detail_controller.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/services/downloader_backup_service.dart';

void main() {
  runApp(const WindTorrentApp());
}

/// 应用入口
/// 按照 flutter-managing-state skill 规范使用 Provider
/// 按照 flutter-implementing-navigation-and-routing skill 规范使用 go_router
class WindTorrentApp extends StatelessWidget {
  const WindTorrentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 提供 TaskDomainStore 作为任务域单一事实来源
        // （snapshot、标准化任务、速度与任务数量摘要）
        ChangeNotifierProvider(create: (_) => TaskDomainStore()),
        // 下载器配置与连接状态的全 App 单一事实来源
        ChangeNotifierProvider(create: (_) => DownloaderController()),
        // 提供 TaskController 作为全局状态
        // qBit / Transmission 共享任务读取委托给 TaskDomainStore（attach 后）
        ChangeNotifierProxyProvider<TaskDomainStore, TaskController>(
          create: (_) => TaskController(),
          update: (_, taskDomainStore, previous) {
            final controller = previous ?? TaskController();
            controller.attachTaskDomainStore(taskDomainStore);
            return controller;
          },
        ),
        // 提供 RealtimeSyncController 作为全局状态
        // （唯一持有 timer 的层，接管 qBit / Transmission 全局轮询）
        // 任务结果写入 TaskDomainStore，连接状态写入 DownloaderController
        ChangeNotifierProxyProvider2<
          DownloaderController,
          TaskDomainStore,
          RealtimeSyncController
        >(
          create: (_) => RealtimeSyncController(),
          update: (_, downloaderController, taskDomainStore, previous) {
            final controller = previous ?? RealtimeSyncController();
            controller.attach(downloaderController: downloaderController);
            controller.attachStore(taskDomainStore);
            return controller;
          },
        ),
        // 提供 TransmissionTaskDetailController 作为全局状态
        // （Transmission 详情页的完整详情加载态；其它下载器详情页不使用）
        ChangeNotifierProvider(
          create: (_) => TransmissionTaskDetailController(),
        ),
        // 提供 UpdateController 作为全局状态（依赖 TaskController 的活跃下载状态）
        ChangeNotifierProxyProvider<TaskController, UpdateController>(
          create: (_) => UpdateController(),
          update: (_, taskController, updateController) {
            updateController ??= UpdateController(
              taskController: taskController,
            );
            updateController.attachTaskController(taskController);
            return updateController;
          },
        ),
        // 提供 SettingsController 作为全局状态
        ChangeNotifierProvider(create: (_) => SettingsController()),
        // 提供 SettingsBackupController 作为全局状态（依赖 DownloaderController）
        ChangeNotifierProxyProvider<
          DownloaderController,
          SettingsBackupController
        >(
          create: (_) => SettingsBackupController(),
          update: (_, downloader, previous) {
            final controller = previous ?? SettingsBackupController();
            controller.attach(
              backupService: DownloaderBackupService(
                fileApi: const FilePickerBackupFileApi(),
                downloaderController: downloader,
                currentAppVersion: () async {
                  final info = await AppVersion.info();
                  return info.version;
                },
              ),
              downloaderController: downloader,
            );
            return controller;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final settings = context.watch<SettingsController>();

          return MaterialApp.router(
            title: AppConstants.appName,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.effectiveThemeMode,
            // 国际化配置
            locale: settings.effectiveLocale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('zh'), Locale('ja')],
            // 使用 go_router
            routerConfig: appRouter,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
