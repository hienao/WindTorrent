import 'package:go_router/go_router.dart';
import 'package:windwalker/features/home/presentation/pages/home_tab_container.dart';
import 'package:windwalker/features/tasks/presentation/pages/tasks_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/task_detail_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/aria2/aria2_task_files_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/aria2/aria2_task_servers_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/aria2/aria2_task_peers_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/aria2/aria2_task_options_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_files_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_options_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_peers_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/qbit/qbit_task_sources_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_files_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_trackers_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_peers_page.dart';
import 'package:windwalker/features/tasks/presentation/pages/transmission/transmission_task_options_page.dart';
import 'package:windwalker/features/add_task/presentation/pages/add_task_page.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_config_page.dart';
import 'package:windwalker/features/downloaders/presentation/pages/downloader_editor_page.dart';
import 'package:windwalker/features/settings/presentation/pages/about_page.dart';
import 'package:windwalker/features/settings/presentation/pages/settings_page.dart';
import 'package:windwalker/features/settings/presentation/pages/webdav_config_page.dart';
import 'package:windwalker/features/startup/presentation/pages/startup_page.dart';
import 'package:windwalker/core/constants/app_constants.dart';

final appRouter = GoRouter(
  initialLocation: '/startup',
  routes: [
    GoRoute(
      path: '/startup',
      name: 'startup',
      builder: (context, state) => const StartupPage(),
    ),
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeTabContainer(),
    ),
    GoRoute(
      path: '/tasks',
      name: 'tasks',
      builder: (context, state) {
        final downloaderId = state.uri.queryParameters['id'];
        final downloaderTypeStr = state.uri.queryParameters['type'];
        final downloaderType = downloaderTypeStr != null
            ? DownloaderType.values.firstWhere(
                (e) => e.name == downloaderTypeStr,
                orElse: () => DownloaderType.aria2,
              )
            : null;
        return TasksPage(
          downloaderId: downloaderId,
          downloaderType: downloaderType,
        );
      },
      routes: [
        GoRoute(
          path: 'detail/:id',
          name: 'task-detail',
          builder: (context, state) {
            final taskId = state.pathParameters['id']!;
            final downloaderId =
                state.uri.queryParameters['downloaderId'] ?? '';
            final taskName = state.uri.queryParameters['taskName'] ?? '';
            return TaskDetailPage(
              taskId: taskId,
              downloaderId: downloaderId,
              taskName: taskName,
            );
          },
          routes: [
            GoRoute(
              path: 'aria2/files',
              name: 'aria2-task-files',
              builder: (context, state) => Aria2TaskFilesPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'aria2/servers',
              name: 'aria2-task-servers',
              builder: (context, state) => Aria2TaskServersPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'aria2/peers',
              name: 'aria2-task-peers',
              builder: (context, state) => Aria2TaskPeersPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'aria2/options',
              name: 'aria2-task-options',
              builder: (context, state) => Aria2TaskOptionsPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'qbit/files',
              name: 'qbit-task-files',
              builder: (context, state) => QBitTaskFilesPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'qbit/sources',
              name: 'qbit-task-sources',
              builder: (context, state) => QBitTaskSourcesPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'qbit/peers',
              name: 'qbit-task-peers',
              builder: (context, state) => QBitTaskPeersPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'qbit/options',
              name: 'qbit-task-options',
              builder: (context, state) => QBitTaskOptionsPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'transmission/files',
              name: 'transmission-task-files',
              builder: (context, state) => TransmissionTaskFilesPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'transmission/trackers',
              name: 'transmission-task-trackers',
              builder: (context, state) => TransmissionTaskTrackersPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'transmission/peers',
              name: 'transmission-task-peers',
              builder: (context, state) => TransmissionTaskPeersPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
            GoRoute(
              path: 'transmission/options',
              name: 'transmission-task-options',
              builder: (context, state) => TransmissionTaskOptionsPage(
                taskId: state.pathParameters['id']!,
                downloaderId: state.uri.queryParameters['downloaderId'] ?? '',
                taskName: state.uri.queryParameters['taskName'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/add-task',
      name: 'add-task',
      builder: (context, state) {
        final initialUrl = state.uri.queryParameters['url'];
        return AddTaskPage(initialUrl: initialUrl);
      },
    ),
    GoRoute(
      path: '/downloaders/new',
      name: 'downloader-create',
      builder: (context, state) => const DownloaderEditorPage(),
    ),
    GoRoute(
      path: '/downloaders/:id/edit',
      name: 'downloader-edit',
      builder: (context, state) =>
          DownloaderEditorPage(downloaderId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/downloaders/:id/config',
      name: 'downloader-config',
      builder: (context, state) =>
          DownloaderConfigPage(downloaderId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
      routes: [
        GoRoute(
          path: 'webdav',
          name: 'settings-webdav',
          builder: (context, state) => const WebDavConfigPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (context, state) => const AboutPage(),
    ),
  ],
);
