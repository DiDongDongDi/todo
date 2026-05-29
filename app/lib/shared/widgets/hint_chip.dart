import 'package:flutter/material.dart';

/// Compact centered hint text that sizes to its content.
class HintChip extends StatelessWidget {
  const HintChip({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
