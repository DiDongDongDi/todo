import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:uuid/uuid.dart';

class _MemoryTaskStore implements TaskStore {
  final List<Task> _tasks = [];

  @override
  Future<void> init() async {}

  @override
  Future<List<Task>> getByStatus(TaskStatus status) async {
    return _tasks
        .where((t) => t.status == status && t.deletedAt == null)
        .toList();
  }

  @override
  Stream<List<Task>> watchByStatus(TaskStatus status) async* {
    yield await getByStatus(status);
  }

  @override
  Future<Task?> getById(String id) async {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _tasks[index] = task;
    } else {
      _tasks.add(task);
    }
  }

  @override
  Future<void> delete(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<Task>> getAll() async => List.from(_tasks);
}

void main() {
  late TaskRepository repo;

  setUp(() {
    repo = TaskRepository(_MemoryTaskStore(), const Uuid());
  });

  test('createInboxWithSubtasks creates parent and subtasks', () async {
    final result = await repo.createInboxWithSubtasks(
      title: 'Parent',
      subtaskTitles: ['Sub 1', 'Sub 2', '  '],
    );

    expect(result.parent.title, 'Parent');
    expect(result.parent.parentId, isNull);
    expect(result.subtasks.length, 2);
    expect(result.subtasks.every((s) => s.parentId == result.parent.id), isTrue);

    final loaded = await repo.getSubtasks(result.parent.id);
    expect(loaded.length, 2);
    expect(loaded.map((t) => t.title), containsAll(['Sub 1', 'Sub 2']));
  });

  test('createSubtask rejects nested subtasks', () async {
    final parent = await repo.createInbox(title: 'Parent');
    final sub = await repo.createSubtask(parentId: parent.id, title: 'Sub');

    expect(
      () => repo.createSubtask(parentId: sub.id, title: 'Nested'),
      throwsStateError,
    );
  });

  test('getSubtasks returns inbox and archived subtasks', () async {
    final parent = await repo.createInbox(title: 'Parent');
    final open = await repo.createSubtask(parentId: parent.id, title: 'Open');
    final done = await repo.createSubtask(parentId: parent.id, title: 'Done');
    await repo.archive(done.id);

    final loaded = await repo.getSubtasks(parent.id);

    expect(loaded.map((t) => t.id), containsAll([open.id, done.id]));
  });

  test('getSubtasks excludes trashed subtasks', () async {
    final parent = await repo.createInbox(title: 'Parent');
    final sub = await repo.createSubtask(parentId: parent.id, title: 'Sub');
    await repo.trash(sub.id);

    final loaded = await repo.getSubtasks(parent.id);

    expect(loaded, isEmpty);
  });

  test('restoreToInbox subtask also restores parent but not siblings', () async {
    final parent = await repo.createInbox(title: 'Parent');
    final sub1 = await repo.createSubtask(parentId: parent.id, title: 'Sub 1');
    final sub2 = await repo.createSubtask(parentId: parent.id, title: 'Sub 2');

    await repo.trash(parent.id);

    await repo.restoreToInbox(sub1.id);

    final restoredParent = await repo.getById(parent.id);
    final restoredSub1 = await repo.getById(sub1.id);
    final restoredSub2 = await repo.getById(sub2.id);

    expect(restoredParent?.status, TaskStatus.inbox);
    expect(restoredSub1?.status, TaskStatus.inbox);
    expect(restoredSub2?.status, TaskStatus.trashed);
  });

  test('restoreToInbox parent restores all subtasks', () async {
    final parent = await repo.createInbox(title: 'Parent');
    final sub1 = await repo.createSubtask(parentId: parent.id, title: 'Sub 1');
    final sub2 = await repo.createSubtask(parentId: parent.id, title: 'Sub 2');

    await repo.trash(parent.id);

    await repo.restoreToInbox(parent.id);

    final restoredParent = await repo.getById(parent.id);
    final restoredSub1 = await repo.getById(sub1.id);
    final restoredSub2 = await repo.getById(sub2.id);

    expect(restoredParent?.status, TaskStatus.inbox);
    expect(restoredSub1?.status, TaskStatus.inbox);
    expect(restoredSub2?.status, TaskStatus.inbox);
  });

  test('restoreToInbox subtask only when parent still in inbox', () async {
    final parent = await repo.createInbox(title: 'Parent');
    final sub = await repo.createSubtask(parentId: parent.id, title: 'Sub');

    await repo.trash(sub.id);

    await repo.restoreToInbox(sub.id);

    final restoredParent = await repo.getById(parent.id);
    final restoredSub = await repo.getById(sub.id);

    expect(restoredParent?.status, TaskStatus.inbox);
    expect(restoredSub?.status, TaskStatus.inbox);
  });

  test('restoreToInbox parent from archive restores all archived subtasks', () async {
    final parent = await repo.createInbox(title: 'Parent');
    final sub1 = await repo.createSubtask(parentId: parent.id, title: 'Sub 1');
    final sub2 = await repo.createSubtask(parentId: parent.id, title: 'Sub 2');

    await repo.archive(parent.id);
    await repo.archive(sub1.id);
    await repo.archive(sub2.id);

    await repo.restoreToInbox(parent.id);

    final restoredParent = await repo.getById(parent.id);
    final restoredSub1 = await repo.getById(sub1.id);
    final restoredSub2 = await repo.getById(sub2.id);

    expect(restoredParent?.status, TaskStatus.inbox);
    expect(restoredSub1?.status, TaskStatus.inbox);
    expect(restoredSub2?.status, TaskStatus.inbox);
  });

  test('restoreToInbox subtask from archive restores parent but not siblings', () async {
    final parent = await repo.createInbox(title: 'Parent');
    final sub1 = await repo.createSubtask(parentId: parent.id, title: 'Sub 1');
    final sub2 = await repo.createSubtask(parentId: parent.id, title: 'Sub 2');

    await repo.archive(parent.id);
    await repo.archive(sub1.id);
    await repo.archive(sub2.id);

    await repo.restoreToInbox(sub1.id);

    final restoredParent = await repo.getById(parent.id);
    final restoredSub1 = await repo.getById(sub1.id);
    final restoredSub2 = await repo.getById(sub2.id);

    expect(restoredParent?.status, TaskStatus.inbox);
    expect(restoredSub1?.status, TaskStatus.inbox);
    expect(restoredSub2?.status, TaskStatus.archived);
  });

  group('parent schedule propagation', () {
    test('unscheduled subtasks inherit parent schedule on update', () async {
      final parent = await repo.createInbox(title: 'Parent');
      final sub = await repo.createSubtask(parentId: parent.id, title: 'Sub');

      final due = DateTime(2026, 6, 15);
      await repo.update(
        parent.copyWith(
          recurrence: TaskRecurrence.none,
          dueDate: due,
        ),
      );

      final updatedSub = await repo.getById(sub.id);
      expect(updatedSub?.recurrence, TaskRecurrence.none);
      expect(updatedSub?.dueDate, due);
    });

    test('inherited subtasks follow parent schedule change', () async {
      final due1 = DateTime(2026, 6, 1);
      final due2 = DateTime(2026, 6, 15);
      final parent = await repo.createInbox(title: 'Parent');
      final sub = await repo.createSubtask(parentId: parent.id, title: 'Sub');

      await repo.update(
        parent.copyWith(
          recurrence: TaskRecurrence.none,
          dueDate: due1,
        ),
      );

      final inherited = await repo.getById(sub.id);
      expect(inherited?.dueDate, due1);

      await repo.update(
        parent.copyWith(
          recurrence: TaskRecurrence.none,
          dueDate: due2,
        ),
      );

      final updatedSub = await repo.getById(sub.id);
      expect(updatedSub?.dueDate, due2);
    });

    test('subtask with own schedule is not overwritten', () async {
      final parentDue = DateTime(2026, 6, 1);
      final subDue = DateTime(2026, 7, 1);
      final parent = await repo.createInbox(title: 'Parent');
      final sub = await repo.createSubtask(
        parentId: parent.id,
        title: 'Sub',
        recurrence: TaskRecurrence.none,
        dueDate: subDue,
      );

      await repo.update(
        parent.copyWith(
          recurrence: TaskRecurrence.none,
          dueDate: parentDue,
        ),
      );

      final updatedSub = await repo.getById(sub.id);
      expect(updatedSub?.dueDate, subDue);
    });

    test('clearing parent schedule does not clear subtask schedule', () async {
      final due = DateTime(2026, 6, 15);
      final parent = await repo.createInbox(title: 'Parent');
      final sub = await repo.createSubtask(parentId: parent.id, title: 'Sub');

      await repo.update(
        parent.copyWith(
          recurrence: TaskRecurrence.none,
          dueDate: due,
        ),
      );

      await repo.update(
        parent.copyWith(
          recurrence: TaskRecurrence.none,
          clearDueDate: true,
        ),
      );

      final updatedSub = await repo.getById(sub.id);
      expect(updatedSub?.dueDate, due);
    });
  });

  test('reorderInboxTasks assigns descending sortOrder and persists order', () async {
    final taskA = await repo.createInbox(title: 'A');
    final taskB = await repo.createInbox(title: 'B');
    final taskC = await repo.createInbox(title: 'C');

    await repo.reorderInboxTasks([taskC, taskA, taskB]);

    final loadedC = await repo.getById(taskC.id);
    final loadedA = await repo.getById(taskA.id);
    final loadedB = await repo.getById(taskB.id);

    expect(loadedC, isNotNull);
    expect(loadedA, isNotNull);
    expect(loadedB, isNotNull);
    expect(loadedC!.sortOrder, greaterThan(loadedA!.sortOrder));
    expect(loadedA.sortOrder, greaterThan(loadedB!.sortOrder));

    final all = await repo.getAll();
    final inbox = all.where((t) => t.status == TaskStatus.inbox).toList()
      ..sort((a, b) {
        final order = b.sortOrder.compareTo(a.sortOrder);
        if (order != 0) return order;
        return b.createdAt.compareTo(a.createdAt);
      });
    expect(inbox.map((t) => t.title).toList(), ['C', 'A', 'B']);
  });
}
