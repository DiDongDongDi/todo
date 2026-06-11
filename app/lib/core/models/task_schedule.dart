import 'package:todo_app/core/models/task.dart';

DateTime localDate(DateTime d) => DateTime(d.year, d.month, d.day);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime clampDay(int year, int month, int anchorDay) {
  final day = anchorDay.clamp(1, daysInMonth(year, month));
  return DateTime(year, month, day);
}

/// 若锚点映射到当前月/年已过期，返回下一周期的首次到期日；否则 null。
DateTime? nextPeriodDueDate({
  required TaskRecurrence recurrence,
  required DateTime dueDate,
  required DateTime today,
}) {
  final t = localDate(today);
  final a = localDate(dueDate);
  late final DateTime periodDue;
  switch (recurrence) {
    case TaskRecurrence.monthly:
      periodDue = clampDay(t.year, t.month, a.day);
    case TaskRecurrence.yearly:
      periodDue = clampDay(t.year, a.month, a.day);
    case TaskRecurrence.daily:
    case TaskRecurrence.none:
      return null;
  }
  if (!t.isAfter(periodDue)) return null;
  switch (recurrence) {
    case TaskRecurrence.monthly:
      final nextMonth = DateTime(t.year, t.month + 1, 1);
      return clampDay(nextMonth.year, nextMonth.month, a.day);
    case TaskRecurrence.yearly:
      return clampDay(t.year + 1, a.month, a.day);
    case TaskRecurrence.daily:
    case TaskRecurrence.none:
      return null;
  }
}

/// 创建/编辑月年任务时，跳过已过期周期，将 dueDate 设为首次生效到期日。
DateTime? normalizeRecurringDueDate({
  required TaskRecurrence recurrence,
  required DateTime? dueDate,
  DateTime? today,
}) {
  if (dueDate == null) return null;
  if (recurrence != TaskRecurrence.monthly &&
      recurrence != TaskRecurrence.yearly) {
    return dueDate;
  }
  final t = localDate(today ?? DateTime.now());
  final next = nextPeriodDueDate(
    recurrence: recurrence,
    dueDate: dueDate,
    today: t,
  );
  return next ?? localDate(dueDate);
}

/// 月/年重复任务是否已到达首次生效到期日。
bool isRecurrenceStarted(Task task, DateTime today) {
  if (task.dueDate == null) return true;
  switch (task.recurrence) {
    case TaskRecurrence.monthly:
    case TaskRecurrence.yearly:
      return !localDate(today).isBefore(localDate(task.dueDate!));
    case TaskRecurrence.daily:
    case TaskRecurrence.none:
      return true;
  }
}

bool isRecurring(Task task) =>
    task.recurrence == TaskRecurrence.daily ||
    task.recurrence == TaskRecurrence.monthly ||
    task.recurrence == TaskRecurrence.yearly;

bool isRecurrenceExpired(Task task, DateTime today) =>
    task.dailyUntil != null &&
    localDate(task.dailyUntil!).isBefore(localDate(today));

String? _untilSuffix(DateTime? dailyUntil) {
  if (dailyUntil == null) return null;
  final until = localDate(dailyUntil);
  return ' · 至 ${until.month}/${until.day}';
}

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
      return !isRecurrenceExpired(task, today) &&
          !isDailyCompletedToday(task, today);
    case TaskRecurrence.monthly:
    case TaskRecurrence.yearly:
      if (!isRecurrenceStarted(task, today)) return false;
      if (isRecurrenceExpired(task, today)) return false;
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

int? overdueDays(Task task, DateTime today) {
  final t = localDate(today);
  switch (task.recurrence) {
    case TaskRecurrence.none:
      if (task.dueDate == null) return null;
      final due = localDate(task.dueDate!);
      if (!t.isAfter(due)) return null;
      return t.difference(due).inDays;
    case TaskRecurrence.monthly:
    case TaskRecurrence.yearly:
      if (!isRecurrenceStarted(task, today)) return null;
      final due = periodDueDate(task, today);
      if (due == null || !t.isAfter(due)) return null;
      return t.difference(due).inDays;
    case TaskRecurrence.daily:
      return null;
  }
}

