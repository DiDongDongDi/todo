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
import 'package:todo_app/shared/widgets/subtask_editor.dart';

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
          if (_subtasks.isNotEmpty) ...[
            const SizedBox(height: 24),
            SubtaskListSection(subtasks: _subtasks),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    style: subtaskTitleInputStyle(context),
                    decoration: subtaskTitleInputDecoration(context),
                    onSubmitted: (_) => _addSubtask(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add_outlined, size: 20),
                  onPressed: _addSubtask,
                  tooltip: '添加子任务',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
