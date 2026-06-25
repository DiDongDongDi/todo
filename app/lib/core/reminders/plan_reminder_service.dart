import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/navigation/shell_navigation.dart';
import 'package:todo_app/core/reminders/plan_reminder_constants.dart';
import 'package:todo_app/core/reminders/plan_reminder_eligibility.dart';
import 'package:todo_app/core/reminders/plan_reminder_ids.dart';
import 'package:todo_app/core/settings/process_queue_source_settings.dart';

typedef PlanReminderTapHandler = void Function(String taskId);

/// 计划任务系统通知（仅 Android/iOS）。
class PlanReminderService {
  PlanReminderService._();

  static final PlanReminderService instance = PlanReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  PlanReminderTapHandler? _onTap;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize({PlanReminderTapHandler? onTap}) async {
    if (onTap != null) _onTap = onTap;
    if (!isSupported || _initialized) return;

    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone));
    } catch (e) {
      debugPrint('PlanReminderService: timezone fallback: $e');
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

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          planReminderBackgroundNotificationTap,
    );

    if (Platform.isAndroid) {
      final android =
          _plugin.resolvePlatformSpecificImplementation<
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

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;

    if (Platform.isAndroid) {
      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      return granted ?? true;
    }

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  Future<void> syncAll(
    List<Task> inboxTasks, {
    required bool enabled,
  }) async {
    if (!isSupported || !_initialized) return;

    if (!enabled) {
      await cancelAll();
      return;
    }

    final now = DateTime.now();
    final activeIds = <int>{};

    for (final task in inboxTasks) {
      final id = notificationIdForTask(task.id);
      if (!shouldSchedulePlanReminder(task, now)) {
        await _cancelTask(id);
        continue;
      }

      activeIds.add(id);

      if (shouldShowPlanReminder(task, now)) {
        final nextAt = nextPlanReminderAt(task, now);
        if (nextAt != null) {
          await _cancelShown(id);
          await _schedule(task, nextAt);
        } else {
          await _plugin.cancel(id);
          await _showOngoing(task);
        }
      } else {
        await _cancelShown(id);
        final nextAt = nextPlanReminderAt(task, now);
        if (nextAt != null) {
          await _schedule(task, nextAt);
        } else {
          await _plugin.cancel(id);
        }
      }
    }

    await _cancelOrphans(inboxTasks, activeIds);
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    await _plugin.cancelAll();
  }

  Future<void> handleLaunchNotification() async {
    if (!isSupported || !_initialized) return;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final payload = details?.notificationResponse?.payload;
    if (payload != null && payload.isNotEmpty) {
      _onTap?.call(payload);
    }
  }

  Future<void> _cancelOrphans(
    List<Task> inboxTasks,
    Set<int> activeIds,
  ) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (!activeIds.contains(request.id)) {
        await _plugin.cancel(request.id);
      }
    }
  }

  Future<void> _cancelTask(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> _cancelShown(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> _showOngoing(Task task) async {
    final body = scheduleLabel(task) ?? '星标任务';
    final title = '★ ${task.title}';

    await _plugin.show(
      notificationIdForTask(task.id),
      title,
      body,
      _details(ongoing: true),
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
      _details(ongoing: true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id,
    );
  }

  NotificationDetails _details({required bool ongoing}) {
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

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _onTap?.call(payload);
    }
  }
}

void handlePlanReminderTap(String taskId, WidgetRef ref) {
  ref.read(shellTabIndexProvider.notifier).state = 1;
  ref.read(processNavigationIntentProvider.notifier).state =
      ProcessNavigationIntent(
    queueSource: const ProcessQueueSource.inbox(),
    taskId: taskId,
  );
}

@pragma('vm:entry-point')
void planReminderBackgroundNotificationTap(NotificationResponse response) {
  // 后台点击由 App 启动后 handleLaunchNotification / 前台回调处理。
}
