import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';

/// 未启用多次打卡时的目标次数。
const int defaultCheckInTarget = 1;

/// 启用多次打卡时 UI 可选的最低次数。
const int minActiveCheckInTarget = 2;

const int maxCheckInTarget = 99;

bool hasCheckInGoal(Task task) => task.checkInTarget > 1;

bool isSameCheckInPeriod(
  TaskRecurrence recurrence,
  DateTime dateA,
  DateTime dateB,
) {
  final a = localDate(dateA);
  final b = localDate(dateB);
  switch (recurrence) {
    case TaskRecurrence.daily:
      return a == b;
    case TaskRecurrence.monthly:
      return a.year == b.year && a.month == b.month;
    case TaskRecurrence.yearly:
      return a.year == b.year;
    case TaskRecurrence.none:
      return true;
  }
}

int effectiveCheckInCount(Task task, {DateTime? now}) {
  if (task.checkInTarget <= 1) return task.checkInCount;
  if (!isRecurring(task)) return task.checkInCount;
  if (task.lastCheckInAt == null) return 0;
  final today = localDate(now ?? DateTime.now());
  if (!isSameCheckInPeriod(
    task.recurrence,
    task.lastCheckInAt!,
    today,
  )) {
    return 0;
  }
  return task.checkInCount;
}

String? checkInLabel(Task task, {DateTime? now}) {
  if (!hasCheckInGoal(task)) return null;
  final count = effectiveCheckInCount(task, now: now);
  return '打卡 $count/${task.checkInTarget}';
}

String checkInSnackbar(Task task, int newCount) {
  if (newCount >= task.checkInTarget) {
    return completeSnackbarFor(task);
  }
  return '已打卡 $newCount/${task.checkInTarget}';
}

String completeLabelForCheckIn(Task task, {DateTime? now}) {
  if (!hasCheckInGoal(task)) return completeLabelFor(task);
  final count = effectiveCheckInCount(task, now: now);
  if (count + 1 >= task.checkInTarget) {
    return completeLabelFor(task);
  }
  return '打卡';
}

enum CheckInResult { partial, finalCompletion }

CheckInResult checkInResultType(Task task, int newCount) {
  if (newCount >= task.checkInTarget) {
    return CheckInResult.finalCompletion;
  }
  return CheckInResult.partial;
}

int clampCheckInCount(int count, int target) {
  if (target < 1) return 0;
  return count.clamp(0, target);
}

bool hasResettableCheckInProgress(Task task, {DateTime? now}) {
  if (!hasCheckInGoal(task)) return false;
  if (effectiveCheckInCount(task, now: now) > 0) return true;
  return isRecurring(task) && isPeriodCompleted(task, now ?? DateTime.now());
}
