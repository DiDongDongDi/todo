import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/reminders/plan_reminder_eligibility.dart';

Task _task({
  bool isStarred = false,
  TaskRecurrence recurrence = TaskRecurrence.none,
  DateTime? dailyUntil,
  DateTime? lastDailyCompletedAt,
  DateTime? dueDate,
  TaskStatus status = TaskStatus.inbox,
}) {
  return Task(
    id: '1',
    title: 'test',
    status: status,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    isStarred: isStarred,
    recurrence: recurrence,
    dailyUntil: dailyUntil,
    lastDailyCompletedAt: lastDailyCompletedAt,
    dueDate: dueDate,
  );
}

void main() {
  final today = DateTime(2026, 6, 7);
  final tomorrow = DateTime(2026, 6, 8);

  group('shouldShowPlanReminder', () {
    test('starred + scheduled + due today → remind', () {
      final task = _task(
        isStarred: true,
        dueDate: today,
      );
      expect(shouldShowPlanReminder(task, today), isTrue);
    });

    test('not starred + scheduled + due today → no remind', () {
      final task = _task(dueDate: today);
      expect(shouldShowPlanReminder(task, today), isFalse);
    });

    test('starred + no schedule → remind', () {
      final task = _task(isStarred: true);
      expect(shouldShowPlanReminder(task, today), isTrue);
    });

    test('starred + future due date → no immediate remind', () {
      final task = _task(isStarred: true, dueDate: tomorrow);
      expect(shouldShowPlanReminder(task, today), isFalse);
    });

    test('starred + archived → no remind', () {
      final task = _task(
        isStarred: true,
        dueDate: today,
        status: TaskStatus.archived,
      );
      expect(shouldShowPlanReminder(task, today), isFalse);
    });

    test('starred daily completed today → no remind', () {
      final task = _task(
        isStarred: true,
        recurrence: TaskRecurrence.daily,
        lastDailyCompletedAt: DateTime(2026, 6, 7, 9),
      );
      expect(shouldShowPlanReminder(task, today), isFalse);
    });
  });

  group('shouldSchedulePlanReminder', () {
    test('starred future one-time task should schedule', () {
      final task = _task(isStarred: true, dueDate: tomorrow);
      expect(shouldSchedulePlanReminder(task, today), isTrue);
    });

    test('unstarred task should not schedule', () {
      final task = _task(isStarred: false, dueDate: tomorrow);
      expect(shouldSchedulePlanReminder(task, today), isFalse);
    });
  });

  group('nextPlanReminderAt', () {
    test('starred + no schedule returns null (show immediately)', () {
      final task = _task(isStarred: true);
      expect(nextPlanReminderAt(task, today), isNull);
    });

    test('before 8:00 on due day schedules today 8:00', () {
      final task = _task(isStarred: true, dueDate: today);
      final now = DateTime(2026, 6, 7, 7, 30);
      final next = nextPlanReminderAt(task, now);
      expect(next, DateTime(2026, 6, 7, 8, 0));
    });

    test('after 8:00 on due day returns null (show immediately)', () {
      final task = _task(isStarred: true, dueDate: today);
      final now = DateTime(2026, 6, 7, 9, 0);
      expect(nextPlanReminderAt(task, now), isNull);
      expect(shouldShowPlanReminder(task, now), isTrue);
    });

    test('future due date schedules on that day 8:00', () {
      final task = _task(isStarred: true, dueDate: tomorrow);
      final next = nextPlanReminderAt(task, today);
      expect(next, DateTime(2026, 6, 8, 8, 0));
    });
  });
}
