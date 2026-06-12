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
  final List<TextEditingController> _subtaskControllers = [];
  bool _subtaskFocused = false;
  bool _loading = true;
  Task? _task;
  List<Task> _subtasks = const [];

  bool get _subtaskUiVisible =>
      _subtaskFocused || _subtaskControllers.isNotEmpty;

  List<String> get _subtaskTitles =>
      SubtaskTitleEditor.nonEmptyTitles(_subtaskControllers);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repo = await ref.read(taskRepositoryProvider.future);
    final task = await repo.getById(widget.taskId);
    final subtasks =
        task != null ? await repo.getSubtasks(widget.taskId) : <Task>[];
    if (!mounted) return;
    setState(() {
      _task = task;
      _subtasks = subtasks;
      _loading = false;
    });
  }

  void _addSubtaskField() {
    setState(() => _subtaskControllers.add(TextEditingController()));
  }

  Future<int> _submitSubtaskRow(int index) async {
    setState(() {
      _subtaskControllers.insert(index + 1, TextEditingController());
    });
    return index + 1;
  }

  void _removeSubtaskField(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
    });
  }

  void _clearSubtaskFields() {
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    _subtaskControllers.clear();
  }

  void _onSubtaskFocusChanged(bool focused) {
    if (_subtaskFocused == focused) return;
    setState(() => _subtaskFocused = focused);
  }

  void _cancelSubtaskEdit() {
    _clearSubtaskFields();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _subtaskFocused = false);
  }

  Future<void> _saveDraftSubtasks() async {
    final titles = _subtaskTitles;
    if (titles.isEmpty) return;

    final repo = await ref.read(taskRepositoryProvider.future);
    try {
      for (final title in titles) {
        await repo.createSubtask(parentId: widget.taskId, title: title);
      }
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

    _clearSubtaskFields();
    FocusManager.instance.primaryFocus?.unfocus();
    await _load();
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    setState(() => _subtaskFocused = false);
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                SubtaskTitleEditor(
                  controllers: _subtaskControllers,
                  onRemove: _removeSubtaskField,
                  onAnyFieldFocusChanged: _onSubtaskFocusChanged,
                  onSubmitRow: _submitSubtaskRow,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.playlist_add_outlined, size: 20),
                    onPressed: _addSubtaskField,
                    tooltip: '添加子任务',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
              ],
            ),
          ),
          if (_subtaskUiVisible)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: _cancelSubtaskEdit,
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          _subtaskTitles.isEmpty ? null : _saveDraftSubtasks,
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
