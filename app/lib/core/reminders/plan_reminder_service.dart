import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/navigation/shell_navigation.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/reminders/plan_reminder_constants.dart';
import 'package:todo_app/core/reminders/plan_reminder_eligibility.dart';
import 'package:todo_app/core/reminders/plan_reminder_ids.dart';
import 'package:todo_app/core/reminders/plan_reminder_sync_engine.dart';
import 'package:todo_app/core/settings/process_queue_source_settings.dart';

typedef PlanReminderTapHandler = void Function(String taskId);

/// 计划任务系统通知（仅 Android/iOS）。
class PlanReminderService {
  PlanReminderService._();

  static final PlanReminderService instance = PlanReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  late final PlanReminderSyncEngine _engine = PlanReminderSyncEngine(_plugin);

  bool _initialized = false;
  Future<void>? _initFuture;
  PlanReminderTapHandler? _onTap;
  Set<int> _lastSyncedActiveIds = {};
  Future<void>? _syncChain;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get isInitialized => _initialized;

  /// Waits until [initialize] has completed (no-op if unsupported).
  Future<void> ensureInitialized() async {
    if (!isSupported || _initialized) return;
    await _initFuture;
  }

  Future<void> initialize({PlanReminderTapHandler? onTap}) async {
    if (onTap != null) _onTap = onTap;
    if (!isSupported || _initialized) return;
    _initFuture ??= _runInitialize();
    await _initFuture;
  }

  Future<void> _runInitialize() async {
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

  Future<PlanReminderSyncResult> syncAll(
    List<Task> inboxTasks, {
    required bool enabled,
  }) async {
    final previous = _syncChain ?? Future<void>.value();
    late final Future<PlanReminderSyncResult> current;
    current = previous.then((_) => _syncAllImpl(inboxTasks, enabled: enabled));
    _syncChain = current.then((_) {}, onError: (_) {});
    return current;
  }

  Future<PlanReminderSyncResult> _syncAllImpl(
    List<Task> inboxTasks, {
    required bool enabled,
  }) async {
    if (!isSupported || !_initialized) {
      return const PlanReminderSyncResult(
        showingTodayCount: 0,
        scheduledCount: 0,
      );
    }

    if (!enabled) {
      await cancelAll();
      return const PlanReminderSyncResult(
        showingTodayCount: 0,
        scheduledCount: 0,
      );
    }

    final now = DateTime.now();
    final activeIds = <int>{
      for (final task in inboxTasks)
        if (shouldSchedulePlanReminder(task, now))
          notificationIdForTask(task.id),
    };

    final result = await _engine.sync(inboxTasks: inboxTasks, enabled: enabled);

    // show() 型通知不在 pending 列表中，需额外清理上次 sync 遗留的 ID。
    for (final id in _lastSyncedActiveIds) {
      if (!activeIds.contains(id)) {
        await _plugin.cancel(id);
      }
    }
    _lastSyncedActiveIds = Set<int>.from(activeIds);

    return result;
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    await _engine.cancelAll();
    _lastSyncedActiveIds = {};
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

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _onTap?.call(payload);
    }
  }
}

void handlePlanReminderTap(String taskId, WidgetRef ref) {
  unawaited(_handlePlanReminderTap(taskId, ref));
}

Future<void> _handlePlanReminderTap(String taskId, WidgetRef ref) async {
  ref.read(shellTabIndexProvider.notifier).state = 1;

  ProcessQueueSource queueSource = const ProcessQueueSource.inbox();
  try {
    final repo = await ref.read(taskRepositoryProvider.future);
    final task = await repo.getById(taskId);
    if (task?.status == TaskStatus.someday) {
      queueSource = const ProcessQueueSource(kind: ProcessQueueKind.someday);
    }
  } catch (e) {
    debugPrint('handlePlanReminderTap: $e');
  }

  ref.read(processNavigationIntentProvider.notifier).state =
      ProcessNavigationIntent(
    queueSource: queueSource,
    taskId: taskId,
  );
}

@pragma('vm:entry-point')
void planReminderBackgroundNotificationTap(NotificationResponse response) {
  // 后台点击由 App 启动后 handleLaunchNotification / 前台回调处理。
}
