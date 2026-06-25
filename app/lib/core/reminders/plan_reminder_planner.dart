import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/reminders/plan_reminder_eligibility.dart';
import 'package:todo_app/core/reminders/plan_reminder_ids.dart';

enum PlanReminderActionKind { show, schedule, cancel }

class PlanReminderAction {
  const PlanReminderAction({
    required this.notificationId,
    required this.kind,
    this.scheduleAt,
  });

  final int notificationId;
  final PlanReminderActionKind kind;
  final DateTime? scheduleAt;
}

/// Pure planning logic shared by sync engine and tests.
List<PlanReminderAction> planReminderActions({
  required List<Task> inboxTasks,
  required bool enabled,
  required DateTime now,
}) {
  if (!enabled) {
    return const [];
  }

  final actions = <PlanReminderAction>[];
  final activeIds = <int>{};

  for (final task in inboxTasks) {
    final id = notificationIdForTask(task.id);
    if (!shouldSchedulePlanReminder(task, now)) {
      actions.add(PlanReminderAction(
        notificationId: id,
        kind: PlanReminderActionKind.cancel,
      ));
      continue;
    }

    activeIds.add(id);

    if (shouldShowPlanReminder(task, now)) {
      final nextAt = nextPlanReminderAt(task, now);
      if (nextAt != null) {
        actions.add(PlanReminderAction(
          notificationId: id,
          kind: PlanReminderActionKind.schedule,
          scheduleAt: nextAt,
        ));
      } else {
        actions.add(PlanReminderAction(
          notificationId: id,
          kind: PlanReminderActionKind.show,
        ));
      }
    } else {
      final nextAt = nextPlanReminderAt(task, now);
      if (nextAt != null) {
        actions.add(PlanReminderAction(
          notificationId: id,
          kind: PlanReminderActionKind.schedule,
          scheduleAt: nextAt,
        ));
      } else {
        actions.add(PlanReminderAction(
          notificationId: id,
          kind: PlanReminderActionKind.cancel,
        ));
      }
    }
  }

  return actions;
}

Set<int> activePlanReminderNotificationIds({
  required List<Task> inboxTasks,
  required bool enabled,
  required DateTime now,
}) {
  if (!enabled) return {};

  return planReminderActions(
    inboxTasks: inboxTasks,
    enabled: enabled,
    now: now,
  )
      .where((a) => a.kind != PlanReminderActionKind.cancel)
      .map((a) => a.notificationId)
      .toSet();
}
