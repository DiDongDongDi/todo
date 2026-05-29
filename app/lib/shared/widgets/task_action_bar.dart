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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: onTrash,
            icon: Icon(Icons.close, size: 18, color: colorScheme.error),
            label: Text(
              '放弃',
              style: TextStyle(color: colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onComplete,
            icon: Icon(Icons.check, size: 18, color: colorScheme.onPrimary),
            label: const Text('完成'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: successColor,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          IconButton.filledTonal(
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.keyboard_arrow_up),
            tooltip: '上一条',
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: '下一条',
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
