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

  group('taskDetailAppBarTitle', () {
    test('subtask title', () {
      final sub = _task(id: 's', parentId: 'p');
      expect(taskDetailAppBarTitle(sub, subtaskCount: 0), '子任务');
    });

    test('parent title', () {
      final parent = _task(id: 'p');
      expect(taskDetailAppBarTitle(parent, subtaskCount: 2), '父任务');
    });

    test('standalone title', () {
      final task = _task(id: 't');
      expect(taskDetailAppBarTitle(task, subtaskCount: 0), '任务详情');
    });
  });

  group('taskDetailDeleteDialogTitle', () {
    test('subtask delete title', () {
      final sub = _task(id: 's', parentId: 'p');
      expect(taskDetailDeleteDialogTitle(sub, subtaskCount: 0), '删除子任务');
    });

    test('parent delete title', () {
      final parent = _task(id: 'p');
      expect(taskDetailDeleteDialogTitle(parent, subtaskCount: 2), '删除父任务');
    });

    test('standalone delete title', () {
      final task = _task(id: 't');
      expect(taskDetailDeleteDialogTitle(task, subtaskCount: 0), '删除任务');
    });
  });

  group('taskSchedulesEqual', () {
    test('true when all schedule fields match', () {
      final due = DateTime(2026, 6, 1);
      final a = _task(id: 'a').copyWith(
        recurrence: TaskRecurrence.monthly,
        dueDate: due,
        dailyUntil: DateTime(2026, 12, 31),
      );
      final b = _task(id: 'b').copyWith(
        recurrence: TaskRecurrence.monthly,
        dueDate: due,
        dailyUntil: DateTime(2026, 12, 31),
      );
      expect(taskSchedulesEqual(a, b), isTrue);
    });

    test('false when dueDate differs', () {
      final a = _task(id: 'a').copyWith(
        recurrence: TaskRecurrence.none,
        dueDate: DateTime(2026, 6, 1),
      );
      final b = _task(id: 'b').copyWith(
        recurrence: TaskRecurrence.none,
        dueDate: DateTime(2026, 6, 15),
      );
      expect(taskSchedulesEqual(a, b), isFalse);
    });
  });

  group('subtaskShouldInheritParentSchedule', () {
    test('true when sub has no schedule', () {
      final sub = _task(id: 's', parentId: 'p');
      final parent = _task(id: 'p').copyWith(
        recurrence: TaskRecurrence.none,
        dueDate: DateTime(2026, 6, 1),
      );
      expect(subtaskShouldInheritParentSchedule(sub, parent), isTrue);
    });

    test('true when sub schedule matches parent before', () {
      final due = DateTime(2026, 6, 1);
      final parent = _task(id: 'p').copyWith(
        recurrence: TaskRecurrence.none,
        dueDate: due,
      );
      final sub = _task(id: 's', parentId: 'p').copyWith(
        recurrence: TaskRecurrence.none,
        dueDate: due,
      );
      expect(subtaskShouldInheritParentSchedule(sub, parent), isTrue);
    });

    test('false when sub has own schedule', () {
      final parent = _task(id: 'p').copyWith(
        recurrence: TaskRecurrence.none,
        dueDate: DateTime(2026, 6, 1),
      );
      final sub = _task(id: 's', parentId: 'p').copyWith(
        recurrence: TaskRecurrence.none,
        dueDate: DateTime(2026, 7, 1),
      );
      expect(subtaskShouldInheritParentSchedule(sub, parent), isFalse);
    });
  });

  group('applyParentSchedule', () {
    test('copies parent schedule to sub', () {
      final parent = _task(id: 'p').copyWith(
        recurrence: TaskRecurrence.none,
        dueDate: DateTime(2026, 6, 15),
      );
      final sub = _task(id: 's', parentId: 'p');
      final result = applyParentSchedule(sub, parent);
      expect(result.recurrence, TaskRecurrence.none);
      expect(result.dueDate, DateTime(2026, 6, 15));
    });
  });
}
