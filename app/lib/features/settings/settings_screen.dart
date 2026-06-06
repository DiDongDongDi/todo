import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/settings/collect_sound_settings.dart';
import 'package:todo_app/core/settings/notification_sound_platform.dart';
import 'package:todo_app/shared/layout/app_layout.dart';
import 'package:todo_app/shared/utils/sounds.dart';

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
    final soundAsync = ref.watch(collectSoundProvider);
    final theme = Theme.of(context);

    return soundAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (current) {
        final supported = _soundSupported ?? false;

        return ListView(
          padding: AppLayout.cardPadding.copyWith(top: 24, bottom: 24),
          children: [
            Text(
              '设置',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '收集音效',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              supported
                  ? '卡片飞出保存时播放所选系统通知音。'
                  : '当前平台暂不支持系统通知音库，仅保留震动反馈。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                title: const Text('启用音效'),
                subtitle: Text(current.displayTitle),
                value: current.enabled && supported,
                onChanged: supported
                    ? (value) =>
                        ref.read(collectSoundProvider.notifier).setEnabled(value)
                    : null,
              ),
            ),
            if (supported) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '当前通知音',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        current.displayTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _pickSound(current),
                        icon: const Icon(Icons.library_music_outlined),
                        label: const Text('从系统通知音库选择'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: current.canPlay
                            ? () => AppSounds.playCollectSuccess(current)
                            : null,
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('试听'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pickSound(CollectSoundPreference current) async {
    final changed =
        await ref.read(collectSoundProvider.notifier).pickFromSystem();
    if (!mounted || !changed) return;

    final updated = ref.read(collectSoundProvider).value;
    if (updated != null && updated.canPlay) {
      await AppSounds.playCollectSuccess(updated);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated?.enabled == true
              ? '已选择：${updated!.displayTitle}'
              : '已设为无声',
        ),
      ),
    );
  }
}
