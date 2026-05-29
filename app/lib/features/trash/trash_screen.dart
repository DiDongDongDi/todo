import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/repositories/task_repository.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(trashedTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('回收站是空的'));
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
                    icon: const Icon(Icons.restore),
                    tooltip: '恢复',
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
