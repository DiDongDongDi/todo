import 'package:flutter/material.dart';
import 'package:todo_app/core/settings/notification_sound_preference.dart';
import 'package:todo_app/shared/utils/sounds.dart';

class NotificationSoundSection extends StatelessWidget {
  const NotificationSoundSection({
    super.key,
    required this.title,
    required this.description,
    required this.preference,
    required this.supported,
    required this.onEnabledChanged,
    required this.onPick,
    this.topSpacing = 28,
  });

  final String title;
  final String description;
  final NotificationSoundPreference preference;
  final bool supported;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onPick;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topSpacing),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: SwitchListTile(
            title: const Text('启用音效'),
            subtitle: Text(preference.displayTitle),
            value: preference.enabled && supported,
            onChanged: supported ? onEnabledChanged : null,
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
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preference.displayTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.library_music_outlined),
                    label: const Text('从系统通知音库选择'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: preference.canPlay
                        ? () => AppSounds.play(preference)
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
  }
}
