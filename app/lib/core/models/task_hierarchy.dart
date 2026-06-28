import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';

bool _datesEqual(DateTime? a, DateTime? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return localDate(a) == localDate(b);
}

/// 比较两个任务的计划字段（recurrence、dueDate、dailyUntil）。
bool taskSchedulesEqual(Task a, Task b) {
  return a.recurrence == b.recurrence &&
      _datesEqual(a.dueDate, b.dueDate) &&
      _datesEqual(a.dailyUntil, b.dailyUntil);
}

/// 子任务是否应随父任务计划变更而继承（未单独设置或与父任务旧计划一致）。
bool subtaskShouldInheritParentSchedule(Task sub, Task parentBefore) {
  return !isScheduled(sub) || taskSchedulesEqual(sub, parentBefore);
}

/// 将父任务计划复制到子任务，复用与 createInbox 相同的规范化逻辑。
Task applyParentSchedule(Task sub, Task parent) {
  final editDue =
      parent.recurrence == TaskRecurrence.daily ? null : parent.dueDate;
  final normalizedDue = normalizeRecurringDueDate(
    recurrence: parent.recurrence,
    dueDate: editDue,
  );
  return sub.copyWith(
    recurrence: parent.recurrence,
    dailyUntil:
        parent.recurrence != TaskRecurrence.none ? parent.dailyUntil : null,
    dueDate: normalizedDue,
    clearDailyUntil:
        parent.recurrence == TaskRecurrence.none || parent.dailyUntil == null,
    clearDueDate: parent.recurrence == TaskRecurrence.daily || editDue == null,
  );
}

bool hasOpenSubtasks(
  Task parent,
  Iterable<Task> all, {
  required bool todayOnly,
  DateTime? now,
}) {
  return hasOpenSubtasksInQueue(
    parent,
    all,
    queueStatus: TaskStatus.inbox,
    todayOnly: todayOnly,
    now: now,
  );
}

bool hasOpenSubtasksInQueue(
  Task parent,
  Iterable<Task> all, {
  required TaskStatus queueStatus,
  bool todayOnly = false,
  DateTime? now,
}) {
  return all.any(
    (t) =>
        t.parentId == parent.id &&
        t.status == queueStatus &&
        (queueStatus == TaskStatus.someday
            ? true
            : shouldShowInProcess(t, todayOnly: todayOnly, now: now)),
  );
}

Task? parentOf(Task task, Map<String, Task> byId) {
  final parentId = task.parentId;
  if (parentId == null) return null;
  return byId[parentId];
}

/// 可管理子任务：inbox / someday / archived，排除 trashed 与软删。
bool isManagedSubtask(Task task) {
  if (task.parentId == null) return false;
  if (task.deletedAt != null) return false;
  return task.status != TaskStatus.trashed;
}

/// 返回至少有一条可管理子任务的父任务 id 集合。
Set<String> parentIdsWithSubtasks(Iterable<Task> all) {
  return all
      .where(isManagedSubtask)
      .map((t) => t.parentId!)
      .toSet();
}

int countSubtasks(String parentId, Iterable<Task> all) {
  return all
      .where((t) => t.parentId == parentId && isManagedSubtask(t))
      .length;
}

String parentTaskSubtitleLabel(Task task, Iterable<Task> all) {
  final count = countSubtasks(task.id, all);
  return '父任务 · $count 个子任务';
}

String taskDetailAppBarTitle(Task task, {required int subtaskCount}) {
  if (task.isSubtask) return '子任务';
  if (subtaskCount > 0) return '父任务';
  return '任务详情';
}

String taskDetailDeleteDialogTitle(Task task, {required int subtaskCount}) {
  if (task.isSubtask) return '删除子任务';
  if (subtaskCount > 0) return '删除父任务';
  return '删除任务';
}

List<Task> filterProcessTasks(
  List<Task> inbox, {
  required bool todayOnly,
  DateTime? now,
}) {
  final eligible = inbox
      .where((t) => shouldShowInProcess(t, todayOnly: todayOnly, now: now))
      .toList();

  final byId = {for (final t in inbox) t.id: t};
  final parentsWithOpenSubs = <String>{};
  for (final task in eligible) {
    if (task.parentId == null &&
        hasOpenSubtasks(task, inbox, todayOnly: todayOnly, now: now)) {
      parentsWithOpenSubs.add(task.id);
    }
  }

  return eligible.where((task) {
    if (task.parentId == null) {
      return !parentsWithOpenSubs.contains(task.id);
    }
    final parentId = task.parentId!;
    final parent = byId[parentId];
    if (parent == null) return true;
    return hasOpenSubtasks(parent, inbox, todayOnly: todayOnly, now: now);
  }).toList();
}
