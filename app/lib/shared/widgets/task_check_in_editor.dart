import 'dart:async';

import 'package:flutter/material.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/widgets/task_check_in_sheet.dart';
import 'package:todo_app/shared/widgets/task_editor_chip.dart';

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
    final label = checkInEditorSummary(checkInTarget);

    return TaskEditorChip(
      icon: Icons.repeat_outlined,
      label: label,
      onPressed: () {
        unawaited(AppHaptics.light());
        _openSheet(context);
      },
    );
  }
}
