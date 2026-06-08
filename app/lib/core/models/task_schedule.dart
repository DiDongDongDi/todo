import 'package:todo_app/core/models/task.dart';

DateTime localDate(DateTime d) => DateTime(d.year, d.month, d.day);

bool isDailyExpired(Task task, DateTime today) =>
    task.dailyUntil != null &&
    localDate(task.dailyUntil!).isBefore(localDate(today));

bool isDailyCompletedToday(Task task, DateTime today) {
  if (task.lastDailyCompletedAt == null) return false;
  final completedLocal = localDate(task.lastDailyCompletedAt!.toLocal());
  return completedLocal == localDate(today);
}

bool isDueToday(Task task, DateTime today) {
  if (task.isDaily) {
    return !isDailyExpired(task, today) && !isDailyCompletedToday(task, today);
  }
  if (task.dueDate != null) {
    return !localDate(task.dueDate!).isAfter(localDate(today));
  }
  return false;
}

bool isScheduled(Task task) => task.isDaily || task.dueDate != null;

bool shouldShowInProcess(
  Task task, {
  required bool todayOnly,
  DateTime? now,
}) {
  if (task.status != TaskStatus.inbox) return false;
  final today = now ?? DateTime.now();
  if (task.isDaily && isDailyExpired(task, today)) return false;
  if (task.isDaily && isDailyCompletedToday(task, today)) return false;
  if (todayOnly) return isDueToday(task, today);
  return true;
}

String? scheduleLabel(Task task, {DateTime? now}) {
  final today = localDate(now ?? DateTime.now());
  if (task.isDaily) {
    if (isDailyExpired(task, today)) return null;
    if (task.dailyUntil != null) {
      final until = localDate(task.dailyUntil!);
      return '每日 · 至 ${until.month}/${until.day}';
    }
    return '每日';
  }
  if (task.dueDate != null) {
    final due = localDate(task.dueDate!);
    if (due.isBefore(today)) {
      return '已逾期 · ${due.month}/${due.day}';
    }
    return '计划 · ${due.month}/${due.day}';
  }
  return null;
}
