import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/reminders/plan_reminder_background_sync.dart';
import 'package:todo_app/core/reminders/plan_reminder_boot_pending.dart';
import 'package:todo_app/core/reminders/plan_reminder_constants.dart';
import 'package:todo_app/core/reminders/plan_reminder_guardian_constants.dart';
import 'package:todo_app/core/reminders/reminder_guardian_service.dart';
import 'package:workmanager/workmanager.dart';

/// Initializes WorkManager for boot and periodic plan reminder sync.
Future<void> initializePlanReminderWorkmanager() async {
  if (kIsWeb || !Platform.isAndroid) return;

  await Workmanager().initialize(
    planReminderWorkmanagerCallback,
    isInDebugMode: kDebugMode,
  );

  await _handleBootPendingIfNeeded();
}

Future<void> registerPlanReminderBackgroundTasks({required bool enabled}) async {
  if (kIsWeb || !Platform.isAndroid) return;

  if (!enabled) {
    await Workmanager().cancelByUniqueName(planReminderWorkmanagerBootTask);
    await Workmanager().cancelByUniqueName(planReminderWorkmanagerPeriodicTask);
    return;
  }

  await Workmanager().registerPeriodicTask(
    planReminderWorkmanagerPeriodicTask,
    planReminderWorkmanagerPeriodicTask,
    frequency: const Duration(hours: 6),
    constraints: Constraints(
      networkType: NetworkType.not_required,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

/// Enqueue a one-off sync (e.g. from boot receiver path).
Future<void> enqueuePlanReminderBootSync() async {
  if (kIsWeb || !Platform.isAndroid) return;

  await Workmanager().registerOneOffTask(
    planReminderWorkmanagerBootTask,
    planReminderWorkmanagerBootTask,
    initialDelay: const Duration(minutes: 1),
    constraints: Constraints(
      networkType: NetworkType.not_required,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

Future<void> _handleBootPendingIfNeeded() async {
  if (kIsWeb || !Platform.isAndroid) return;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(planReminderBootPendingKey) != true) return;

  await prefs.setBool(planReminderBootPendingKey, false);
  await enqueuePlanReminderBootSync();
}

@pragma('vm:entry-point')
void planReminderWorkmanagerCallback() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case planReminderWorkmanagerBootTask:
      case planReminderWorkmanagerPeriodicTask:
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool(planReminderEnabledKey) ?? true;
        if (!enabled) {
          await ReminderGuardianService.instance.stop();
          return true;
        }
        await planReminderBackgroundSync();
        if (Platform.isAndroid) {
          await ReminderGuardianService.instance.startIfEnabled();
        }
        return true;
      default:
        return false;
    }
  });
}
