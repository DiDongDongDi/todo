import 'dart:async';

import 'package:flutter/material.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/widgets/task_check_in_sheet.dart';

/// 任务打卡配置入口：点击打开底部面板设置完成所需打卡次数。
class TaskCheckInEditor extends StatelessWidget {
  const TaskCheckInEditor({
    super.key,
    required this.checkInTarget,
    required this.onCheckInTargetChanged,
    this.onTransientUiOpening,
    this.onTransientUiClosed,
  });

  final int checkInTarget;
  final ValueChanged<int> onCheckInTargetChanged;
  final VoidCallback? onTransientUiOpening;
  final VoidCallback? onTransientUiClosed;

  Future<void> _openSheet(BuildContext context) {
    return showTaskCheckInSheet(
      context,
      checkInTarget: checkInTarget,
      onCheckInTargetChanged: onCheckInTargetChanged,
      onTransientUiOpening: onTransientUiOpening,
      onTransientUiClosed: onTransientUiClosed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = checkInEditorSummary(checkInTarget);

    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        label: Text(label, style: theme.textTheme.labelMedium),
        avatar: Icon(
          Icons.repeat_outlined,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        onPressed: () {
          unawaited(AppHaptics.light());
          _openSheet(context);
        },
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
