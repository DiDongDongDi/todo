import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';

bool hasOpenSubtasks(
  Task parent,
  Iterable<Task> all, {
  required bool todayOnly,
  DateTime? now,
}) {
  return all.any(
    (t) =>
        t.parentId == parent.id &&
        t.status == TaskStatus.inbox &&
        shouldShowInProcess(t, todayOnly: todayOnly, now: now),
  );
}

Task? parentOf(Task task, Map<String, Task> byId) {
  final parentId = task.parentId;
  if (parentId == null) return null;
  return byId[parentId];
}

/// 返回至少有一条未软删子任务的父任务 id 集合。
Set<String> parentIdsWithSubtasks(Iterable<Task> all) {
  return all
      .where((t) => t.parentId != null && t.deletedAt == null)
      .map((t) => t.parentId!)
      .toSet();
}

int countSubtasks(String parentId, Iterable<Task> all) {
  return all.where((t) => t.parentId == parentId && t.deletedAt == null).length;
}

String parentTaskSubtitleLabel(Task task, Iterable<Task> all) {
  final count = countSubtasks(task.id, all);
  return '父任务 · $count 个子任务';
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
