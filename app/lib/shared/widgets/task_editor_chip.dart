import 'package:flutter/material.dart';

/// 任务编辑区计划/打卡等入口按钮，避免 [ActionChip] 在 Web 上截断中文标签。
class TaskEditorChip extends StatelessWidget {
  const TaskEditorChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
