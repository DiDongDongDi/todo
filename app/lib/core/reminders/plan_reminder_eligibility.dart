import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/reminders/plan_reminder_constants.dart';

/// 可参与计划提醒的任务状态（收集箱 + 将来也许）。
bool isPlanReminderEligibleStatus(TaskStatus status) =>
    status == TaskStatus.inbox || status == TaskStatus.someday;

/// 是否应在通知栏显示持久提醒（无计划星标立即 show；有计划则计划日零点起或 App 打开时 show）。
bool shouldShowPlanReminder(Task task, DateTime now) {
  if (!task.isStarred) return false;
  if (!isPlanReminderEligibleStatus(task.status)) return false;
  if (!isScheduled(task)) return true;
  if (isRecurring(task) && isPeriodCompleted(task, now)) return false;
  return isDueToday(task, now);
}

/// 是否应参与提醒调度（含未来到期日的预约）。
bool shouldSchedulePlanReminder(Task task, DateTime now) {
  if (!task.isStarred) return false;
  if (!isPlanReminderEligibleStatus(task.status)) return false;
  if (!isScheduled(task)) return true;
  if (isRecurrenceExpired(task, now)) return false;
  if (isRecurring(task) && isPeriodCompleted(task, now)) {
    return _hasFutureReminder(task, now);
  }
  if (shouldShowPlanReminder(task, now)) return true;
  return _hasFutureReminder(task, now);
}

bool _hasFutureReminder(Task task, DateTime now) {
  final today = localDate(now);
  switch (task.recurrence) {
    case TaskRecurrence.none:
      if (task.dueDate == null) return false;
      return localDate(task.dueDate!).isAfter(today);
    case TaskRecurrence.daily:
      return !isRecurrenceExpired(task, now);
    case TaskRecurrence.monthly:
    case TaskRecurrence.yearly:
      if (!isRecurrenceStarted(task, now)) {
        return task.dueDate != null;
      }
      if (isPeriodCompleted(task, now)) {
        return nextPeriodDueDate(
              recurrence: task.recurrence,
              dueDate: task.dueDate!,
              today: today,
            ) !=
            null;
      }
      return false;
  }
}

/// 下一次应触发提醒的本地时间（计划日 00:00）；无计划星标任务返回 null 以立即 show。
DateTime? nextPlanReminderAt(Task task, DateTime now) {
  if (!shouldSchedulePlanReminder(task, now)) return null;
  if (!isScheduled(task)) return null;

  final today = localDate(now);
  DateTime atReminderTime(DateTime date) => DateTime(
        date.year,
        date.month,
        date.day,
        planReminderHour,
        planReminderMinute,
      );

  if (shouldShowPlanReminder(task, now)) return null;

  switch (task.recurrence) {
    case TaskRecurrence.none:
      if (task.dueDate == null) return null;
      final due = localDate(task.dueDate!);
      if (due.isAfter(today)) return atReminderTime(due);
      return null;
    case TaskRecurrence.daily:
      final tomorrow = today.add(const Duration(days: 1));
      return atReminderTime(tomorrow);
    case TaskRecurrence.monthly:
    case TaskRecurrence.yearly:
      if (task.dueDate == null) return null;
      if (!isRecurrenceStarted(task, now)) {
        return atReminderTime(localDate(task.dueDate!));
      }
      if (isPeriodCompleted(task, now)) {
        final next = nextPeriodDueDate(
          recurrence: task.recurrence,
          dueDate: task.dueDate!,
          today: today,
        );
        if (next != null) return atReminderTime(next);
      }
      return null;
  }
}
