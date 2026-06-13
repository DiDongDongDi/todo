import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_hierarchy.dart';

Task _task({
  required String id,
  String? parentId,
  TaskStatus status = TaskStatus.inbox,
  String title = 'task',
}) {
  return Task(
    id: id,
    parentId: parentId,
    title: title,
    status: status,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  final today = DateTime(2026, 6, 7);

  group('hasOpenSubtasks', () {
    test('true when parent has inbox subtask', () {
      final parent = _task(id: 'p');
      final sub = _task(id: 's', parentId: 'p');
      expect(
        hasOpenSubtasks(parent, [parent, sub], todayOnly: false, now: today),
        isTrue,
      );
    });

    test('false when subtask is archived', () {
      final parent = _task(id: 'p');
      final sub = _task(id: 's', parentId: 'p', status: TaskStatus.archived);
      expect(
        hasOpenSubtasks(parent, [parent, sub], todayOnly: false, now: today),
        isFalse,
      );
    });

    test('false when subtask is trashed', () {
      final parent = _task(id: 'p');
      final sub = _task(id: 's', parentId: 'p', status: TaskStatus.trashed);
      expect(
        hasOpenSubtasks(parent, [parent, sub], todayOnly: false, now: today),
        isFalse,
      );
    });
  });

  group('filterProcessTasks', () {
    test('hides parent and shows open subtasks', () {
      final parent = _task(id: 'p', title: 'Parent');
      final sub1 = _task(id: 's1', parentId: 'p', title: 'Sub 1');
      final sub2 = _task(id: 's2', parentId: 'p', title: 'Sub 2');
      final inbox = [parent, sub1, sub2];

      final result = filterProcessTasks(inbox, todayOnly: false, now: today);

      expect(result.map((t) => t.id), ['s1', 's2']);
    });

    test('shows parent when all subtasks archived', () {
      final parent = _task(id: 'p', title: 'Parent');
      final sub1 = _task(id: 's1', parentId: 'p', status: TaskStatus.archived);
      final inbox = [parent, sub1];

      final result = filterProcessTasks(inbox, todayOnly: false, now: today);

      expect(result.map((t) => t.id), ['p']);
    });

    test('shows parent when all subtasks trashed', () {
      final parent = _task(id: 'p', title: 'Parent');
      final sub1 = _task(id: 's1', parentId: 'p', status: TaskStatus.trashed);
      final sub2 = _task(id: 's2', parentId: 'p', status: TaskStatus.trashed);
      final inbox = [parent, sub1, sub2];

      final result = filterProcessTasks(inbox, todayOnly: false, now: today);

      expect(result.map((t) => t.id), ['p']);
    });

    test('hides completed subtask when parent has no open subs', () {
      final parent = _task(id: 'p');
      final sub = _task(id: 's', parentId: 'p', status: TaskStatus.archived);
      final inbox = [parent, sub];

      final result = filterProcessTasks(inbox, todayOnly: false, now: today);

      expect(result.map((t) => t.id), ['p']);
    });

    test('tasks without subtasks pass through', () {
      final task = _task(id: 't');
      final result = filterProcessTasks([task], todayOnly: false, now: today);
      expect(result.length, 1);
      expect(result.first.id, 't');
    });
  });

  group('parentIdsWithSubtasks', () {
    test('includes parent with inbox subtask', () {
      final parent = _task(id: 'p');
      final sub = _task(id: 's', parentId: 'p');
      expect(parentIdsWithSubtasks([parent, sub]), {'p'});
    });

    test('includes parent with trashed subtask', () {
      final parent = _task(id: 'p', status: TaskStatus.trashed);
      final sub = _task(id: 's', parentId: 'p', status: TaskStatus.trashed);
      expect(parentIdsWithSubtasks([parent, sub]), {'p'});
    });

    test('excludes standalone task', () {
      final task = _task(id: 't');
      expect(parentIdsWithSubtasks([task]), isEmpty);
    });
  });

  group('countSubtasks and parentTaskSubtitleLabel', () {
    test('counts active subtasks across statuses', () {
      final parent = _task(id: 'p');
      final sub1 = _task(id: 's1', parentId: 'p');
      final sub2 = _task(id: 's2', parentId: 'p', status: TaskStatus.trashed);
      final all = [parent, sub1, sub2];

      expect(countSubtasks('p', all), 2);
      expect(parentTaskSubtitleLabel(parent, all), '父任务 · 2 个子任务');
    });
  });
}
