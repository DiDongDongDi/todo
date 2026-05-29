import 'package:flutter/material.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';

class TaskActionBar extends StatelessWidget {
  const TaskActionBar({
    super.key,
    required this.onTrash,
    required this.onComplete,
    required this.onPrevious,
    required this.onNext,
    this.canGoPrevious = true,
    this.canGoNext = true,
  });

  final VoidCallback onTrash;
  final VoidCallback onComplete;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoPrevious;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = context.semanticColors.success;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onTrash,
              icon: Icon(Icons.close, color: colorScheme.error),
              label: Text(
                '放弃',
                style: TextStyle(color: colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: onComplete,
              icon: Icon(Icons.check, color: colorScheme.onPrimary),
              label: const Text('完成'),
              style: FilledButton.styleFrom(
                backgroundColor: successColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.keyboard_arrow_up),
            tooltip: '上一条',
          ),
          IconButton.filledTonal(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: '下一条',
          ),
        ],
      ),
    );
  }
}
