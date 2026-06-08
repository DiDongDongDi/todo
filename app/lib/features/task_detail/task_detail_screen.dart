import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/save_template_dialog.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _subtaskController = TextEditingController();
  bool _loading = true;
  Task? _task;
  List<Task> _subtasks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = await ref.read(taskRepositoryProvider.future);
    final task = await repo.getById(widget.taskId);
    final subtasks = task != null ? await repo.getSubtasks(widget.taskId) : <Task>[];
    if (!mounted) return;
    setState(() {
      _task = task;
      _subtasks = subtasks;
      _loading = false;
    });
  }

  Future<void> _addSubtask() async {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;

    final repo = await ref.read(taskRepositoryProvider.future);
    try {
      await repo.createSubtask(parentId: widget.taskId, title: title);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '无法添加子任务',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
      return;
    }

    _subtaskController.clear();
    await _load();
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已添加子任务',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
  }

  Future<void> _saveAsTemplate() async {
    final task = _task;
    if (task == null) return;

    final name = await showSaveTemplateDialog(
      context,
      defaultTitle: task.title,
    );
    if (name == null || !mounted) return;

    final templateRepo = await ref.read(templateRepositoryProvider.future);
    await templateRepo.saveFromTask(task.id, titleOverride: name);
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已保存为模板',
      icon: Icons.bookmark_outline,
      type: AppSnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final task = _task;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('任务不存在')),
      );
    }

    final completedCount =
        _subtasks.where((t) => t.status == TaskStatus.archived).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('父任务'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: '保存为模板',
            onPressed: _saveAsTemplate,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            task.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (scheduleLabel(task) != null) ...[
            const SizedBox(height: 8),
            Text(
              scheduleLabel(task)!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isOverdue(task)
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
          if (task.note != null && task.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(task.note!),
          ],
          if (_subtasks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '子任务 $completedCount/${_subtasks.length} 已完成',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._subtasks.map((sub) {
              final done = sub.status == TaskStatus.archived;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(
                  sub.title,
                  style: done
                      ? TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        )
                      : null,
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          Text(
            '添加子任务',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subtaskController,
                  decoration: const InputDecoration(
                    hintText: '子任务标题',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addSubtask(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addSubtask,
                child: const Text('添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
