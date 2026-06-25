import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/core/reminders/plan_reminder_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final shortcutsAsync = ref.watch(volumeKeyShortcutsProvider);
    final remindersSupported = PlanReminderService.instance.isSupported;

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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('通知提醒'),
                  subtitle: const Text('星标任务常驻通知栏；计划日零点起提醒'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/notification-reminders'),
                ),
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
