import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';

Future<void> showTaskScheduleSheet(
  BuildContext context, {
  required TaskRecurrence recurrence,
  required DateTime? dailyUntil,
  required DateTime? dueDate,
  required ValueChanged<TaskRecurrence> onRecurrenceChanged,
  required ValueChanged<DateTime?> onDailyUntilChanged,
  required ValueChanged<DateTime?> onDueDateChanged,
  VoidCallback? onTransientUiOpening,
  VoidCallback? onTransientUiClosed,
}) async {
  onTransientUiOpening?.call();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TaskScheduleSheet(
        initialRecurrence: recurrence,
        initialDailyUntil: dailyUntil,
        initialDueDate: dueDate,
        onTransientUiOpening: onTransientUiOpening,
        onTransientUiClosed: onTransientUiClosed,
        onCommit: (nextRecurrence, nextDailyUntil, nextDueDate) {
          if (nextRecurrence != recurrence) {
            onRecurrenceChanged(nextRecurrence);
          }
          if (nextDailyUntil != dailyUntil) {
            onDailyUntilChanged(nextDailyUntil);
          }
          if (nextDueDate != dueDate) {
            onDueDateChanged(nextDueDate);
          }
        },
      ),
    );
  } finally {
    onTransientUiClosed?.call();
  }
}

class _TaskScheduleSheet extends StatefulWidget {
  const _TaskScheduleSheet({
    required this.initialRecurrence,
    required this.initialDailyUntil,
    required this.initialDueDate,
    required this.onCommit,
    this.onTransientUiOpening,
    this.onTransientUiClosed,
  });

  final TaskRecurrence initialRecurrence;
  final DateTime? initialDailyUntil;
  final DateTime? initialDueDate;
  final void Function(
    TaskRecurrence recurrence,
    DateTime? dailyUntil,
    DateTime? dueDate,
  ) onCommit;
  final VoidCallback? onTransientUiOpening;
  final VoidCallback? onTransientUiClosed;

  @override
  State<_TaskScheduleSheet> createState() => _TaskScheduleSheetState();
}

class _TaskScheduleSheetState extends State<_TaskScheduleSheet> {
  late TaskRecurrence _recurrence;
  DateTime? _dailyUntil;
  DateTime? _dueDate;

  static String _formatShortDate(DateTime d) => '${d.month}/${d.day}';

  @override
  void initState() {
    super.initState();
    _recurrence = widget.initialRecurrence;
    _dailyUntil = widget.initialDailyUntil;
    _dueDate = widget.initialDueDate;
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    widget.onTransientUiOpening?.call();
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
      widget.onTransientUiClosed?.call();
    }
  }

  void _setRecurrence(TaskRecurrence type) {
    setState(() {
      _recurrence = type;
      if (type == TaskRecurrence.daily) {
        _dueDate = null;
      } else if (type == TaskRecurrence.none) {
        _dailyUntil = null;
        _dueDate = null;
      }
    });
  }

  void _clearPlan() {
    setState(() {
      _recurrence = TaskRecurrence.none;
      _dailyUntil = null;
      _dueDate = null;
    });
  }

  void _commit() {
    widget.onCommit(_recurrence, _dailyUntil, _dueDate);
    Navigator.pop(context);
  }

  Widget _buildUnlimitedUntilSection() {
    final unlimited = _dailyUntil == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('无限期'),
          value: unlimited,
          onChanged: (value) {
            setState(() {
              _dailyUntil = value ? null : localDate(DateTime.now());
            });
          },
        ),
        if (!unlimited)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('到期日'),
            subtitle: Text(_formatShortDate(localDate(_dailyUntil!))),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '改为无限期',
              onPressed: () => setState(() => _dailyUntil = null),
            ),
            onTap: () => _pickDate(
              initial: _dailyUntil,
              onPicked: (value) => setState(() => _dailyUntil = value),
            ),
          ),
      ],
    );
  }

  Widget _buildDateSection(ThemeData theme) {
    switch (_recurrence) {
      case TaskRecurrence.none:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: const Text('计划日期'),
          subtitle: Text(
            _dueDate == null
                ? '未选择'
                : _formatShortDate(localDate(_dueDate!)),
          ),
          trailing: _dueDate != null
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: '清除日期',
                  onPressed: () => setState(() => _dueDate = null),
                )
              : const Icon(Icons.chevron_right),
          onTap: () => _pickDate(
            initial: _dueDate,
            onPicked: (value) => setState(() => _dueDate = value),
          ),
        );
      case TaskRecurrence.daily:
        return _buildUnlimitedUntilSection();
      case TaskRecurrence.monthly:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('每月几号'),
              subtitle: Text(
                _dueDate == null ? '未选择' : '每月 ${localDate(_dueDate!).day} 日',
              ),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: '清除日期',
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => _pickDate(
                initial: _dueDate,
                onPicked: (value) => setState(() => _dueDate = value),
              ),
            ),
            _buildUnlimitedUntilSection(),
          ],
        );
      case TaskRecurrence.yearly:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('每年日期'),
              subtitle: Text(
                _dueDate == null
                    ? '未选择'
                    : _formatShortDate(localDate(_dueDate!)),
              ),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: '清除日期',
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => _pickDate(
                initial: _dueDate,
                onPicked: (value) => setState(() => _dueDate = value),
              ),
            ),
            _buildUnlimitedUntilSection(),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('计划设置', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('重复周期', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          RadioListTile<TaskRecurrence>(
            contentPadding: EdgeInsets.zero,
            title: const Text('一次性'),
            value: TaskRecurrence.none,
            groupValue: _recurrence,
            onChanged: (value) {
              if (value != null) _setRecurrence(value);
            },
          ),
          RadioListTile<TaskRecurrence>(
            contentPadding: EdgeInsets.zero,
            title: const Text('每日'),
            value: TaskRecurrence.daily,
            groupValue: _recurrence,
            onChanged: (value) {
              if (value != null) _setRecurrence(value);
            },
          ),
          RadioListTile<TaskRecurrence>(
            contentPadding: EdgeInsets.zero,
            title: const Text('每月'),
            value: TaskRecurrence.monthly,
            groupValue: _recurrence,
            onChanged: (value) {
              if (value != null) _setRecurrence(value);
            },
          ),
          RadioListTile<TaskRecurrence>(
            contentPadding: EdgeInsets.zero,
            title: const Text('每年'),
            value: TaskRecurrence.yearly,
            groupValue: _recurrence,
            onChanged: (value) {
              if (value != null) _setRecurrence(value);
            },
          ),
          const SizedBox(height: 8),
          Text('日期', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          _buildDateSection(theme),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _commit,
            child: const Text('完成'),
          ),
          TextButton(
            onPressed: _clearPlan,
            child: const Text('清除计划'),
          ),
        ],
      ),
    );
  }
}
