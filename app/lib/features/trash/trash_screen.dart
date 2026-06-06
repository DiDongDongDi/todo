import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/shared/widgets/restore_task_list.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: RestoreTaskListView(
        tasksProvider: trashedTasksProvider,
        emptyMessage: '回收站是空的',
        restoreIcon: Icons.restore,
        restoreTooltip: '恢复',
      ),
    );
  }
}
