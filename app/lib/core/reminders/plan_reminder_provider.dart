import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/reminders/plan_reminder_service.dart';
import 'package:todo_app/core/reminders/plan_reminder_settings.dart';

Future<List<Task>> _reminderEligibleTasks(
  T Function<T>(ProviderListenable<T> provider) read,
) async {
  final inbox = await read(inboxTasksProvider.future);
  final someday = await read(somedayTasksProvider.future);
  return [...inbox, ...someday];
}

/// 从收集箱与将来也许拉取任务并同步计划提醒（等待 Service 初始化完成）。
Future<void> syncPlanReminders(Ref ref) =>
    _syncPlanReminders(read: ref.read);

Future<void> syncPlanRemindersFromRef(WidgetRef ref) =>
    _syncPlanReminders(read: ref.read);

Future<void> syncPlanRemindersFromProvider(Ref ref) =>
    _syncPlanReminders(read: ref.read);

Future<void> _syncPlanReminders({
  required T Function<T>(ProviderListenable<T> provider) read,
}) async {
  await PlanReminderService.instance.ensureInitialized();
  final enabled = read(planReminderEnabledProvider).value ?? true;
  final tasks = await _reminderEligibleTasks(read);
  await PlanReminderService.instance.syncAll(tasks, enabled: enabled);
}

/// 监听 inbox / someday 变更并同步计划提醒；在 [TodoApp] 中 watch 以保持活跃。
final planReminderCoordinatorProvider = Provider<void>((ref) {
  void scheduleSync() {
    if (PlanReminderService.instance.isInitialized) {
      unawaited(syncPlanReminders(ref));
    }
  }

  ref.listen(inboxTasksProvider, (previous, next) {
    next.whenData((_) => scheduleSync());
  });

  ref.listen(somedayTasksProvider, (previous, next) {
    next.whenData((_) => scheduleSync());
  });

  ref.listen(planReminderEnabledProvider, (previous, next) {
    next.whenData((_) => scheduleSync());
  });
});