bool isOverdue(Task task, {DateTime? now}) {
  final today = localDate(now ?? DateTime.now());
  return overdueDays(task, today) != null;
}

bool shouldIncludeInSearch(Task task, {DateTime? now}) {
  if (task.status != TaskStatus.inbox) return false;
  final today = now ?? DateTime.now();
  if (isRecurring(task) && isPeriodCompleted(task, today)) return false;
  return true;
}

bool shouldShowInProcess(
  Task task, {
  required bool todayOnly,
  DateTime? now,
}) {
  if (task.status != TaskStatus.inbox) return false;
  final today = now ?? DateTime.now();
  if (isRecurring(task) && isRecurrenceExpired(task, today)) {
    return false;
  }
  if (isRecurring(task) && isPeriodCompleted(task, today)) return false;
  if (todayOnly) return isDueToday(task, today);
  if (isScheduled(task)) return isDueToday(task, today);
  return true;
}

/// 计划编辑器入口 Chip 的摘要文案（未设置时显示「计划」）。
String scheduleEditorSummary({
  required TaskRecurrence recurrence,
  required DateTime? dailyUntil,
  required DateTime? dueDate,
}) {
  switch (recurrence) {
    case TaskRecurrence.daily:
      return '每日${_untilSuffix(dailyUntil) ?? ''}';
    case TaskRecurrence.monthly:
      if (dueDate == null) return '每月${_untilSuffix(dailyUntil) ?? ''}';
      return '每月 · ${localDate(dueDate).day}日${_untilSuffix(dailyUntil) ?? ''}';
    case TaskRecurrence.yearly:
      if (dueDate == null) return '每年${_untilSuffix(dailyUntil) ?? ''}';
      final anchor = localDate(dueDate);
      return '每年 · ${anchor.month}/${anchor.day}${_untilSuffix(dailyUntil) ?? ''}';
    case TaskRecurrence.none:
      if (dueDate != null) {
        final due = localDate(dueDate);
        return '计划 · ${due.month}/${due.day}';
      }
      return '计划';
  }
}

String? completedScheduleLabel(Task task) {
  switch (task.recurrence) {
    case TaskRecurrence.daily:
      return '每日 · 今日已完成';
    case TaskRecurrence.monthly:
      return '每月 · 本月已完成';
    case TaskRecurrence.yearly:
      return '每年 · 今年已完成';
    case TaskRecurrence.none:
      if (task.dueDate != null) {
        final due = localDate(task.dueDate!);
        return '计划 · ${due.month}/${due.day}';
      }
      return null;
  }
}

String? scheduleLabel(Task task, {DateTime? now}) {
  final today = localDate(now ?? DateTime.now());
  if (isRecurring(task) && isPeriodCompleted(task, today)) return null;
  if ((task.recurrence == TaskRecurrence.monthly ||
          task.recurrence == TaskRecurrence.yearly) &&
      !isRecurrenceStarted(task, today)) {
    return null;
  }
  final overdue = overdueDays(task, today);
  if (overdue != null) return '已逾期 $overdue 天';

  switch (task.recurrence) {
    case TaskRecurrence.daily:
      if (isRecurrenceExpired(task, today)) return null;
      return '每日${_untilSuffix(task.dailyUntil) ?? ''}';
    case TaskRecurrence.monthly:
      if (isRecurrenceExpired(task, today)) return null;
      if (task.dueDate == null) return null;
      final monthlyAnchor = localDate(task.dueDate!);
      return '每月 · ${monthlyAnchor.day}日${_untilSuffix(task.dailyUntil) ?? ''}';
    case TaskRecurrence.yearly:
      if (isRecurrenceExpired(task, today)) return null;
      if (task.dueDate == null) return null;
      final yearlyAnchor = localDate(task.dueDate!);
      return '每年 · ${yearlyAnchor.month}/${yearlyAnchor.day}${_untilSuffix(task.dailyUntil) ?? ''}';
    case TaskRecurrence.none:
      if (task.dueDate != null) {
        final due = localDate(task.dueDate!);
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
