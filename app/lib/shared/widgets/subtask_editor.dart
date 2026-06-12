import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';

TextStyle? subtaskTitleInputStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium;
}

InputDecoration subtaskTitleInputDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: colorScheme.outlineVariant),
  );

  return InputDecoration(
    hintText: '子任务',
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    ),
    isDense: true,
    filled: true,
    fillColor: colorScheme.surfaceContainerHigh,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),
    border: fieldBorder,
    enabledBorder: fieldBorder,
    focusedBorder: fieldBorder.copyWith(
      borderSide: BorderSide(color: colorScheme.primary),
    ),
  );
}

/// 草稿态子任务标题编辑（收集页保存前、处理页编辑态使用）。
class SubtaskTitleEditor extends StatefulWidget {
  const SubtaskTitleEditor({
    super.key,
    required this.controllers,
    required this.onRemove,
    this.onAnyFieldFocusChanged,
  });

  final List<TextEditingController> controllers;
  final ValueChanged<int> onRemove;
  final ValueChanged<bool>? onAnyFieldFocusChanged;

  static List<String> nonEmptyTitles(Iterable<TextEditingController> controllers) {
    return controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  @override
  State<SubtaskTitleEditor> createState() => _SubtaskTitleEditorState();
}

class _SubtaskTitleEditorState extends State<SubtaskTitleEditor> {
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
  }

  @override
  void didUpdateWidget(SubtaskTitleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父级可能就地 mutate 同一 List，old/new widget 的 length 会相同。
    _syncFocusNodes();
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.removeListener(_notifyFocusChanged);
      node.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }

  void _syncFocusNodes() {
    var changed = false;
    while (_focusNodes.length < widget.controllers.length) {
      final node = FocusNode();
      node.addListener(_notifyFocusChanged);
      _focusNodes.add(node);
      changed = true;
    }
    while (_focusNodes.length > widget.controllers.length) {
      final node = _focusNodes.removeLast();
      node.removeListener(_notifyFocusChanged);
      node.dispose();
      changed = true;
    }
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifyFocusChanged();
      });
    }
  }

  void _notifyFocusChanged() {
    if (!mounted) return;
    final anyFocused = _focusNodes.any((node) => node.hasFocus);
    widget.onAnyFieldFocusChanged?.call(anyFocused);
  }

  @override
  Widget build(BuildContext context) {
    _syncFocusNodes();
    if (widget.controllers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.controllers.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controllers[index],
                  focusNode: _focusNodes[index],
                  style: subtaskTitleInputStyle(context),
                  decoration: subtaskTitleInputDecoration(context),
                  textInputAction: TextInputAction.next,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => widget.onRemove(index),
                tooltip: '移除',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// 持久态子任务只读列表（处理页父任务卡片常态使用）。
class SubtaskListSection extends StatelessWidget {
  const SubtaskListSection({
    super.key,
    required this.subtasks,
  });

  final List<Task> subtasks;

  @override
  Widget build(BuildContext context) {
    if (subtasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completedCount =
        subtasks.where((t) => t.status == TaskStatus.archived).length;
    final total = subtasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '子任务 $completedCount/$total 已完成',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...subtasks.map((sub) {
          final done = sub.status == TaskStatus.archived;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: done ? colorScheme.primary : colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sub.title,
                    style: done
                        ? theme.textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          )
                        : theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
