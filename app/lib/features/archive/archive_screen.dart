import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/shared/widgets/restore_task_list.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('已完成')),
      body: RestoreTaskListView(
        tasksProvider: archivedTasksProvider,
        emptyMessage: '暂无已完成任务',
        restoreIcon: Icons.undo,
        restoreTooltip: '恢复到收集箱',
      ),
    );
  }
}
