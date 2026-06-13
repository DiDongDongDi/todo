import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task_check_in.dart';

Future<void> showTaskCheckInSheet(
  BuildContext context, {
  required int checkInTarget,
  required ValueChanged<int> onCheckInTargetChanged,
  VoidCallback? onTransientUiOpening,
  VoidCallback? onTransientUiClosed,
}) async {
  onTransientUiOpening?.call();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TaskCheckInSheet(
        initialTarget: checkInTarget,
        onCommit: onCheckInTargetChanged,
      ),
    );
  } finally {
    onTransientUiClosed?.call();
  }
}

class _TaskCheckInSheet extends StatefulWidget {
  const _TaskCheckInSheet({
    required this.initialTarget,
    required this.onCommit,
  });

  final int initialTarget;
  final ValueChanged<int> onCommit;

  @override
  State<_TaskCheckInSheet> createState() => _TaskCheckInSheetState();
}

class _TaskCheckInSheetState extends State<_TaskCheckInSheet> {
  late int _target;

  @override
  void initState() {
    super.initState();
    _target = _initialSheetTarget(widget.initialTarget);
  }

  int _initialSheetTarget(int initialTarget) {
    if (initialTarget <= defaultCheckInTarget) {
      return minActiveCheckInTarget;
    }
    return initialTarget.clamp(minActiveCheckInTarget, maxCheckInTarget);
  }

  void _commit() {
    widget.onCommit(_target);
    Navigator.pop(context);
  }

  void _cancelCheckIn() {
    widget.onCommit(defaultCheckInTarget);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('打卡设置', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '完成前需打卡的次数。重复任务在每个周期内分别计数。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _target > minActiveCheckInTarget
                    ? () => setState(() => _target--)
                    : null,
                icon: const Icon(Icons.remove),
                tooltip: '减少',
              ),
              const SizedBox(width: 24),
              Text(
                '$_target 次',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(width: 24),
              IconButton.filledTonal(
                onPressed: _target < maxCheckInTarget
                    ? () => setState(() => _target++)
                    : null,
                icon: const Icon(Icons.add),
                tooltip: '增加',
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _commit,
            child: const Text('完成'),
          ),
          TextButton(
            onPressed: _cancelCheckIn,
            child: const Text('取消打卡'),
          ),
        ],
      ),
    );
  }
}

String checkInEditorSummary(int checkInTarget) {
  if (checkInTarget <= defaultCheckInTarget) return '打卡';
  return '打卡 · ${checkInTarget}次';
}
