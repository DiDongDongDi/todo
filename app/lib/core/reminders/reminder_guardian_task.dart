import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:todo_app/core/reminders/plan_reminder_background_sync.dart';

@pragma('vm:entry-point')
void reminderGuardianStartCallback() {
  FlutterForegroundTask.setTaskHandler(ReminderGuardianTaskHandler());
}

class ReminderGuardianTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _syncAndUpdateNotification();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _syncAndUpdateNotification();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}

  Future<void> _syncAndUpdateNotification() async {
    final result = await planReminderBackgroundSync();
    final count = result.showingTodayCount;
    final body = count > 0 ? '今日 $count 项待提醒' : '正在监听计划任务';
    FlutterForegroundTask.updateService(
      notificationTitle: '计划提醒运行中',
      notificationText: body,
    );
  }
}
