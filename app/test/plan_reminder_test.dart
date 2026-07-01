import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/reminders/plan_reminder_eligibility.dart';
import 'package:todo_app/core/reminders/plan_reminder_ids.dart';
import 'package:todo_app/core/reminders/plan_reminder_planner.dart';

Task _task({
  String id = '1',
  bool isStarred = false,
  TaskRecurrence recurrence = TaskRecurrence.none,
  DateTime? dailyUntil,
  DateTime? lastDailyCompletedAt,
  DateTime? dueDate,
  TaskStatus status = TaskStatus.inbox,
}) {
  return Task(
    id: id,
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

    test('on due day before midnight returns null (show immediately)', () {
      final task = _task(isStarred: true, dueDate: today);
      final now = DateTime(2026, 6, 7, 7, 30);
      expect(nextPlanReminderAt(task, now), isNull);
      expect(shouldShowPlanReminder(task, now), isTrue);
    });

    test('after midnight on due day returns null (show immediately)', () {
      final task = _task(isStarred: true, dueDate: today);
      final now = DateTime(2026, 6, 7, 9, 0);
      expect(nextPlanReminderAt(task, now), isNull);
      expect(shouldShowPlanReminder(task, now), isTrue);
    });

    test('future due date schedules on that day 00:00', () {
      final task = _task(isStarred: true, dueDate: tomorrow);
      final next = nextPlanReminderAt(task, today);
      expect(next, DateTime(2026, 6, 8, 0, 0));
    });
  });

  group('planReminderActions', () {
    test('disabled returns no actions', () {
      final actions = planReminderActions(
        inboxTasks: [_task(isStarred: true, dueDate: today)],
        enabled: false,
        now: DateTime(2026, 6, 7, 9),
      );
      expect(actions, isEmpty);
    });

    test('due today → show action', () {
      final task = _task(isStarred: true, dueDate: today);
      final now = DateTime(2026, 6, 7, 9);
      final actions = planReminderActions(
        inboxTasks: [task],
        enabled: true,
        now: now,
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, PlanReminderActionKind.show);
      expect(actions.single.notificationId, notificationIdForTask(task.id));
    });

    test('starred + no schedule → show action', () {
      final task = _task(isStarred: true);
      final actions = planReminderActions(
        inboxTasks: [task],
        enabled: true,
        now: today,
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, PlanReminderActionKind.show);
      expect(actions.single.notificationId, notificationIdForTask(task.id));
    });

    test('future due date → schedule action', () {
      final task = _task(isStarred: true, dueDate: tomorrow);
      final actions = planReminderActions(
        inboxTasks: [task],
        enabled: true,
        now: today,
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, PlanReminderActionKind.schedule);
      expect(actions.single.scheduleAt, DateTime(2026, 6, 8, 0, 0));
    });

    test('unstarred task → cancel action', () {
      final task = _task(dueDate: today);
      final actions = planReminderActions(
        inboxTasks: [task],
        enabled: true,
        now: DateTime(2026, 6, 7, 9),
      );
      expect(actions, hasLength(1));
      expect(actions.single.kind, PlanReminderActionKind.cancel);
    });

    test('mixed inbox picks correct actions per task', () {
      final dueToday = _task(id: 'a', isStarred: true, dueDate: today);
      final future = _task(id: 'b', isStarred: true, dueDate: tomorrow);
      final plain = _task(id: 'c', dueDate: today);
      final now = DateTime(2026, 6, 7, 9);

      final actions = planReminderActions(
        inboxTasks: [dueToday, future, plain],
        enabled: true,
        now: now,
      );

      final byId = {for (final a in actions) a.notificationId: a.kind};
      expect(byId[notificationIdForTask('a')], PlanReminderActionKind.show);
      expect(byId[notificationIdForTask('b')], PlanReminderActionKind.schedule);
      expect(byId[notificationIdForTask('c')], PlanReminderActionKind.cancel);
    });
  });
}
