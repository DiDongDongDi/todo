import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/core/models/task_hierarchy.dart';
import 'package:todo_app/core/models/task_schedule.dart';

List<Task> filterTasksForSearch(List<Task> tasks, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return tasks;

  final lower = trimmed.toLowerCase();
  return tasks.where((task) {
    return task.displayTitle.toLowerCase().contains(lower);
  }).toList();
}

String? taskSearchSubtitle(Task task, Iterable<Task> all, {DateTime? now}) {
  final parts = <String>[];
  if (parentIdsWithSubtasks(all).contains(task.id)) {
    parts.add(parentTaskSubtitleLabel(task, all));
  }
  final schedule = scheduleLabel(task, now: now);
  if (schedule != null) {
    parts.add(schedule);
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

TextStyle? taskSearchInputStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium;
}

InputDecoration taskSearchInputDecoration(
  BuildContext context, {
  String hintText = '搜索任务',
}) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hintText,
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
    ),
    prefixIcon: const Icon(Icons.search),
    border: const OutlineInputBorder(),
    isDense: true,
  );
}

Future<Task?> showProcessTaskSearchSheet(
  BuildContext context, {
  required List<Task> tasks,
  required List<Task> allTasks,
  required String? currentTaskId,
}) {
  return showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _ProcessTaskSearchSheet(
      tasks: tasks,
      allTasks: allTasks,
      currentTaskId: currentTaskId,
    ),
  );
}

class _ProcessTaskSearchSheet extends StatefulWidget {
  const _ProcessTaskSearchSheet({
    required this.tasks,
    required this.allTasks,
    required this.currentTaskId,
  });

  final List<Task> tasks;
  final List<Task> allTasks;
  final String? currentTaskId;

  @override
  State<_ProcessTaskSearchSheet> createState() => _ProcessTaskSearchSheetState();
}

class _ProcessTaskSearchSheetState extends State<_ProcessTaskSearchSheet> {
  final _queryController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleFocusAfterSheetAnimation();
    });
  }

  void _scheduleFocusAfterSheetAnimation() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _searchFocusNode.requestFocus();
      return;
    }

    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(onStatus);
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      }
    }

    animation.addStatusListener(onStatus);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _queryController,
                  focusNode: _searchFocusNode,
                  style: taskSearchInputStyle(context),
                  decoration: taskSearchInputDecoration(context),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _queryController,
                  builder: (context, value, _) {
                    final query = value.text;
                    final filtered = filterTasksForSearch(widget.tasks, query);

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          query.trim().isEmpty ? '暂无任务' : '没有匹配的任务',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final task = filtered[index];
                        final isCurrent = task.id == widget.currentTaskId;
                        final subtitle = taskSearchSubtitle(task, widget.allTasks);

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
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
