import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/repositories/task_repository.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

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
              return Card(
                child: ListTile(
                  title: Text(task.title),
                  subtitle: task.note != null ? Text(task.note!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: '恢复到收集箱',
                    onPressed: () async {
                      final repo =
                          await ref.read(taskRepositoryProvider.future);
                      await repo.restoreToInbox(task.id);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
