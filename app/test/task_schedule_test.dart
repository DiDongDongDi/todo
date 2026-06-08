import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';

Task _task({
  bool isDaily = false,
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
    isDaily: isDaily,
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
      final task = _task(isDaily: true);
      expect(isDueToday(task, today), isTrue);
    });

    test('expired daily task is not due', () {
      final task = _task(isDaily: true, dailyUntil: yesterday);
      expect(isDueToday(task, today), isFalse);
    });

    test('daily task on expiry day is still due', () {
      final task = _task(isDaily: true, dailyUntil: today);
      expect(isDueToday(task, today), isTrue);
    });

    test('daily task completed today is not due', () {
      final task = _task(
        isDaily: true,
        lastDailyCompletedAt: DateTime(2026, 6, 7, 10),
      );
      expect(isDueToday(task, today), isFalse);
    });

    test('daily task completed yesterday reappears today', () {
      final task = _task(
        isDaily: true,
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
      final task = _task(isDaily: true, lastDailyCompletedAt: utcStored);
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
      final task = _task(isDaily: true, lastDailyCompletedAt: utcStored);
      expect(isDueToday(task, nextLocalDay), isTrue);
    });

    test('date-only completion hides task for that day', () {
      final task = _task(
        isDaily: true,
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
        isDaily: true,
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
        shouldShowInProcess(_task(isDaily: true), todayOnly: true, now: today),
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
          _task(isDaily: true, dailyUntil: yesterday),
          todayOnly: false,
          now: today,
        ),
        isFalse,
      );
    });
  });

  group('scheduleLabel', () {
    test('daily without expiry', () {
      expect(scheduleLabel(_task(isDaily: true), now: today), '每日');
    });

    test('daily with expiry', () {
      expect(
        scheduleLabel(
          _task(isDaily: true, dailyUntil: DateTime(2026, 6, 30)),
          now: today,
        ),
        '每日 · 至 6/30',
      );
    });

    test('overdue due date', () {
      expect(
        scheduleLabel(_task(dueDate: yesterday), now: today),
        '已逾期 · 6/6',
      );
    });
  });
}
