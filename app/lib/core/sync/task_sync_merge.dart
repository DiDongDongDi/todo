import 'package:todo_app/core/models/task.dart';

/// 若应把远端任务写入本地则返回合并结果，否则 null（保留本地）。
Task? resolveRemoteTaskMerge(Task local, Task remote) {
  if (remote.syncVersion > local.syncVersion) return remote;
  if (local.syncVersion > remote.syncVersion) return null;
  if (!remote.updatedAt.isAfter(local.updatedAt)) return null;
  return reconcileRemoteWinner(local, remote);
}

/// 远端胜出时合并字段，避免服务端 updated_at 刷新但 is_starred 未写入导致丢星标。
Task reconcileRemoteWinner(Task local, Task remote) {
  if (!local.isStarred || remote.isStarred) return remote;
  return remote.copyWith(isStarred: true);
}
