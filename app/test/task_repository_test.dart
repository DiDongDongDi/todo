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
}
