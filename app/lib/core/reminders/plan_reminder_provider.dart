import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/reminders/plan_reminder_service.dart';
import 'package:todo_app/core/reminders/plan_reminder_settings.dart';

/// 从 inbox 拉取完整任务列表并同步计划提醒（等待 Service 初始化完成）。
Future<void> syncPlanReminders(Ref ref) async {
  await PlanReminderService.instance.ensureInitialized();
  final enabled = ref.read(planReminderEnabledProvider).value ?? true;
  final tasks = await ref.read(inboxTasksProvider.future);
  await PlanReminderService.instance.syncAll(tasks, enabled: enabled);
}

Future<void> syncPlanRemindersFromRef(WidgetRef ref) =>
    syncPlanReminders(ref);

Future<void> syncPlanRemindersFromProvider(Ref ref) =>
    syncPlanReminders(ref);

/// 监听 inbox 变更并同步计划提醒；在 [TodoApp] 中 watch 以保持活跃。
final planReminderCoordinatorProvider = Provider<void>((ref) {
  ref.listen(inboxTasksProvider, (previous, next) {
    next.whenData((_) => unawaited(syncPlanReminders(ref)));
  });

  ref.listen(planReminderEnabledProvider, (previous, next) {
    next.whenData((_) => unawaited(syncPlanReminders(ref)));
  });

  unawaited(syncPlanReminders(ref));
});
