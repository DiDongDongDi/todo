import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/shared/widgets/process_task_search_sheet.dart';

Task _task({
  required String id,
  String? parentId,
  TaskStatus status = TaskStatus.inbox,
  String title = 'task',
  DateTime? deletedAt,
  DateTime? dueDate,
  TaskRecurrence recurrence = TaskRecurrence.none,
  DateTime? lastDailyCompletedAt,
}) {
  return Task(
    id: id,
    parentId: parentId,
    title: title,
    status: status,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    deletedAt: deletedAt,
    dueDate: dueDate,
    recurrence: recurrence,
    lastDailyCompletedAt: lastDailyCompletedAt,
  );
}

void main() {
  final today = DateTime(2026, 6, 7);

  group('shouldIncludeInSearch', () {
    test('includes inbox and someday tasks', () {
      expect(shouldIncludeInSearch(_task(id: 'a')), isTrue);
      expect(
        shouldIncludeInSearch(_task(id: 'b', status: TaskStatus.someday)),
        isTrue,
      );
    });

    test('includes period-completed recurring inbox task', () {
      final task = _task(
        id: 'r',
        recurrence: TaskRecurrence.daily,
        lastDailyCompletedAt: today,
      );
      expect(shouldIncludeInSearch(task, now: today), isTrue);
    });

    test('excludes archived, trashed, and soft-deleted tasks', () {
      expect(
        shouldIncludeInSearch(_task(id: 'a', status: TaskStatus.archived)),
        isFalse,
      );
      expect(
        shouldIncludeInSearch(_task(id: 'b', status: TaskStatus.trashed)),
        isFalse,
      );
      expect(
        shouldIncludeInSearch(
          _task(id: 'c', deletedAt: DateTime(2026, 1, 1)),
        ),
        isFalse,
      );
    });
  });

  group('resolveSearchableProcessTasks', () {
    test('merges inbox and someday without duplicates', () {
      final inbox = [_task(id: 'a'), _task(id: 'shared')];
      final someday = [
        _task(id: 'b', status: TaskStatus.someday),
        _task(id: 'shared', status: TaskStatus.someday, title: 'shared someday'),
      ];

      final result = resolveSearchableProcessTasks(inbox: inbox, someday: someday);

      expect(result.map((t) => t.id).toSet(), {'a', 'b', 'shared'});
      expect(result.length, 3);
    });

    test('excludes archived tasks from inbox list input', () {
      final inbox = [
        _task(id: 'a'),
        _task(id: 'done', status: TaskStatus.archived),
      ];

      final result = resolveSearchableProcessTasks(inbox: inbox, someday: const []);

      expect(result.map((t) => t.id), ['a']);
    });
  });

  group('taskSearchSubtitle', () {
    test('shows parent label for parent tasks', () {
      final parent = _task(id: 'p', title: 'Parent');
      final sub = _task(id: 's', parentId: 'p', title: 'Sub');
      final all = [parent, sub];

      expect(taskSearchSubtitle(parent, all), '父任务 · 1 个子任务');
    });

    test('combines parent label with schedule label', () {
      final now = DateTime(2026, 6, 1);
      final parent = _task(
        id: 'p',
        dueDate: DateTime(2026, 6, 15),
      );
      final sub = _task(id: 's', parentId: 'p');
      final all = [parent, sub];

      expect(
        taskSearchSubtitle(parent, all, now: now),
        '父任务 · 1 个子任务 · 计划 · 6/15',
      );
    });
  });
}
