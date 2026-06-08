import 'package:todo_app/core/models/task.dart';

DateTime localDate(DateTime d) => DateTime(d.year, d.month, d.day);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime clampDay(int year, int month, int anchorDay) {
  final day = anchorDay.clamp(1, daysInMonth(year, month));
  return DateTime(year, month, day);
}

bool isRecurring(Task task) =>
    task.recurrence == TaskRecurrence.daily ||
    task.recurrence == TaskRecurrence.monthly ||
    task.recurrence == TaskRecurrence.yearly;

bool isDailyExpired(Task task, DateTime today) =>
    task.dailyUntil != null &&
    localDate(task.dailyUntil!).isBefore(localDate(today));

bool isDailyCompletedToday(Task task, DateTime today) {
  if (task.lastDailyCompletedAt == null) return false;
  final completedLocal = localDate(task.lastDailyCompletedAt!.toLocal());
  return completedLocal == localDate(today);
}

DateTime? periodDueDate(Task task, DateTime today) {
  final anchor = task.dueDate;
  if (anchor == null) return null;
  final t = localDate(today);
  final a = localDate(anchor);
  switch (task.recurrence) {
    case TaskRecurrence.monthly:
      return clampDay(t.year, t.month, a.day);
    case TaskRecurrence.yearly:
      return clampDay(t.year, a.month, a.day);
    case TaskRecurrence.daily:
    case TaskRecurrence.none:
      return null;
  }
}

bool isPeriodCompleted(Task task, DateTime today) {
  if (task.lastDailyCompletedAt == null) return false;
  final completed = localDate(task.lastDailyCompletedAt!.toLocal());
  final t = localDate(today);
  switch (task.recurrence) {
    case TaskRecurrence.daily:
      return completed == t;
    case TaskRecurrence.monthly:
      return completed.year == t.year && completed.month == t.month;
    case TaskRecurrence.yearly:
      return completed.year == t.year;
    case TaskRecurrence.none:
      return false;
  }
}

bool isDueToday(Task task, DateTime today) {
  final t = localDate(today);
  switch (task.recurrence) {
    case TaskRecurrence.daily:
      return !isDailyExpired(task, today) && !isDailyCompletedToday(task, today);
    case TaskRecurrence.monthly:
    case TaskRecurrence.yearly:
      final due = periodDueDate(task, today);
      if (due == null) return false;
      return !t.isBefore(due) && !isPeriodCompleted(task, today);
    case TaskRecurrence.none:
      if (task.dueDate != null) {
        return !localDate(task.dueDate!).isAfter(t);
      }
      return false;
  }
}

bool isScheduled(Task task) =>
    task.recurrence != TaskRecurrence.none || task.dueDate != null;

bool shouldShowInProcess(
  Task task, {
  required bool todayOnly,
  DateTime? now,
}) {
  if (task.status != TaskStatus.inbox) return false;
  final today = now ?? DateTime.now();
  if (task.recurrence == TaskRecurrence.daily && isDailyExpired(task, today)) {
    return false;
  }
  if (isRecurring(task) && isPeriodCompleted(task, today)) return false;
  if (todayOnly) return isDueToday(task, today);
  return true;
}

String? scheduleLabel(Task task, {DateTime? now}) {
  final today = localDate(now ?? DateTime.now());
  switch (task.recurrence) {
    case TaskRecurrence.daily:
      if (isDailyExpired(task, today)) return null;
      if (task.dailyUntil != null) {
        final until = localDate(task.dailyUntil!);
        return '每日 · 至 ${until.month}/${until.day}';
      }
      return '每日';
    case TaskRecurrence.monthly:
      if (task.dueDate == null) return null;
      final anchor = localDate(task.dueDate!);
      final due = periodDueDate(task, today);
      if (due != null && today.isAfter(due)) {
        return '已逾期 · 每月 ${anchor.day}日';
      }
      return '每月 · ${anchor.day}日';
    case TaskRecurrence.yearly:
      if (task.dueDate == null) return null;
      final anchor = localDate(task.dueDate!);
      final due = periodDueDate(task, today);
      if (due != null && today.isAfter(due)) {
        return '已逾期 · 每年 ${anchor.month}/${anchor.day}';
      }
      return '每年 · ${anchor.month}/${anchor.day}';
    case TaskRecurrence.none:
      if (task.dueDate != null) {
        final due = localDate(task.dueDate!);
        if (due.isBefore(today)) {
          return '已逾期 · ${due.month}/${due.day}';
        }
        return '计划 · ${due.month}/${due.day}';
      }
      return null;
  }
}

String completeLabelFor(Task task) {
  switch (task.recurrence) {
    case TaskRecurrence.daily:
      return '今日完成';
    case TaskRecurrence.monthly:
      return '本月完成';
    case TaskRecurrence.yearly:
      return '今年完成';
    case TaskRecurrence.none:
      return '完成';
  }
}

String completeSnackbarFor(Task task) {
  switch (task.recurrence) {
    case TaskRecurrence.daily:
      return '今日已完成';
    case TaskRecurrence.monthly:
      return '本月已完成';
    case TaskRecurrence.yearly:
      return '今年已完成';
    case TaskRecurrence.none:
      return '已完成';
  }
}
