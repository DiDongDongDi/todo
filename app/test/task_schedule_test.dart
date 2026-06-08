import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';

Task _task({
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
    recurrence: recurrence,
    dailyUntil: dailyUntil,
    lastDailyCompletedAt: lastDailyCompletedAt,
    dueDate: dueDate,
  );
}

void main() {
  final today = DateTime(2026, 6, 7);
  final yesterday = DateTime(2026, 6, 6);
  final tomorrow = DateTime(2026, 6, 8);

  group('daily tasks', () {
    test('active daily task is due today', () {
      final task = _task(recurrence: TaskRecurrence.daily);
      expect(isDueToday(task, today), isTrue);
    });

    test('expired daily task is not due', () {
      final task = _task(recurrence: TaskRecurrence.daily, dailyUntil: yesterday);
      expect(isDueToday(task, today), isFalse);
    });

    test('daily task on expiry day is still due', () {
      final task = _task(recurrence: TaskRecurrence.daily, dailyUntil: today);
      expect(isDueToday(task, today), isTrue);
    });

    test('daily task completed today is not due', () {
      final task = _task(
        recurrence: TaskRecurrence.daily,
        lastDailyCompletedAt: DateTime(2026, 6, 7, 10),
      );
      expect(isDueToday(task, today), isFalse);
    });

    test('daily task completed yesterday reappears today', () {
      final task = _task(
        recurrence: TaskRecurrence.daily,
        lastDailyCompletedAt: DateTime(2026, 6, 6, 22),
      );
      expect(isDueToday(task, today), isTrue);
    });

    test('UTC timestamp completed on local calendar day is not due', () {
      final utcStored = DateTime.utc(2026, 6, 8, 18);
      final localDay = utcStored.toLocal();
      final today = DateTime(
        localDay.year,
        localDay.month,
        localDay.day,
        2,
      );
      final task = _task(
        recurrence: TaskRecurrence.daily,
        lastDailyCompletedAt: utcStored,
      );
      expect(isDueToday(task, today), isFalse);
      expect(
        shouldShowInProcess(task, todayOnly: false, now: today),
        isFalse,
      );
    });

    test('UTC timestamp from previous local day reappears today', () {
      final utcStored = DateTime.utc(2026, 6, 8, 18);
      final localDay = utcStored.toLocal();
      final nextLocalDay = DateTime(
        localDay.year,
        localDay.month,
        localDay.day,
      ).add(const Duration(days: 1));
      final task = _task(
        recurrence: TaskRecurrence.daily,
        lastDailyCompletedAt: utcStored,
      );
      expect(isDueToday(task, nextLocalDay), isTrue);
    });

    test('date-only completion hides task for that day', () {
      final task = _task(
        recurrence: TaskRecurrence.daily,
        lastDailyCompletedAt: DateTime(2026, 6, 7),
      );
      expect(
        shouldShowInProcess(
          task,
          todayOnly: false,
          now: DateTime(2026, 6, 7, 14),
        ),
        isFalse,
      );
      expect(
        shouldShowInProcess(
          task,
          todayOnly: false,
          now: DateTime(2026, 6, 8, 8),
        ),
        isTrue,
      );
    });
  });

  group('monthly tasks', () {
    test('before anchor day is not due', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 1, 15),
      );
      expect(isDueToday(task, today), isFalse);
    });

    test('on anchor day is due', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 1, 15),
      );
      expect(isDueToday(task, DateTime(2026, 6, 15)), isTrue);
    });

    test('after anchor day is due', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 1, 15),
      );
      expect(isDueToday(task, DateTime(2026, 6, 20)), isTrue);
    });

    test('completed this month is hidden', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 1, 15),
        lastDailyCompletedAt: DateTime(2026, 6, 16),
      );
      expect(
        shouldShowInProcess(task, todayOnly: false, now: DateTime(2026, 6, 20)),
        isFalse,
      );
    });

    test('reappears next month', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 1, 15),
        lastDailyCompletedAt: DateTime(2026, 6, 16),
      );
      expect(
        shouldShowInProcess(task, todayOnly: false, now: DateTime(2026, 7, 15)),
        isTrue,
      );
    });

    test('anchor day 31 clamps in February', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 1, 31),
      );
      expect(periodDueDate(task, DateTime(2026, 2, 1)), DateTime(2026, 2, 28));
      expect(isDueToday(task, DateTime(2026, 2, 28)), isTrue);
      expect(isDueToday(task, DateTime(2026, 2, 27)), isFalse);
    });
  });

  group('yearly tasks', () {
    test('before anchor date is not due', () {
      final task = _task(
        recurrence: TaskRecurrence.yearly,
        dueDate: DateTime(2020, 6, 9),
      );
      expect(isDueToday(task, today), isFalse);
    });

    test('on anchor date is due', () {
      final task = _task(
        recurrence: TaskRecurrence.yearly,
        dueDate: DateTime(2020, 6, 9),
      );
      expect(isDueToday(task, DateTime(2026, 6, 9)), isTrue);
    });

    test('completed this year is hidden', () {
      final task = _task(
        recurrence: TaskRecurrence.yearly,
        dueDate: DateTime(2020, 6, 9),
        lastDailyCompletedAt: DateTime(2026, 6, 9),
      );
      expect(
        shouldShowInProcess(task, todayOnly: false, now: DateTime(2026, 6, 10)),
        isFalse,
      );
    });

    test('reappears next year', () {
      final task = _task(
        recurrence: TaskRecurrence.yearly,
        dueDate: DateTime(2020, 6, 9),
        lastDailyCompletedAt: DateTime(2026, 6, 9),
      );
      expect(
        shouldShowInProcess(task, todayOnly: false, now: DateTime(2027, 6, 9)),
        isTrue,
      );
    });
  });

  group('due date tasks', () {
    test('due today is due', () {
      expect(isDueToday(_task(dueDate: today), today), isTrue);
    });

    test('overdue is due', () {
      expect(isDueToday(_task(dueDate: yesterday), today), isTrue);
    });

    test('future due date is not due today', () {
      expect(isDueToday(_task(dueDate: tomorrow), today), isFalse);
    });
  });

  group('shouldShowInProcess', () {
    test('hides daily completed today in default mode', () {
      final task = _task(
        recurrence: TaskRecurrence.daily,
        lastDailyCompletedAt: DateTime(2026, 6, 7, 8),
      );
      expect(
        shouldShowInProcess(task, todayOnly: false, now: today),
        isFalse,
      );
    });

    test('shows unscheduled inbox in default mode', () {
      expect(
        shouldShowInProcess(_task(), todayOnly: false, now: today),
        isTrue,
      );
    });

    test('todayOnly hides unscheduled tasks', () {
      expect(
        shouldShowInProcess(_task(), todayOnly: true, now: today),
        isFalse,
      );
    });

    test('todayOnly shows daily and due today', () {
      expect(
        shouldShowInProcess(
          _task(recurrence: TaskRecurrence.daily),
          todayOnly: true,
          now: today,
        ),
        isTrue,
      );
      expect(
        shouldShowInProcess(_task(dueDate: today), todayOnly: true, now: today),
        isTrue,
      );
    });

    test('todayOnly hides future due date', () {
      expect(
        shouldShowInProcess(
          _task(dueDate: tomorrow),
          todayOnly: true,
          now: today,
        ),
        isFalse,
      );
    });

    test('hides expired daily in default mode', () {
      expect(
        shouldShowInProcess(
          _task(recurrence: TaskRecurrence.daily, dailyUntil: yesterday),
          todayOnly: false,
          now: today,
        ),
        isFalse,
      );
    });

    test('default mode hides future due date', () {
      expect(
        shouldShowInProcess(
          _task(dueDate: tomorrow),
          todayOnly: false,
          now: today,
        ),
        isFalse,
      );
    });

    test('default mode shows due today and overdue', () {
      expect(
        shouldShowInProcess(
          _task(dueDate: today),
          todayOnly: false,
          now: today,
        ),
        isTrue,
      );
      expect(
        shouldShowInProcess(
          _task(dueDate: yesterday),
          todayOnly: false,
          now: today,
        ),
        isTrue,
      );
    });

    test('default mode hides monthly before anchor day', () {
      expect(
        shouldShowInProcess(
          _task(
            recurrence: TaskRecurrence.monthly,
            dueDate: DateTime(2026, 1, 15),
          ),
          todayOnly: false,
          now: today,
        ),
        isFalse,
      );
    });

    test('default mode hides yearly before anchor date', () {
      expect(
        shouldShowInProcess(
          _task(
            recurrence: TaskRecurrence.yearly,
            dueDate: DateTime(2020, 6, 9),
          ),
          todayOnly: false,
          now: today,
        ),
        isFalse,
      );
    });
  });

  group('overdueDays', () {
    test('one day overdue', () {
      expect(overdueDays(_task(dueDate: yesterday), today), 1);
    });

    test('three days overdue', () {
      expect(
        overdueDays(_task(dueDate: DateTime(2026, 6, 4)), today),
        3,
      );
    });

    test('not overdue returns null', () {
      expect(overdueDays(_task(dueDate: today), today), isNull);
      expect(overdueDays(_task(dueDate: tomorrow), today), isNull);
    });

    test('monthly overdue uses period due date', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 1, 15),
      );
      expect(overdueDays(task, DateTime(2026, 6, 20)), 5);
    });
  });

  group('isOverdue', () {
    test('true when overdue', () {
      expect(isOverdue(_task(dueDate: yesterday), now: today), isTrue);
    });

    test('false when not overdue', () {
      expect(isOverdue(_task(dueDate: today), now: today), isFalse);
      expect(isOverdue(_task(dueDate: tomorrow), now: today), isFalse);
      expect(isOverdue(_task(), now: today), isFalse);
    });
  });

  group('scheduleLabel', () {
    test('daily without expiry', () {
      expect(
        scheduleLabel(_task(recurrence: TaskRecurrence.daily), now: today),
        '每日',
      );
    });

    test('daily with expiry', () {
      expect(
        scheduleLabel(
          _task(
            recurrence: TaskRecurrence.daily,
            dailyUntil: DateTime(2026, 6, 30),
          ),
          now: today,
        ),
        '每日 · 至 6/30',
      );
    });

    test('overdue due date', () {
      expect(
        scheduleLabel(_task(dueDate: yesterday), now: today),
        '已逾期 1 天',
      );
    });

    test('overdue due date multiple days', () {
      expect(
        scheduleLabel(_task(dueDate: DateTime(2026, 6, 4)), now: today),
        '已逾期 3 天',
      );
    });

    test('monthly label', () {
      expect(
        scheduleLabel(
          _task(
            recurrence: TaskRecurrence.monthly,
            dueDate: DateTime(2026, 1, 15),
          ),
          now: today,
        ),
        '每月 · 15日',
      );
    });

    test('monthly overdue label', () {
      expect(
        scheduleLabel(
          _task(
            recurrence: TaskRecurrence.monthly,
            dueDate: DateTime(2026, 1, 15),
          ),
          now: DateTime(2026, 6, 20),
        ),
        '已逾期 5 天',
      );
    });

    test('yearly label', () {
      expect(
        scheduleLabel(
          _task(
            recurrence: TaskRecurrence.yearly,
            dueDate: DateTime(2020, 6, 9),
          ),
          now: today,
        ),
        '每年 · 6/9',
      );
    });
  });
}
