import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/core/reminders/plan_reminder_permissions.dart';
import 'package:todo_app/core/reminders/plan_reminder_service.dart';
import 'package:todo_app/core/reminders/plan_reminder_settings.dart';
import 'package:todo_app/core/reminders/plan_reminder_workmanager.dart';
import 'package:todo_app/core/reminders/reminder_guardian_service.dart';
import 'package:todo_app/core/settings/volume_key_platform.dart';
import 'package:todo_app/core/settings/volume_key_settings.dart';
import 'package:todo_app/shared/layout/app_layout.dart';
import 'package:todo_app/shared/widgets/tab_page_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _volumeKeySupported;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVolumeKeySupport());
  }

  Future<void> _loadVolumeKeySupport() async {
    final supported = await VolumeKeyPlatform.isSupported;
    if (mounted) setState(() => _volumeKeySupported = supported);
  }

  String _planReminderSubtitle() {
    if (Platform.isAndroid) {
      return '已星标且设了计划的任务，到期当天 8:00 于通知栏提醒。'
          '开启后会显示守护通知与各任务通知，并在后台保持同步。';
    }
    if (Platform.isIOS) {
      return '已星标且设了计划的任务，到期当天 8:00 提醒。'
          'iOS 不支持常驻通知与开机自启；依赖系统调度与后台刷新，打开 App 后会恢复当日提醒。';
    }
    return '已星标且设了计划的任务，在到期当天 8:00 于通知栏提醒。';
  }

  @override
  Widget build(BuildContext context) {
    final shortcutsAsync = ref.watch(volumeKeyShortcutsProvider);
    final planReminderAsync = ref.watch(planReminderEnabledProvider);
    final remindersSupported = PlanReminderService.instance.isSupported;
    final planReminderEnabled = planReminderAsync.value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabPageHeader(title: '设置'),
        Expanded(
          child: ListView(
            padding: AppLayout.cardPadding.copyWith(top: 20, bottom: 24),
            children: [
              if (_volumeKeySupported == true) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.volume_down_outlined),
                  title: const Text('音量键快捷键'),
                  subtitle: const Text(
                    '收集页：音量下键保存；处理页：音量上/下键切换任务',
                  ),
                  value: shortcutsAsync.value ?? false,
                  onChanged: shortcutsAsync.isLoading
                      ? null
                      : (value) => ref
                          .read(volumeKeyShortcutsProvider.notifier)
                          .setEnabled(value),
                ),
                const SizedBox(height: 8),
              ],
              if (remindersSupported) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('计划提醒'),
                  subtitle: Text(_planReminderSubtitle()),
                  value: planReminderAsync.value ?? true,
                  onChanged: planReminderAsync.isLoading
                      ? null
                      : (value) async {
                          if (value) {
                            await PlanReminderService.instance
                                .requestPermissions();
                            if (Platform.isAndroid) {
                              await PlanReminderPermissions
                                  .requestBatteryOptimizationExemption();
                            }
                          } else {
                            await PlanReminderService.instance.cancelAll();
                            await ReminderGuardianService.instance.stop();
                            await registerPlanReminderBackgroundTasks(
                              enabled: false,
                            );
                          }
                          await ref
                              .read(planReminderEnabledProvider.notifier)
                              .setEnabled(value);
                        },
                ),
                if (Platform.isAndroid && planReminderEnabled) ...[
                  const SizedBox(height: 4),
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
                const SizedBox(height: 8),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('任务模板'),
                subtitle: const Text('查看、编辑或删除已保存的模板'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/templates'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.volume_up_outlined),
                title: const Text('音效'),
                subtitle: const Text('配置收集、处理、恢复等操作的提示音'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/sounds'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync_outlined),
                title: const Text('同步配置'),
                subtitle: const Text('登录账号并同步任务到云端'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/auth'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
