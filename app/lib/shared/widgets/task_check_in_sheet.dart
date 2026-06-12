import 'package:flutter/material.dart';

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
  static const _minTarget = 1;
  static const _maxTarget = 99;

  late int _target;

  @override
  void initState() {
    super.initState();
    _target = widget.initialTarget.clamp(_minTarget, _maxTarget);
  }

  void _commit() {
    widget.onCommit(_target);
    Navigator.pop(context);
  }

  void _clearCheckIn() {
    setState(() => _target = 1);
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
                onPressed: _target > _minTarget
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
                onPressed: _target < _maxTarget
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
            onPressed: _clearCheckIn,
            child: const Text('重置为 1 次'),
          ),
        ],
      ),
    );
  }
}

String checkInEditorSummary(int checkInTarget) {
  if (checkInTarget <= 1) return '打卡';
  return '打卡 · ${checkInTarget}次';
}
