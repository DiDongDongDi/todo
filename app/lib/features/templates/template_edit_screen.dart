import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/models/task_template.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/task_schedule_editor.dart';

class TemplateEditScreen extends ConsumerStatefulWidget {
  const TemplateEditScreen({super.key, required this.templateId});

  final String templateId;

  @override
  ConsumerState<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends ConsumerState<TemplateEditScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _subtaskControllers = <TextEditingController>[];

  bool _loading = true;
  TaskTemplate? _template;
  bool _isDaily = false;
  DateTime? _dailyUntil;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await ref.read(templateRepositoryProvider.future);
    final template = await repo.getById(widget.templateId);
    if (!mounted) return;

    if (template != null) {
      _titleController.text = template.title;
      _noteController.text = template.note ?? '';
      _isDaily = template.isDaily;
      _dailyUntil = template.dailyUntil;
      _dueDate = template.dueDate;
      for (final title in template.subtaskTitles) {
        _subtaskControllers.add(TextEditingController(text: title));
      }
    }

    setState(() {
      _template = template;
      _loading = false;
    });
  }

  void _addSubtaskField() {
    setState(() => _subtaskControllers.add(TextEditingController()));
  }

  void _removeSubtaskField(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
    });
  }

  Future<void> _save() async {
    final template = _template;
    if (template == null) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showAppSnackBar(
        context,
        message: '请输入模板标题',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
      return;
    }

    setState(() => _saving = true);
    final repo = await ref.read(templateRepositoryProvider.future);
    await repo.update(
      template.copyWith(
        title: title,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        isDaily: _isDaily,
        dailyUntil: _dailyUntil,
        dueDate: _isDaily ? null : _dueDate,
        clearNote: _noteController.text.trim().isEmpty,
        clearDailyUntil: _isDaily && _dailyUntil == null,
        clearDueDate: _isDaily || _dueDate == null,
        subtaskTitles: _subtaskControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
      ),
    );
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    setState(() => _saving = false);
    showAppSnackBar(
      context,
      message: '模板已保存',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
  }

  Future<void> _createTask() async {
    await _save();
    final repo = await ref.read(templateRepositoryProvider.future);
    final created = await repo.createTasksFromTemplate(widget.templateId);
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已创建 ${created.length} 个任务',
      icon: Icons.check_circle_outline,
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

    if (_template == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('模板不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑模板'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '备注',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TaskScheduleEditor(
            isDaily: _isDaily,
            dailyUntil: _dailyUntil,
            dueDate: _dueDate,
            onDailyChanged: (value) => setState(() => _isDaily = value),
            onDailyUntilChanged: (value) =>
                setState(() => _dailyUntil = value),
            onDueDateChanged: (value) => setState(() => _dueDate = value),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                '子任务',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addSubtaskField,
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
          ...List.generate(_subtaskControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskControllers[index],
                      decoration: InputDecoration(
                        hintText: '子任务 ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeSubtaskField(index),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _createTask,
            child: const Text('创建任务'),
          ),
        ],
      ),
    );
  }
}
