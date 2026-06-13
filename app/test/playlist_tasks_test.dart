import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/playlist_tasks.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_playlist.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/settings/process_queue_source_settings.dart';

Task _task({
  required String id,
  String title = 't',
  TaskStatus status = TaskStatus.inbox,
  String? parentId,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Task(
    id: id,
    title: title,
    status: status,
    createdAt: now,
    updatedAt: now,
    parentId: parentId,
  );
}

void main() {
  group('resolvePlaylistTasks', () {
    test('keeps playlist order and skips archived', () {
      final inbox = [
        _task(id: 'a', title: 'A'),
        _task(id: 'b', title: 'B', status: TaskStatus.archived),
        _task(id: 'c', title: 'C'),
      ];
      final someday = [_task(id: 'd', title: 'D', status: TaskStatus.someday)];
      final playlist = TaskPlaylist(
        id: 'p1',
        title: '清单',
        taskIds: ['d', 'b', 'a', 'missing'],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final result = resolvePlaylistTasks(
        playlist: playlist,
        inbox: inbox,
        someday: someday,
      );

      expect(result.map((t) => t.id), ['d', 'a']);
    });
  });

  group('resolveProcessQueueTasks', () {
    test('daily filters to today due only', () {
      final now = DateTime(2026, 6, 13);
      final inbox = [
        _task(
          id: 'due-today',
          title: '今日到期',
        ).copyWith(dueDate: DateTime(2026, 6, 13)),
        _task(
          id: 'future',
          title: '未来',
        ).copyWith(
          recurrence: TaskRecurrence.monthly,
          dueDate: DateTime(2026, 12, 1),
        ),
      ];

      final daily = resolveProcessQueueTasks(
        source: const ProcessQueueSource(kind: ProcessQueueKind.daily),
        inbox: inbox,
        someday: const [],
        playlists: const [],
        now: now,
      );

      expect(daily.map((t) => t.id), ['due-today']);
    });

    test('playlist resolves referenced tasks', () {
      final inbox = [_task(id: 'x'), _task(id: 'y')];
      final playlists = [
        TaskPlaylist(
          id: 'pl',
          title: '测试',
          taskIds: ['y', 'x'],
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ];

      final result = resolveProcessQueueTasks(
        source: ProcessQueueSource(
          kind: ProcessQueueKind.playlist,
          playlistId: 'pl',
        ),
        inbox: inbox,
        someday: const [],
        playlists: playlists,
      );

      expect(result.map((t) => t.id), ['y', 'x']);
    });
  });
}
