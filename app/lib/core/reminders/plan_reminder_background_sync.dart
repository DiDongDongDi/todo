import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/reminders/plan_reminder_constants.dart';
import 'package:todo_app/core/reminders/plan_reminder_storage.dart';
import 'package:todo_app/core/reminders/plan_reminder_sync_engine.dart';

/// Loads inbox tasks from SharedPreferences for background sync.
Future<List<Task>> loadInboxTasksFromPrefs(SharedPreferences prefs) async {
  final raw = prefs.getString(planReminderTasksStorageKey);
  if (raw == null || raw.isEmpty) return [];

  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
      .where((t) => t.status == TaskStatus.inbox && t.deletedAt == null)
      .toList();
}

Future<bool> isPlanReminderEnabledFromPrefs(SharedPreferences prefs) async {
  return prefs.getBool(planReminderEnabledKey) ?? true;
}

Future<FlutterLocalNotificationsPlugin> _initNotificationsPlugin() async {
  tz_data.initializeTimeZones();
  try {
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone));
  } catch (e) {
    tz.setLocalLocation(tz.local);
  }

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(initSettings);

  if (Platform.isAndroid) {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        planReminderChannelId,
        planReminderChannelName,
        description: planReminderChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  return plugin;
}

/// Headless entry point for WorkManager / FGS isolate.
@pragma('vm:entry-point')
Future<PlanReminderSyncResult> planReminderBackgroundSync() async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
    return const PlanReminderSyncResult(
      showingTodayCount: 0,
      scheduledCount: 0,
    );
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = await isPlanReminderEnabledFromPrefs(prefs);
    final plugin = await _initNotificationsPlugin();
    final engine = PlanReminderSyncEngine(plugin);

    if (!enabled) {
      await engine.cancelAll();
      return const PlanReminderSyncResult(
        showingTodayCount: 0,
        scheduledCount: 0,
      );
    }

    final inboxTasks = await loadInboxTasksFromPrefs(prefs);
    return engine.sync(inboxTasks: inboxTasks, enabled: enabled);
  } catch (e, st) {
    debugPrint('planReminderBackgroundSync failed: $e\n$st');
    return const PlanReminderSyncResult(
      showingTodayCount: 0,
      scheduledCount: 0,
    );
  }
}
