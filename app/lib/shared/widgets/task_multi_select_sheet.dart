import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/shared/widgets/process_task_search_sheet.dart';

Future<List<Task>?> showTaskMultiSelectSheet(
  BuildContext context, {
  required List<Task> tasks,
  List<String> initialSelectedIds = const [],
}) {
  return showModalBottomSheet<List<Task>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _TaskMultiSelectSheet(
      tasks: tasks,
      initialSelectedIds: initialSelectedIds,
    ),
  );
}

class _TaskMultiSelectSheet extends StatefulWidget {
  const _TaskMultiSelectSheet({
    required this.tasks,
    required this.initialSelectedIds,
  });

  final List<Task> tasks;
  final List<String> initialSelectedIds;

  @override
  State<_TaskMultiSelectSheet> createState() => _TaskMultiSelectSheetState();
}

class _TaskMultiSelectSheetState extends State<_TaskMultiSelectSheet> {
  final _queryController = TextEditingController();
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _confirm() {
    final selected = widget.tasks
        .where((t) => _selectedIds.contains(t.id))
        .toList();
    if (selected.isEmpty) return;
    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final filtered = filterTasksForSearch(widget.tasks, _queryController.text);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('选择任务', style: theme.textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    hintText: '搜索任务…',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          widget.tasks.isEmpty ? '暂无可选任务' : '没有匹配的任务',
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final task = filtered[index];
                          final selected = _selectedIds.contains(task.id);
                          final statusLabel =
                              task.status == TaskStatus.someday ? '将来也许' : '收集箱';
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIds.add(task.id);
                                } else {
                                  _selectedIds.remove(task.id);
                                }
                              });
                            },
                            title: Text(task.displayTitle),
                            subtitle: Text(statusLabel),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _selectedIds.isEmpty ? null : _confirm,
                      child: Text('确认 (${_selectedIds.length})'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
