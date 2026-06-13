import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/restore_task_list.dart';

class SomedayScreen extends ConsumerWidget {
  const SomedayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(somedayTasksProvider);
    final hasTasks = tasksAsync.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('将来也许'),
        actions: [
          IconButton(
            icon: const Icon(Icons.move_to_inbox_outlined),
            tooltip: '全部移回收集箱',
            onPressed: hasTasks ? () => _restoreAll(context, ref) : null,
          ),
        ],
      ),
      body: RestoreTaskListView(
        tasksProvider: somedayTasksProvider,
        emptyMessage: '暂无将来也许的任务',
        restoreIcon: Icons.restore,
        restoreTooltip: '恢复到收集箱',
      ),
    );
  }

  Future<void> _restoreAll(BuildContext context, WidgetRef ref) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    final count = await repo.restoreAllSomedayToInbox();
    unawaited(triggerSyncIfSignedIn(ref));

    if (!context.mounted) return;
    if (count == 0) return;

    showAppSnackBar(
      context,
      message: '已全部移回收集箱',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
  }
}
