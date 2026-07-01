import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/sync/task_sync_merge.dart';

Task _task({
  required String id,
  int syncVersion = 1,
  DateTime? updatedAt,
  bool isStarred = false,
}) {
  final updated = updatedAt ?? DateTime(2026, 1, 1);
  return Task(
    id: id,
    title: 't',
    status: TaskStatus.inbox,
    createdAt: updated,
    updatedAt: updated,
    syncVersion: syncVersion,
    isStarred: isStarred,
  );
}

void main() {
  test('remote with higher sync_version wins', () {
    final local = _task(id: '1', syncVersion: 2, isStarred: true);
    final remote = _task(
      id: '1',
      syncVersion: 3,
      updatedAt: DateTime(2026, 1, 2),
      isStarred: false,
    );

    expect(resolveRemoteTaskMerge(local, remote), remote);
  });

  test('local with higher sync_version is kept', () {
    final local = _task(id: '1', syncVersion: 4, isStarred: true);
    final remote = _task(
      id: '1',
      syncVersion: 3,
      updatedAt: DateTime(2026, 6, 1),
      isStarred: false,
    );

    expect(resolveRemoteTaskMerge(local, remote), isNull);
  });

  test('remote updated_at wins but preserves local is_starred', () {
    final local = _task(
      id: '1',
      syncVersion: 5,
      updatedAt: DateTime(2026, 1, 1),
      isStarred: true,
    );
    final remote = _task(
      id: '1',
      syncVersion: 5,
      updatedAt: DateTime(2026, 1, 2),
      isStarred: false,
    );

    final merged = resolveRemoteTaskMerge(local, remote);
    expect(merged, isNotNull);
    expect(merged!.isStarred, isTrue);
    expect(merged.updatedAt, remote.updatedAt);
  });
}
