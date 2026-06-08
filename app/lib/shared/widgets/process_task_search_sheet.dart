import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/core/models/task_schedule.dart';

List<Task> filterTasksForSearch(List<Task> tasks, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return tasks;

  final lower = trimmed.toLowerCase();
  return tasks.where((task) {
    if (task.displayTitle.toLowerCase().contains(lower)) return true;
    final note = task.note;
    if (note != null && note.toLowerCase().contains(lower)) return true;
    return false;
  }).toList();
}

Future<Task?> showProcessTaskSearchSheet(
  BuildContext context, {
  required List<Task> tasks,
  required String? currentTaskId,
}) {
  return showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ProcessTaskSearchSheet(
      tasks: tasks,
      currentTaskId: currentTaskId,
    ),
  );
}

class _ProcessTaskSearchSheet extends StatefulWidget {
  const _ProcessTaskSearchSheet({
    required this.tasks,
    required this.currentTaskId,
  });

  final List<Task> tasks;
  final String? currentTaskId;

  @override
  State<_ProcessTaskSearchSheet> createState() => _ProcessTaskSearchSheetState();
}

class _ProcessTaskSearchSheetState extends State<_ProcessTaskSearchSheet> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() {
      setState(() => _query = _queryController.text);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = filterTasksForSearch(widget.tasks, _query);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _queryController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索任务',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _query.trim().isEmpty ? '暂无任务' : '没有匹配的任务',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final task = filtered[index];
                        final isCurrent = task.id == widget.currentTaskId;
                        final subtitle = scheduleLabel(task);

                        return ListTile(
                          title: Text(task.displayTitle),
                          subtitle: subtitle != null ? Text(subtitle) : null,
                          selected: isCurrent,
                          trailing: isCurrent
                              ? Icon(
                                  Icons.check,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, task),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
