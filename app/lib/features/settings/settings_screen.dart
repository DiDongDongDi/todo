import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/core/settings/collect_sound_settings.dart';
import 'package:todo_app/core/settings/notification_sound_platform.dart';
import 'package:todo_app/core/settings/notification_sound_preference.dart';
import 'package:todo_app/core/settings/process_sound_settings.dart';
import 'package:todo_app/core/settings/restore_sound_settings.dart';
import 'package:todo_app/shared/layout/app_layout.dart';
import 'package:todo_app/shared/utils/sounds.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/notification_sound_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _soundSupported;

  @override
  void initState() {
    super.initState();
    NotificationSoundPlatform.isSupported.then((value) {
      if (mounted) setState(() => _soundSupported = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final collectAsync = ref.watch(collectSoundProvider);
    final processAsync = ref.watch(processSoundProvider);
    final restoreAsync = ref.watch(restoreSoundProvider);

    if (collectAsync.isLoading ||
        processAsync.isLoading ||
        restoreAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (collectAsync.hasError) {
      return Center(child: Text('加载失败: ${collectAsync.error}'));
    }
    if (processAsync.hasError) {
      return Center(child: Text('加载失败: ${processAsync.error}'));
    }
    if (restoreAsync.hasError) {
      return Center(child: Text('加载失败: ${restoreAsync.error}'));
    }

    final collect = collectAsync.requireValue;
    final process = processAsync.requireValue;
    final restore = restoreAsync.requireValue;
    final supported = _soundSupported ?? false;
    final unsupportedHint = supported
        ? null
        : '当前平台暂不支持系统通知音库，仅保留震动反馈。';

    return ListView(
      padding: AppLayout.cardPadding.copyWith(top: 24, bottom: 24),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bookmark_outline),
          title: const Text('任务模板'),
          subtitle: const Text('查看、编辑或删除已保存的模板'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/templates'),
        ),
        const Divider(height: 32),
        NotificationSoundSection(
          title: '收集音效',
          description: unsupportedHint ??
              '卡片飞出保存时播放所选系统通知音。',
          preference: collect,
          supported: supported,
          topSpacing: 0,
          onEnabledChanged: (value) =>
              ref.read(collectSoundProvider.notifier).setEnabled(value),
          onPick: () => _pickCollectSound(collect),
        ),
        NotificationSoundSection(
          title: '处理 · 完成音效',
          description: unsupportedHint ??
              '右滑归档或点击完成时播放所选系统通知音。',
          preference: process.complete,
          supported: supported,
          onEnabledChanged: (value) => ref
              .read(processSoundProvider.notifier)
              .setEnabled(ProcessSoundKind.complete, value),
          onPick: () => _pickProcessSound(
            ProcessSoundKind.complete,
            process.complete,
          ),
        ),
        NotificationSoundSection(
          title: '处理 · 删除音效',
          description: unsupportedHint ??
              '左滑放弃或移至回收站时播放所选系统通知音。',
          preference: process.trash,
          supported: supported,
          onEnabledChanged: (value) => ref
              .read(processSoundProvider.notifier)
              .setEnabled(ProcessSoundKind.trash, value),
          onPick: () => _pickProcessSound(
            ProcessSoundKind.trash,
            process.trash,
          ),
        ),
        NotificationSoundSection(
          title: '恢复音效',
          description: unsupportedHint ??
              '在已完成或回收站恢复任务到收集箱时播放所选系统通知音。',
          preference: restore,
          supported: supported,
          onEnabledChanged: (value) =>
              ref.read(restoreSoundProvider.notifier).setEnabled(value),
          onPick: () => _pickRestoreSound(restore),
        ),
      ],
    );
  }

  Future<void> _pickCollectSound(NotificationSoundPreference current) async {
    final changed =
        await ref.read(collectSoundProvider.notifier).pickFromSystem();
    if (!mounted || !changed) return;

    final updated = ref.read(collectSoundProvider).value;
    if (updated != null && updated.canPlay) {
      await AppSounds.play(updated);
    }

    if (!mounted) return;
    _showPickResult(updated);
  }

  Future<void> _pickRestoreSound(NotificationSoundPreference current) async {
    final changed =
        await ref.read(restoreSoundProvider.notifier).pickFromSystem();
    if (!mounted || !changed) return;

    final updated = ref.read(restoreSoundProvider).value;
    if (updated != null && updated.canPlay) {
      await AppSounds.play(updated);
    }

    if (!mounted) return;
    _showPickResult(updated);
  }

  Future<void> _pickProcessSound(
    ProcessSoundKind kind,
    NotificationSoundPreference current,
  ) async {
    final changed = await ref
        .read(processSoundProvider.notifier)
        .pickFromSystem(kind);
    if (!mounted || !changed) return;

    final settings = ref.read(processSoundProvider).value;
    final updated = switch (kind) {
      ProcessSoundKind.complete => settings?.complete,
      ProcessSoundKind.trash => settings?.trash,
    };
    if (updated != null && updated.canPlay) {
      await AppSounds.play(updated);
    }

    if (!mounted) return;
    _showPickResult(updated);
  }

  void _showPickResult(NotificationSoundPreference? updated) {
    final enabled = updated?.enabled == true;
    showAppSnackBar(
      context,
      message: enabled ? '已选择：${updated!.displayTitle}' : '已设为无声',
      icon: enabled ? Icons.library_music_outlined : Icons.volume_off_outlined,
      type: AppSnackType.success,
    );
  }
}
