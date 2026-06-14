import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_check_in.dart';
import 'package:todo_app/core/models/task_schedule.dart';
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

Task _task({
  TaskRecurrence recurrence = TaskRecurrence.none,
  int checkInTarget = 1,
  int checkInCount = 0,
  DateTime? lastCheckInAt,
  DateTime? lastDailyCompletedAt,
}) {
  return Task(
    id: '1',
    title: 'test',
    status: TaskStatus.inbox,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    recurrence: recurrence,
    checkInTarget: checkInTarget,
    checkInCount: checkInCount,
    lastCheckInAt: lastCheckInAt,
    lastDailyCompletedAt: lastDailyCompletedAt,
  );
}

void main() {
  late TaskRepository repo;

  setUp(() {
    repo = TaskRepository(_MemoryTaskStore(), const Uuid());
  });

  group('effectiveCheckInCount', () {
    test('resets across daily periods', () {
      final task = _task(
        recurrence: TaskRecurrence.daily,
        checkInTarget: 3,
        checkInCount: 2,
        lastCheckInAt: DateTime(2026, 6, 6),
      );
      expect(
        effectiveCheckInCount(task, now: DateTime(2026, 6, 7)),
        0,
      );
    });

    test('keeps count within same daily period', () {
      final task = _task(
        recurrence: TaskRecurrence.daily,
        checkInTarget: 3,
        checkInCount: 2,
        lastCheckInAt: DateTime(2026, 6, 7),
      );
      expect(
        effectiveCheckInCount(task, now: DateTime(2026, 6, 7, 18)),
        2,
      );
    });
  });

  group('checkIn repository', () {
    test('non-recurring task archives after target check-ins', () async {
      final created = await repo.createInbox(
        title: 'Read book',
        checkInTarget: 3,
      );

      final first = await repo.checkIn(created.id);
      expect(first.result, CheckInResult.partial);
      expect(first.task.status, TaskStatus.inbox);
      expect(first.task.checkInCount, 1);

      final second = await repo.checkIn(created.id);
      expect(second.result, CheckInResult.partial);
      expect(second.task.checkInCount, 2);

      final third = await repo.checkIn(created.id);
      expect(third.result, CheckInResult.finalCompletion);
      expect(third.task.status, TaskStatus.archived);
      expect(third.task.checkInCount, 3);
    });

    test('daily recurring task completes period after target check-ins', () async {
      final created = await repo.createInbox(
        title: 'Drink water',
        recurrence: TaskRecurrence.daily,
        checkInTarget: 3,
      );

      await repo.checkIn(created.id);
      final second = await repo.checkIn(created.id);
      expect(second.task.status, TaskStatus.inbox);
      expect(second.task.checkInCount, 2);

      final third = await repo.checkIn(created.id);
      expect(third.result, CheckInResult.finalCompletion);
      expect(third.task.status, TaskStatus.inbox);
      expect(third.task.checkInCount, 0);
      expect(third.task.lastDailyCompletedAt, isNotNull);
      expect(
        isPeriodCompleted(third.task, DateTime.now()),
        isTrue,
      );
    });

    test('target 1 non-recurring archives immediately', () async {
      final created = await repo.createInbox(title: 'Simple');
      final result = await repo.checkIn(created.id);
      expect(result.result, CheckInResult.finalCompletion);
      expect(result.task.status, TaskStatus.archived);
    });

    test('target 1 recurring completes period immediately', () async {
      final created = await repo.createInbox(
        title: 'Daily',
        recurrence: TaskRecurrence.daily,
      );
      final result = await repo.checkIn(created.id);
      expect(result.result, CheckInResult.finalCompletion);
      expect(result.task.status, TaskStatus.inbox);
      expect(isPeriodCompleted(result.task, DateTime.now()), isTrue);
    });

    test('undo partial check-in decrements count', () async {
      final created = await repo.createInbox(
        title: 'Workout',
        checkInTarget: 3,
      );
      await repo.checkIn(created.id);
      await repo.checkIn(created.id);

      final undone = await repo.undoCheckIn(
        created.id,
        wasFinalCompletion: false,
      );
      expect(undone.checkInCount, 1);
      expect(undone.status, TaskStatus.inbox);
    });

    test('undo final non-recurring check-in restores inbox', () async {
      final created = await repo.createInbox(
        title: 'Workout',
        checkInTarget: 2,
      );
      await repo.checkIn(created.id);
      await repo.checkIn(created.id);

      final undone = await repo.undoCheckIn(
        created.id,
        wasFinalCompletion: true,
      );
      expect(undone.status, TaskStatus.inbox);
      expect(undone.checkInCount, 1);
    });

    test('undo final recurring check-in clears period completion', () async {
      final created = await repo.createInbox(
        title: 'Daily habit',
        recurrence: TaskRecurrence.daily,
        checkInTarget: 2,
      );
      await repo.checkIn(created.id);
      final completed = await repo.checkIn(created.id);
      expect(isPeriodCompleted(completed.task, DateTime.now()), isTrue);

      final undone = await repo.undoCheckIn(
        created.id,
        wasFinalCompletion: true,
      );
      expect(undone.status, TaskStatus.inbox);
      expect(undone.checkInCount, 1);
      expect(isPeriodCompleted(undone, DateTime.now()), isFalse);
    });
  });

  group('resetCheckInProgress', () {
    test('resets partial progress', () async {
      final created = await repo.createInbox(
        title: 'Workout',
        checkInTarget: 3,
      );
      await repo.checkIn(created.id);
      await repo.checkIn(created.id);

      final reset = await repo.resetCheckInProgress(created.id);
      expect(reset.checkInCount, 0);
      expect(reset.lastCheckInAt, isNull);
      expect(reset.checkInTarget, 3);
      expect(reset.status, TaskStatus.inbox);
    });

    test('resets recurring period completion', () async {
      final created = await repo.createInbox(
        title: 'Daily habit',
        recurrence: TaskRecurrence.daily,
        checkInTarget: 2,
      );
      await repo.checkIn(created.id);
      final completed = await repo.checkIn(created.id);
      expect(isPeriodCompleted(completed.task, DateTime.now()), isTrue);

      final reset = await repo.resetCheckInProgress(created.id);
      expect(reset.checkInCount, 0);
      expect(reset.lastCheckInAt, isNull);
      expect(reset.lastDailyCompletedAt, isNull);
      expect(isPeriodCompleted(reset, DateTime.now()), isFalse);
    });

    test('no-op when no progress', () async {
      final created = await repo.createInbox(
        title: 'Fresh',
        checkInTarget: 3,
      );

      final reset = await repo.resetCheckInProgress(created.id);
      expect(reset.checkInCount, 0);
      expect(reset.lastCheckInAt, isNull);
      expect(reset.syncVersion, created.syncVersion);
    });

    test('no-op when check-in not enabled', () async {
      final created = await repo.createInbox(title: 'Simple');
      await repo.checkIn(created.id);

      final reset = await repo.resetCheckInProgress(created.id);
      expect(reset.status, TaskStatus.archived);
    });
  });

  group('hasResettableCheckInProgress', () {
    test('true for partial progress', () {
      final task = _task(checkInTarget: 3, checkInCount: 2);
      expect(hasResettableCheckInProgress(task), isTrue);
    });

    test('true for completed recurring period with zero count', () {
      final today = DateTime.now();
      final task = _task(
        recurrence: TaskRecurrence.daily,
        checkInTarget: 2,
        lastDailyCompletedAt: today,
      );
      expect(hasResettableCheckInProgress(task, now: today), isTrue);
    });

    test('false when no check-in goal', () {
      expect(hasResettableCheckInProgress(_task()), isFalse);
    });

    test('false when no progress', () {
      expect(hasResettableCheckInProgress(_task(checkInTarget: 3)), isFalse);
    });
  });

  group('labels', () {
    test('checkInLabel shows progress', () {
      final task = _task(checkInTarget: 3, checkInCount: 2);
      expect(checkInLabel(task), '打卡 2/3');
    });

    test('completeLabelForCheckIn uses 打卡 before final attempt', () {
      final task = _task(checkInTarget: 3, checkInCount: 1);
      expect(completeLabelForCheckIn(task), '打卡');
    });

    test('completeLabelForCheckIn uses complete label on final attempt', () {
      final task = _task(checkInTarget: 3, checkInCount: 2);
      expect(completeLabelForCheckIn(task), '完成');
    });
  });
}
