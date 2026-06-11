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

    test('expired monthly task is not due', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 1, 15),
        dailyUntil: yesterday,
      );
      expect(isDueToday(task, today), isFalse);
    });

    test('monthly task on expiry day is still due', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 1, 15),
        dailyUntil: DateTime(2026, 6, 20),
      );
      expect(isDueToday(task, DateTime(2026, 6, 20)), isTrue);
    });

    test('hides expired monthly in default mode', () {
      expect(
        shouldShowInProcess(
          _task(
            recurrence: TaskRecurrence.monthly,
            dueDate: DateTime(2026, 1, 15),
            dailyUntil: yesterday,
          ),
          todayOnly: false,
          now: today,
        ),
        isFalse,
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

    test('expired yearly task is not due', () {
      final task = _task(
        recurrence: TaskRecurrence.yearly,
        dueDate: DateTime(2020, 6, 9),
        dailyUntil: yesterday,
      );
      expect(isDueToday(task, today), isFalse);
    });

    test('yearly task on expiry day is still due', () {
      final task = _task(
        recurrence: TaskRecurrence.yearly,
        dueDate: DateTime(2020, 6, 9),
        dailyUntil: DateTime(2026, 6, 9),
      );
      expect(isDueToday(task, DateTime(2026, 6, 9)), isTrue);
    });

    test('hides expired yearly in default mode', () {
      expect(
        shouldShowInProcess(
          _task(
            recurrence: TaskRecurrence.yearly,
            dueDate: DateTime(2020, 6, 9),
            dailyUntil: yesterday,
          ),
          todayOnly: false,
          now: today,
        ),
        isFalse,
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

    test('monthly label with expiry', () {
      expect(
        scheduleLabel(
          _task(
            recurrence: TaskRecurrence.monthly,
            dueDate: DateTime(2026, 1, 15),
            dailyUntil: DateTime(2026, 12, 31),
          ),
          now: today,
        ),
        '每月 · 15日 · 至 12/31',
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

    test('yearly label with expiry', () {
      expect(
        scheduleLabel(
          _task(
            recurrence: TaskRecurrence.yearly,
            dueDate: DateTime(2020, 6, 9),
            dailyUntil: DateTime(2026, 12, 31),
          ),
          now: today,
        ),
        '每年 · 6/9 · 至 12/31',
      );
    });

    test('period-completed monthly overdue returns null not overdue label', () {
      expect(
        scheduleLabel(
          _task(
            recurrence: TaskRecurrence.monthly,
            dueDate: DateTime(2026, 1, 15),
            lastDailyCompletedAt: DateTime(2026, 6, 7, 10),
          ),
          now: DateTime(2026, 6, 20),
        ),
        isNull,
      );
    });
  });

  group('scheduleEditorSummary', () {
    test('monthly without expiry', () {
      expect(
        scheduleEditorSummary(
          recurrence: TaskRecurrence.monthly,
          dailyUntil: null,
          dueDate: DateTime(2026, 1, 15),
        ),
        '每月 · 15日',
      );
    });

    test('monthly with expiry', () {
      expect(
        scheduleEditorSummary(
          recurrence: TaskRecurrence.monthly,
          dailyUntil: DateTime(2026, 12, 31),
          dueDate: DateTime(2026, 1, 15),
        ),
        '每月 · 15日 · 至 12/31',
      );
    });

    test('yearly without expiry', () {
      expect(
        scheduleEditorSummary(
          recurrence: TaskRecurrence.yearly,
          dailyUntil: null,
          dueDate: DateTime(2020, 6, 9),
        ),
        '每年 · 6/9',
      );
    });

    test('yearly with expiry', () {
      expect(
        scheduleEditorSummary(
          recurrence: TaskRecurrence.yearly,
          dailyUntil: DateTime(2026, 12, 31),
          dueDate: DateTime(2020, 6, 9),
        ),
        '每年 · 6/9 · 至 12/31',
      );
    });
  });

  group('shouldIncludeInSearch', () {
    test('includes active inbox tasks', () {
      expect(shouldIncludeInSearch(_task(), now: today), isTrue);
    });

    test('excludes daily completed today', () {
      expect(
        shouldIncludeInSearch(
          _task(
            recurrence: TaskRecurrence.daily,
            lastDailyCompletedAt: DateTime(2026, 6, 7, 10),
          ),
          now: today,
        ),
        isFalse,
      );
    });

    test('excludes monthly completed this month', () {
      expect(
        shouldIncludeInSearch(
          _task(
            recurrence: TaskRecurrence.monthly,
            dueDate: DateTime(2026, 1, 15),
            lastDailyCompletedAt: DateTime(2026, 6, 5),
          ),
          now: today,
        ),
        isFalse,
      );
    });

    test('excludes yearly completed this year', () {
      expect(
        shouldIncludeInSearch(
          _task(
            recurrence: TaskRecurrence.yearly,
            dueDate: DateTime(2020, 6, 9),
            lastDailyCompletedAt: DateTime(2026, 1, 1),
          ),
          now: today,
        ),
        isFalse,
      );
    });

    test('includes monthly not yet completed this month', () {
      expect(
        shouldIncludeInSearch(
          _task(
            recurrence: TaskRecurrence.monthly,
            dueDate: DateTime(2026, 1, 15),
          ),
          now: today,
        ),
        isTrue,
      );
    });

    test('excludes archived tasks', () {
      expect(
        shouldIncludeInSearch(
          _task(status: TaskStatus.archived),
          now: today,
        ),
        isFalse,
      );
    });
  });

  group('completedScheduleLabel', () {
    test('daily', () {
      expect(
        completedScheduleLabel(_task(recurrence: TaskRecurrence.daily)),
        '每日 · 今日已完成',
      );
    });

    test('monthly', () {
      expect(
        completedScheduleLabel(
          _task(
            recurrence: TaskRecurrence.monthly,
            dueDate: DateTime(2026, 1, 15),
          ),
        ),
        '每月 · 本月已完成',
      );
    });

    test('yearly', () {
      expect(
        completedScheduleLabel(
          _task(
            recurrence: TaskRecurrence.yearly,
            dueDate: DateTime(2020, 6, 9),
          ),
        ),
        '每年 · 今年已完成',
      );
    });

    test('planned one-off', () {
      expect(
        completedScheduleLabel(_task(dueDate: DateTime(2026, 6, 7))),
        '计划 · 6/7',
      );
    });

    test('no schedule returns null', () {
      expect(completedScheduleLabel(_task()), isNull);
    });
  });

  group('skip overdue period on create', () {
    final june30 = DateTime(2026, 6, 30);

    test('nextPeriodDueDate monthly returns next month when anchor passed', () {
      expect(
        nextPeriodDueDate(
          recurrence: TaskRecurrence.monthly,
          dueDate: DateTime(2026, 7, 5),
          today: june30,
        ),
        DateTime(2026, 7, 5),
      );
    });

    test('nextPeriodDueDate monthly returns null when anchor not passed', () {
      expect(
        nextPeriodDueDate(
          recurrence: TaskRecurrence.monthly,
          dueDate: DateTime(2026, 6, 20),
          today: today,
        ),
        isNull,
      );
    });

    test('nextPeriodDueDate yearly returns next year when anchor passed', () {
      expect(
        nextPeriodDueDate(
          recurrence: TaskRecurrence.yearly,
          dueDate: DateTime(2027, 1, 15),
          today: today,
        ),
        DateTime(2027, 1, 15),
      );
    });

    test('nextPeriodDueDate yearly returns null when anchor not passed', () {
      expect(
        nextPeriodDueDate(
          recurrence: TaskRecurrence.yearly,
          dueDate: DateTime(2026, 12, 25),
          today: today,
        ),
        isNull,
      );
    });

    test('normalizeRecurringDueDate skips to next period when overdue', () {
      expect(
        normalizeRecurringDueDate(
          recurrence: TaskRecurrence.monthly,
          dueDate: DateTime(2026, 7, 5),
          today: june30,
        ),
        DateTime(2026, 7, 5),
      );
      expect(
        normalizeRecurringDueDate(
          recurrence: TaskRecurrence.yearly,
          dueDate: DateTime(2027, 1, 15),
          today: today,
        ),
        DateTime(2027, 1, 15),
      );
    });

    test('normalizeRecurringDueDate keeps date when not overdue', () {
      expect(
        normalizeRecurringDueDate(
          recurrence: TaskRecurrence.monthly,
          dueDate: DateTime(2026, 6, 20),
          today: today,
        ),
        DateTime(2026, 6, 20),
      );
    });

    test('not started task is hidden and not overdue', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 7, 5),
      );
      expect(isRecurrenceStarted(task, june30), isFalse);
      expect(isDueToday(task, june30), isFalse);
      expect(isOverdue(task, now: june30), isFalse);
      expect(
        shouldShowInProcess(task, todayOnly: false, now: june30),
        isFalse,
      );
      expect(scheduleLabel(task, now: june30), isNull);
    });

    test('first due date is due but not overdue', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 7, 5),
      );
      final firstDue = DateTime(2026, 7, 5);
      expect(isRecurrenceStarted(task, firstDue), isTrue);
      expect(isDueToday(task, firstDue), isTrue);
      expect(isOverdue(task, now: firstDue), isFalse);
      expect(
        shouldShowInProcess(task, todayOnly: false, now: firstDue),
        isTrue,
      );
    });

    test('yearly not started until first due date', () {
      final task = _task(
        recurrence: TaskRecurrence.yearly,
        dueDate: DateTime(2027, 1, 15),
      );
      expect(isRecurrenceStarted(task, today), isFalse);
      expect(
        shouldShowInProcess(task, todayOnly: false, now: today),
        isFalse,
      );
      final firstDue = DateTime(2027, 1, 15);
      expect(isRecurrenceStarted(task, firstDue), isTrue);
      expect(isDueToday(task, firstDue), isTrue);
    });

    test('monthly continues normal cycle after first due', () {
      final task = _task(
        recurrence: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 7, 5),
      );
      final august = DateTime(2026, 8, 10);
      expect(isRecurrenceStarted(task, august), isTrue);
      expect(isDueToday(task, august), isTrue);
      expect(overdueDays(task, august), 5);
    });
  });
}
