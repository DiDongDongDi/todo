import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/reminders/plan_reminder_constants.dart';
import 'package:todo_app/core/reminders/plan_reminder_eligibility.dart';
import 'package:todo_app/core/reminders/plan_reminder_ids.dart';
import 'package:todo_app/core/reminders/plan_reminder_planner.dart';

/// Result of syncing plan reminder notifications.
class PlanReminderSyncResult {
  const PlanReminderSyncResult({
    required this.showingTodayCount,
    required this.scheduledCount,
  });

  final int showingTodayCount;
  final int scheduledCount;
}

/// Shared notification sync logic for main and background isolates.
class PlanReminderSyncEngine {
  PlanReminderSyncEngine(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static NotificationDetails details({required bool ongoing}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        planReminderChannelId,
        planReminderChannelName,
        channelDescription: planReminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        ongoing: ongoing,
        autoCancel: false,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<PlanReminderSyncResult> sync({
    required List<Task> inboxTasks,
    required bool enabled,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();

    if (!enabled) {
      await _plugin.cancelAll();
      return const PlanReminderSyncResult(
        showingTodayCount: 0,
        scheduledCount: 0,
      );
    }

    var showingTodayCount = 0;
    var scheduledCount = 0;
    final actions = planReminderActions(
      inboxTasks: inboxTasks,
      enabled: enabled,
      now: effectiveNow,
    );
    final activeIds = <int>{
      for (final task in inboxTasks)
        if (shouldSchedulePlanReminder(task, effectiveNow))
          notificationIdForTask(task.id),
    };

    for (final action in actions) {
      switch (action.kind) {
        case PlanReminderActionKind.cancel:
          await _plugin.cancel(action.notificationId);
        case PlanReminderActionKind.show:
          final task = inboxTasks.firstWhere(
            (t) => notificationIdForTask(t.id) == action.notificationId,
          );
          await _plugin.cancel(action.notificationId);
          await _showOngoing(task);
          showingTodayCount++;
        case PlanReminderActionKind.schedule:
          final task = inboxTasks.firstWhere(
            (t) => notificationIdForTask(t.id) == action.notificationId,
          );
          await _plugin.cancel(action.notificationId);
          await _schedule(task, action.scheduleAt!);
          scheduledCount++;
      }
    }

    await _cancelOrphans(activeIds);
    return PlanReminderSyncResult(
      showingTodayCount: showingTodayCount,
      scheduledCount: scheduledCount,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> _cancelOrphans(Set<int> activeIds) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (!activeIds.contains(request.id)) {
        await _plugin.cancel(request.id);
      }
    }
  }

  Future<void> _showOngoing(Task task) async {
    final body = scheduleLabel(task) ?? '星标任务';
    final title = '★ ${task.title}';

    await _plugin.show(
      notificationIdForTask(task.id),
      title,
      body,
      details(ongoing: true),
      payload: task.id,
    );
  }

  Future<void> _schedule(Task task, DateTime localDateTime) async {
    final scheduled = tz.TZDateTime.from(localDateTime, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    final body = scheduleLabel(task) ?? '星标任务';
    final title = '★ ${task.title}';

    await _plugin.zonedSchedule(
      notificationIdForTask(task.id),
      title,
      body,
      scheduled,
      details(ongoing: true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id,
    );
  }
}
