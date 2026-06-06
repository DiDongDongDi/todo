import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/swipeable_restore_tile.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  void _showRestoredSnackBar(BuildContext context) {
    showAppSnackBar(
      context,
      message: '已恢复',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(archivedTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('已完成')),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('暂无已完成任务'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return SwipeableRestoreTile(
                key: ValueKey(task.id),
                task: task,
                restoreIcon: Icons.undo,
                restoreTooltip: '恢复到收集箱',
                onRestore: () async {
                  final repo = await ref.read(taskRepositoryProvider.future);
                  await repo.restoreToInbox(task.id);
                  await triggerSyncIfSignedIn(ref);
                  if (context.mounted) {
                    _showRestoredSnackBar(context);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
