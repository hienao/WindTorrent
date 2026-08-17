import 'package:flutter/material.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/features/home/presentation/pages/all_tasks_tab_page.dart';

class TasksTab extends StatelessWidget {
  final TaskStatus? initialStatus;

  const TasksTab({super.key, this.initialStatus});

  @override
  Widget build(BuildContext context) {
    return AllTasksTabPage(initialStatus: initialStatus);
  }
}
