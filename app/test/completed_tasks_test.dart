import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';

Task _task({
  required String id,
  TaskRecurrence recurrence = TaskRecurrence.none,
  TaskStatus status = TaskStatus.inbox,
  DateTime? lastDailyCompletedAt,
  DateTime? archivedAt,
  DateTime? dueDate,
}) {
  return Task(
    id: id,
    title: 'test',
    status: status,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    recurrence: recurrence,
    lastDailyCompletedAt: lastDailyCompletedAt,
    archivedAt: archivedAt,
    dueDate: dueDate,
  );
}

void main() {
  final today = DateTime(2026, 6, 7);

  test('mergeCompletedTasks combines archived and period-completed inbox', () {
    final archived = [
      _task(
        id: 'a1',
        status: TaskStatus.archived,
        archivedAt: DateTime(2026, 6, 6),
        dueDate: DateTime(2026, 6, 1),
      ),
    ];
    final inbox = [
      _task(
        id: 'i1',
        recurrence: TaskRecurrence.daily,
        lastDailyCompletedAt: DateTime(2026, 6, 7, 10),
      ),
      _task(
        id: 'i2',
        recurrence: TaskRecurrence.daily,
      ),
    ];

    final merged = mergeCompletedTasks(
      archived: archived,
      inbox: inbox,
      now: today,
    );

    expect(merged.length, 2);
    expect(merged[0].task.id, 'i1');
    expect(merged[0].isPeriodCompletion, isTrue);
    expect(merged[1].task.id, 'a1');
    expect(merged[1].isPeriodCompletion, isFalse);
  });

  test('mergeCompletedTasks sorts by completion time descending', () {
    final archived = [
      _task(
        id: 'older',
        status: TaskStatus.archived,
        archivedAt: DateTime(2026, 6, 1),
      ),
      _task(
        id: 'newer',
        status: TaskStatus.archived,
        archivedAt: DateTime(2026, 6, 10),
      ),
    ];

    final merged = mergeCompletedTasks(
      archived: archived,
      inbox: const [],
      now: today,
    );

    expect(merged.map((e) => e.task.id).toList(), ['newer', 'older']);
  });
}
