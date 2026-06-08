import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';

/// 紧凑的任务计划配置：每日 / 每月 / 每年重复，或一次性计划日期（互斥）。
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

  static String _formatShortDate(DateTime d) => '${d.month}/${d.day}';

  Future<void> _pickDate(
    BuildContext context, {
    required DateTime? initial,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    onTransientUiOpening?.call();
    try {
      final today = localDate(DateTime.now());
      final picked = await showDatePicker(
        context: context,
        initialDate: initial ?? today,
        firstDate: today,
        lastDate: today.add(const Duration(days: 3650)),
      );
      if (picked != null) {
        onPicked(localDate(picked));
      }
    } finally {
      onTransientUiClosed?.call();
    }
  }

  void _selectRecurrence(TaskRecurrence type) {
    if (recurrence == type) {
      onRecurrenceChanged(TaskRecurrence.none);
      if (type == TaskRecurrence.daily) {
        onDailyUntilChanged(null);
      } else {
        onDueDateChanged(null);
      }
      return;
    }
    onRecurrenceChanged(type);
    if (type == TaskRecurrence.daily) {
      onDueDateChanged(null);
    } else {
      onDailyUntilChanged(null);
    }
  }

  Widget _recurrenceChip(
    BuildContext context, {
    required String label,
    required TaskRecurrence type,
  }) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label, style: theme.textTheme.labelMedium),
      selected: recurrence == type,
      onSelected: (_) => _selectRecurrence(type),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _recurrenceChip(context, label: '每日', type: TaskRecurrence.daily),
        _recurrenceChip(context, label: '每月', type: TaskRecurrence.monthly),
        _recurrenceChip(context, label: '每年', type: TaskRecurrence.yearly),
        if (recurrence == TaskRecurrence.daily)
          ActionChip(
            label: Text(
              dailyUntil == null ? '无限期' : '至 ${_formatShortDate(dailyUntil!)}',
              style: labelStyle,
            ),
            onPressed: () => _pickDate(
              context,
              initial: dailyUntil,
              onPicked: onDailyUntilChanged,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            avatar: dailyUntil != null
                ? null
                : Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.primary),
          )
        else if (recurrence == TaskRecurrence.monthly)
          ActionChip(
            label: Text(
              dueDate == null
                  ? '每月日期'
                  : '每月 ${dueDate!.day}日',
              style: labelStyle,
            ),
            onPressed: () => _pickDate(
              context,
              initial: dueDate,
              onPicked: onDueDateChanged,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            avatar: dueDate == null
                ? Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.primary)
                : null,
          )
        else if (recurrence == TaskRecurrence.yearly)
          ActionChip(
            label: Text(
              dueDate == null
                  ? '每年日期'
                  : '每年 ${_formatShortDate(dueDate!)}',
              style: labelStyle,
            ),
            onPressed: () => _pickDate(
              context,
              initial: dueDate,
              onPicked: onDueDateChanged,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            avatar: dueDate == null
                ? Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.primary)
                : null,
          )
        else
          ActionChip(
            label: Text(
              dueDate == null ? '计划日期' : '计划 ${_formatShortDate(dueDate!)}',
              style: labelStyle,
            ),
            onPressed: () => _pickDate(
              context,
              initial: dueDate,
              onPicked: onDueDateChanged,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            avatar: dueDate == null
                ? Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.primary)
                : null,
          ),
        if (recurrence == TaskRecurrence.daily && dailyUntil != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: '清除到期日',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => onDailyUntilChanged(null),
          )
        else if (recurrence != TaskRecurrence.daily && dueDate != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: recurrence == TaskRecurrence.none ? '清除计划日期' : '清除日期',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => onDueDateChanged(null),
          ),
      ],
    );
  }
}
