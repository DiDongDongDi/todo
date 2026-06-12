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
  bool _loading = true;
  bool _editingSubtasks = false;
  Task? _task;
  List<Task> _subtasks = const [];
  List<Task> _subtaskSnapshot = const [];
  final List<TextEditingController> _editSubtaskControllers = [];
  final List<String?> _editSubtaskIds = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clearEditSubtaskFields();
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

  void _clearEditSubtaskFields() {
    for (final c in _editSubtaskControllers) {
      c.dispose();
    }
    _editSubtaskControllers.clear();
    _editSubtaskIds.clear();
  }

  void _enterSubtaskEdit({bool addEmptyRow = false}) {
    _clearEditSubtaskFields();
    _subtaskSnapshot = List.from(_subtasks);
    for (final sub in _subtasks) {
      _editSubtaskControllers.add(TextEditingController(text: sub.title));
      _editSubtaskIds.add(sub.id);
    }
    if (addEmptyRow && _editSubtaskControllers.isEmpty) {
      _editSubtaskControllers.add(TextEditingController());
      _editSubtaskIds.add(null);
    }
    setState(() => _editingSubtasks = true);
  }

  void _addEditSubtaskField() {
    setState(() {
      _editSubtaskControllers.add(TextEditingController());
      _editSubtaskIds.add(null);
    });
  }

  void _removeEditSubtaskField(int index) {
    setState(() {
      _editSubtaskControllers[index].dispose();
      _editSubtaskControllers.removeAt(index);
      _editSubtaskIds.removeAt(index);
    });
  }

  void _cancelSubtaskEdit() {
    _clearEditSubtaskFields();
    setState(() {
      _editingSubtasks = false;
      _subtaskSnapshot = const [];
    });
  }

  Future<void> _saveSubtaskEdit() async {
    final repo = await ref.read(taskRepositoryProvider.future);
    final snapshotById = {for (final s in _subtaskSnapshot) s.id: s};
    final currentIds = _editSubtaskIds.whereType<String>().toSet();

    try {
      for (final id in snapshotById.keys) {
        if (!currentIds.contains(id)) {
          await repo.trash(id);
        }
      }

      for (var i = 0; i < _editSubtaskControllers.length; i++) {
        final title = _editSubtaskControllers[i].text.trim();
        final id = _editSubtaskIds[i];

        if (id == null) {
          if (title.isNotEmpty) {
            await repo.createSubtask(parentId: widget.taskId, title: title);
          }
          continue;
        }

        if (title.isEmpty) {
          await repo.trash(id);
          continue;
        }

        final original = snapshotById[id];
        if (original != null && original.title != title) {
          await repo.update(original.copyWith(title: title));
        }
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '无法保存子任务',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
      return;
    }

    _clearEditSubtaskFields();
    setState(() {
      _editingSubtasks = false;
      _subtaskSnapshot = const [];
    });
    await _load();
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已保存子任务',
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

  Widget _buildSubtaskToolbar(BuildContext context) {
    const compact = VisualDensity.compact;
    const gap = SizedBox(width: 4);

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: _addEditSubtaskField,
          icon: const Icon(Icons.playlist_add_outlined),
          tooltip: '添加子任务',
          visualDensity: compact,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _cancelSubtaskEdit,
          style: TextButton.styleFrom(
            visualDensity: compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('取消'),
        ),
        gap,
        Focus(
          canRequestFocus: false,
          child: FilledButton(
            onPressed: _saveSubtaskEdit,
            style: FilledButton.styleFrom(
              visualDensity: compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtaskSection(BuildContext context) {
    if (_editingSubtasks) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          SubtaskTitleEditor(
            controllers: _editSubtaskControllers,
            onRemove: _removeEditSubtaskField,
          ),
          const SizedBox(height: 16),
          _buildSubtaskToolbar(context),
        ],
      );
    }

    if (_subtasks.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          SubtaskListSection(subtasks: _subtasks),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _enterSubtaskEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('编辑子任务'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          '暂无子任务',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _enterSubtaskEdit(addEmptyRow: true),
            icon: const Icon(Icons.playlist_add_outlined, size: 18),
            label: const Text('添加子任务'),
          ),
        ),
      ],
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
          _buildSubtaskSection(context),
        ],
      ),
    );
  }
}
