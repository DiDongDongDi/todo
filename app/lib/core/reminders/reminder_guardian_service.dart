import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:todo_app/core/reminders/plan_reminder_guardian_constants.dart';
import 'package:todo_app/core/reminders/reminder_guardian_task.dart';

/// Foreground service that keeps plan reminders synced in the background.
class ReminderGuardianService {
  ReminderGuardianService._();

  static final ReminderGuardianService instance = ReminderGuardianService._();

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool _initialized = false;

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;

    FlutterForegroundTask.initCommunicationPort();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: planReminderGuardianChannelId,
        channelName: planReminderGuardianChannelName,
        channelDescription: planReminderGuardianChannelDescription,
        onlyAlertOnce: true,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          planReminderGuardianSyncIntervalMs,
        ),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    _initialized = true;
  }

  Future<bool> isRunning() async {
    if (!isSupported) return false;
    return FlutterForegroundTask.isRunningService;
  }

  Future<void> start() async {
    if (!isSupported) return;
    await initialize();

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: planReminderGuardianNotificationId,
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: '计划提醒运行中',
      notificationText: '正在监听计划任务',
      callback: reminderGuardianStartCallback,
    );
  }

  Future<void> stop() async {
    if (!isSupported) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// Used by WorkManager boot sync when reminders are enabled.
  Future<void> startIfEnabled() async {
    if (!isSupported) return;
    await initialize();
    await start();
  }
}
