import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/reminders/plan_reminder_service.dart';
import 'package:todo_app/core/reminders/plan_reminder_settings.dart';

/// 监听 inbox 变更并同步计划提醒；在 [TodoApp] 中 watch 以保持活跃。
final planReminderCoordinatorProvider = Provider<void>((ref) {
  ref.listen(inboxTasksProvider, (previous, next) {
    next.whenData((tasks) async {
      final enabled = ref.read(planReminderEnabledProvider).value ?? true;
      await PlanReminderService.instance.syncAll(
        tasks,
        enabled: enabled,
      );
    });
  });

  ref.listen(planReminderEnabledProvider, (previous, next) {
    next.whenData((enabled) async {
      final tasks = ref.read(inboxTasksProvider).value ?? [];
      await PlanReminderService.instance.syncAll(
        tasks,
        enabled: enabled,
      );
    });
  });
});

Future<void> syncPlanRemindersFromRef(WidgetRef ref) async {
  final enabled = ref.read(planReminderEnabledProvider).value ?? true;
  final tasks = ref.read(inboxTasksProvider).value ?? [];
  await PlanReminderService.instance.syncAll(tasks, enabled: enabled);
}

Future<void> syncPlanRemindersFromProvider(Ref ref) async {
  final enabled = ref.read(planReminderEnabledProvider).value ?? true;
  final tasks = ref.read(inboxTasksProvider).value ?? [];
  await PlanReminderService.instance.syncAll(tasks, enabled: enabled);
}
