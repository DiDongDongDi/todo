import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/settings/collect_sound_settings.dart';
import 'package:todo_app/core/settings/notification_sound_platform.dart';
import 'package:todo_app/core/settings/notification_sound_preference.dart';
import 'package:todo_app/core/settings/process_sound_settings.dart';
import 'package:todo_app/core/settings/restore_sound_settings.dart';
import 'package:todo_app/shared/layout/app_layout.dart';
import 'package:todo_app/shared/utils/sounds.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/notification_sound_section.dart';

class SoundSettingsScreen extends ConsumerStatefulWidget {
  const SoundSettingsScreen({super.key});

  @override
  ConsumerState<SoundSettingsScreen> createState() =>
      _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends ConsumerState<SoundSettingsScreen> {
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

    return Scaffold(
      appBar: AppBar(title: const Text('音效')),
      body: collectAsync.isLoading ||
              processAsync.isLoading ||
              restoreAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : collectAsync.hasError
              ? Center(child: Text('加载失败: ${collectAsync.error}'))
              : processAsync.hasError
                  ? Center(child: Text('加载失败: ${processAsync.error}'))
                  : restoreAsync.hasError
                      ? Center(child: Text('加载失败: ${restoreAsync.error}'))
                      : _buildContent(
                          collect: collectAsync.requireValue,
                          process: processAsync.requireValue,
                          restore: restoreAsync.requireValue,
                        ),
    );
  }

  Widget _buildContent({
    required NotificationSoundPreference collect,
    required ProcessSoundSettings process,
    required NotificationSoundPreference restore,
  }) {
    final supported = _soundSupported ?? false;
    final unsupportedHint = supported
        ? null
        : '当前平台暂不支持系统通知音库，仅保留震动反馈。';

    return ListView(
      padding: AppLayout.cardPadding.copyWith(top: 24, bottom: 24),
      children: [
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
              '左滑完成或点击完成时播放所选系统通知音。',
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
          title: '处理 · 将来也许音效',
          description: unsupportedHint ??
              '右滑或点击将来也许时播放所选系统通知音。',
          preference: process.someday,
          supported: supported,
          onEnabledChanged: (value) => ref
              .read(processSoundProvider.notifier)
              .setEnabled(ProcessSoundKind.someday, value),
          onPick: () => _pickProcessSound(
            ProcessSoundKind.someday,
            process.someday,
          ),
        ),
        NotificationSoundSection(
          title: '处理 · 删除音效',
          description: unsupportedHint ??
              '点击删除按钮移至回收站时播放所选系统通知音。',
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
              '在已完成、回收站或将来也许队列恢复任务到收集箱时播放所选系统通知音。',
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
      ProcessSoundKind.someday => settings?.someday,
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
