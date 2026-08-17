import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/home/presentation/pages/data_tab.dart';
import 'package:windwalker/features/home/presentation/pages/management_tab.dart';
import 'package:windwalker/features/home/presentation/pages/profile_tab.dart';
import 'package:windwalker/features/home/presentation/pages/tasks_tab.dart';
import 'package:windwalker/features/home/presentation/widgets/neo_home_shell.dart';
import 'package:windwalker/features/realtime/presentation/controllers/realtime_sync_controller.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';
import 'package:windwalker/l10n/app_localizations.dart';

class HomeTabContainer extends StatefulWidget {
  const HomeTabContainer({super.key});

  @override
  State<HomeTabContainer> createState() => _HomeTabContainerState();
}

class _HomeTabContainerState extends State<HomeTabContainer> {
  int _currentIndex = 0;
  TaskStatus? _pendingTaskStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<DownloaderController>().init();
      context.read<RealtimeSyncController>().start();
      await context.read<UpdateController>().runSilentCheck();
      await _maybeShowUpdatePrompt();
    });
  }

  Future<void> _maybeShowUpdatePrompt() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final update = context.read<UpdateController>();
    if (!update.shouldOfferUpdateDialog) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.updateAvailableTitle),
        content: Text(AppLocalizations.of(ctx)!.updateAvailableMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.later),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.updateNow),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (go == true) {
      await update.openStorePage();
      return;
    }

    update.dismissCurrentVersion();
  }

  NeoHomeFabConfig? _fabConfigForIndex(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    switch (_currentIndex) {
      case 0:
        return NeoHomeFabConfig(
          tooltip: l10n.addTaskButton,
          icon: Icons.add_rounded,
          onPressed: () => context.push(AppConstants.addTaskRoute),
        );
      case 1:
        return NeoHomeFabConfig(
          tooltip: l10n.addDownloader,
          icon: Icons.add_rounded,
          onPressed: () => context.push('/downloaders/new'),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return NeoHomeShell(
      selectedIndex: _currentIndex,
      onTabSelected: (value) => setState(() {
        if (value != 2) {
          _pendingTaskStatus = null;
        }
        _currentIndex = value;
      }),
      fabConfig: _fabConfigForIndex(context, l10n),
      tabs: [
        NeoHomeTabItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: l10n.data,
          semanticsLabel: l10n.data,
        ),
        NeoHomeTabItem(
          icon: Icons.storage_outlined,
          selectedIcon: Icons.storage_rounded,
          label: l10n.downloadersTab,
          semanticsLabel: l10n.downloadersTab,
        ),
        NeoHomeTabItem(
          icon: Icons.task_alt_outlined,
          selectedIcon: Icons.task_alt_rounded,
          label: l10n.taskList,
          semanticsLabel: l10n.taskList,
        ),
        NeoHomeTabItem(
          icon: Icons.person_outline,
          selectedIcon: Icons.person_rounded,
          label: l10n.my,
          semanticsLabel: l10n.my,
        ),
      ],
      children: [
        DataTab(
          onShowDownloaders: () => setState(() => _currentIndex = 1),
          onShowTasks: (status) => setState(() {
            _pendingTaskStatus = status;
            _currentIndex = 2;
          }),
        ),
        const ManagementTab(),
        TasksTab(initialStatus: _pendingTaskStatus),
        const ProfileTab(),
      ],
    );
  }
}
