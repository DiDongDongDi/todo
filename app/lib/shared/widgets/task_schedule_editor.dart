import 'dart:async';

import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/widgets/task_schedule_sheet.dart';

/// 任务计划配置入口：点击打开底部面板设置一次性 / 每日 / 每月 / 每年计划。
class TaskScheduleEditor extends StatelessWidget {
  const TaskScheduleEditor({
    super.key,
    required this.recurrence,
    required this.dailyUntil,
    required this.dueDate,
    required this.onRecurrenceChanged,
    required this.onDailyUntilChanged,
    required this.onDueDateChanged,
    this.onTransientUiOpening,
    this.onTransientUiClosed,
  });

  final TaskRecurrence recurrence;
  final DateTime? dailyUntil;
  final DateTime? dueDate;
  final ValueChanged<TaskRecurrence> onRecurrenceChanged;
  final ValueChanged<DateTime?> onDailyUntilChanged;
  final ValueChanged<DateTime?> onDueDateChanged;
  final VoidCallback? onTransientUiOpening;
  final VoidCallback? onTransientUiClosed;

  Future<void> _openSheet(BuildContext context) {
    return showTaskScheduleSheet(
      context,
      recurrence: recurrence,
      dailyUntil: dailyUntil,
      dueDate: dueDate,
      onRecurrenceChanged: onRecurrenceChanged,
      onDailyUntilChanged: onDailyUntilChanged,
      onDueDateChanged: onDueDateChanged,
      onTransientUiOpening: onTransientUiOpening,
      onTransientUiClosed: onTransientUiClosed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = scheduleEditorSummary(
      recurrence: recurrence,
      dailyUntil: dailyUntil,
      dueDate: dueDate,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        label: Text(label, style: theme.textTheme.labelMedium),
        avatar: Icon(
          Icons.event_outlined,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        onPressed: () {
          unawaited(AppHaptics.light());
          _openSheet(context);
        },
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
