import 'dart:async';

import 'package:flutter/material.dart';
import 'package:todo_app/shared/utils/haptics.dart';

/// 任务星标切换按钮。
class TaskStarButton extends StatelessWidget {
  const TaskStarButton({
    super.key,
    required this.isStarred,
    required this.onToggle,
    this.compact = false,
    this.showWhenUnstarred = true,
  });

  final bool isStarred;
  final VoidCallback onToggle;
  final bool compact;

  /// 为 false 时，未星标不渲染（只读态）；编辑态应保持默认 true 以便添加星标。
  final bool showWhenUnstarred;

  @override
  Widget build(BuildContext context) {
    if (!showWhenUnstarred && !isStarred) {
      return const SizedBox.shrink();
    }

    const starColor = Colors.amber;
    final icon = isStarred ? Icons.star : Icons.star_outline;
    final tooltip = isStarred ? '取消星标' : '添加星标';

    Future<void> handleTap() async {
      await AppHaptics.light();
      onToggle();
    }

    if (compact) {
      return IconButton.filledTonal(
        onPressed: () => unawaited(handleTap()),
        icon: Icon(icon, color: isStarred ? starColor : null),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return IconButton(
      onPressed: () => unawaited(handleTap()),
      icon: Icon(icon, color: isStarred ? starColor : null),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );
  }
}
