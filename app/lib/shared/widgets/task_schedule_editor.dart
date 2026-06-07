import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task_schedule.dart';

/// 紧凑的任务计划配置：每日重复 / 一次性计划日期（互斥）。
class TaskScheduleEditor extends StatelessWidget {
  const TaskScheduleEditor({
    super.key,
    required this.isDaily,
    required this.dailyUntil,
    required this.dueDate,
    required this.onDailyChanged,
    required this.onDailyUntilChanged,
    required this.onDueDateChanged,
    this.onTransientUiOpening,
    this.onTransientUiClosed,
  });

  final bool isDaily;
  final DateTime? dailyUntil;
  final DateTime? dueDate;
  final ValueChanged<bool> onDailyChanged;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: Text('每日', style: labelStyle),
          selected: isDaily,
          onSelected: (value) {
            onDailyChanged(value);
            if (value) onDueDateChanged(null);
          },
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        if (isDaily)
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
        if (isDaily && dailyUntil != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: '清除到期日',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => onDailyUntilChanged(null),
          )
        else if (!isDaily && dueDate != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: '清除计划日期',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => onDueDateChanged(null),
          ),
      ],
    );
  }
}
