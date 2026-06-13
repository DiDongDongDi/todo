import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_hierarchy.dart';
import 'package:todo_app/core/models/task_playlist.dart';

/// 将清单中的 taskId 解析为可处理的任务列表（保持清单顺序）。
List<Task> resolvePlaylistTasks({
  required TaskPlaylist playlist,
  required List<Task> inbox,
  required List<Task> someday,
}) {
  final byId = <String, Task>{
    for (final t in [...inbox, ...someday])
      if (t.status == TaskStatus.inbox || t.status == TaskStatus.someday) t.id: t,
  };

  final ordered = <Task>[];
  for (final id in playlist.taskIds) {
    final task = byId[id];
    if (task != null) ordered.add(task);
  }

  return filterQueueTasks(ordered, allInQueue: ordered);
}

/// 对任意队列任务应用子任务层级过滤。
List<Task> filterQueueTasks(
  List<Task> eligible, {
  required List<Task> allInQueue,
}) {
  if (eligible.isEmpty) return eligible;

  final byId = {for (final t in allInQueue) t.id: t};
  final parentsWithOpenSubs = <String>{};
  for (final task in eligible) {
    if (task.parentId == null &&
        hasOpenSubtasksInQueue(task, allInQueue, queueStatus: task.status)) {
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
    return hasOpenSubtasksInQueue(parent, allInQueue, queueStatus: parent.status);
  }).toList();
}

List<Task> filterSomedayTasks(List<Task> someday, {DateTime? now}) {
  final active = someday.where((t) => t.status == TaskStatus.someday).toList();
  return filterQueueTasks(active, allInQueue: active);
}
