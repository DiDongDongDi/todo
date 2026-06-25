import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/reminders/plan_reminder_permissions.dart';
import 'package:todo_app/core/reminders/plan_reminder_provider.dart';
import 'package:todo_app/core/reminders/plan_reminder_service.dart';
import 'package:todo_app/core/reminders/plan_reminder_settings.dart';
import 'package:todo_app/core/reminders/plan_reminder_workmanager.dart';
import 'package:todo_app/core/reminders/reminder_guardian_service.dart';
import 'package:todo_app/shared/layout/app_layout.dart';

class NotificationReminderSettingsScreen extends ConsumerWidget {
  const NotificationReminderSettingsScreen({super.key});

  String _subtitle() {
    if (Platform.isAndroid) {
      return '已星标任务在通知栏常驻显示；设了计划的从计划日当天零点起提醒（逾期仍提醒）。'
          '开启后会显示守护通知与各任务通知，并在后台保持同步。';
    }
    if (Platform.isIOS) {
      return '已星标任务在通知栏显示；设了计划的从计划日当天零点起提醒。'
          'iOS 不支持常驻通知与开机自启；依赖系统调度与后台刷新，打开 App 后会恢复。';
    }
    return '已星标任务在通知栏显示；设了计划的从计划日当天零点起提醒。';
  }

  Future<void> _setEnabled(WidgetRef ref, bool value) async {
    if (value) {
      await PlanReminderService.instance.requestPermissions();
      if (Platform.isAndroid) {
        await PlanReminderPermissions.requestBatteryOptimizationExemption();
      }
    } else {
      await PlanReminderService.instance.cancelAll();
      await ReminderGuardianService.instance.stop();
      await registerPlanReminderBackgroundTasks(enabled: false);
    }

    await ref.read(planReminderEnabledProvider.notifier).setEnabled(value);
    await syncPlanRemindersFromRef(ref);

    if (value && Platform.isAndroid) {
      await registerPlanReminderBackgroundTasks(enabled: true);
      await ReminderGuardianService.instance.start();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planReminderAsync = ref.watch(planReminderEnabledProvider);
    final remindersSupported = PlanReminderService.instance.isSupported;
    final planReminderEnabled = planReminderAsync.value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('通知提醒')),
      body: !remindersSupported
          ? const Center(child: Text('当前平台不支持通知提醒'))
          : ListView(
              padding: AppLayout.cardPadding.copyWith(top: 20, bottom: 24),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('开启通知提醒'),
                  subtitle: Text(_subtitle()),
                  value: planReminderAsync.value ?? true,
                  onChanged: planReminderAsync.isLoading
                      ? null
                      : (value) => unawaited(_setEnabled(ref, value)),
                ),
                if (Platform.isAndroid && planReminderEnabled) ...[
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.battery_saver_outlined),
                    title: const Text('允许后台运行'),
                    subtitle: const Text('关闭电池优化，避免守护通知被系统清理'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: PlanReminderPermissions.openBatteryOptimizationSettings,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.power_settings_new_outlined),
                    title: const Text('自启动权限'),
                    subtitle: const Text(
                      '请在系统设置中为 Todo 开启自启动（小米/华为/OPPO 等需在应用详情中手动设置）',
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: PlanReminderPermissions.openBatteryOptimizationSettings,
                  ),
                ],
              ],
            ),
    );
  }
}
