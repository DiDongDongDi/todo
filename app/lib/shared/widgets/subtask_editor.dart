import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';

/// 草稿态子任务标题编辑（收集页保存前使用）。
class SubtaskTitleEditor extends StatelessWidget {
  const SubtaskTitleEditor({
    super.key,
    required this.controllers,
    required this.onAdd,
    required this.onRemove,
  });

  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  static List<String> nonEmptyTitles(Iterable<TextEditingController> controllers) {
    return controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '子任务',
              style: theme.textTheme.titleSmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        if (controllers.isNotEmpty) const SizedBox(height: 4),
        ...List.generate(controllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers[index],
                    decoration: InputDecoration(
                      hintText: '子任务 ${index + 1}',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => onRemove(index),
                  tooltip: '移除',
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// 持久态子任务列表（处理页父任务卡片使用）。
class SubtaskListSection extends StatefulWidget {
  const SubtaskListSection({
    super.key,
    required this.subtasks,
    required this.onAdd,
    this.adding = false,
  });

  final List<Task> subtasks;
  final Future<void> Function(String title) onAdd;
  final bool adding;

  @override
  State<SubtaskListSection> createState() => _SubtaskListSectionState();
}

class _SubtaskListSectionState extends State<SubtaskListSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || widget.adding) return;
    await widget.onAdd(title);
    if (!mounted) return;
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completedCount = widget.subtasks
        .where((t) => t.status == TaskStatus.archived)
        .length;
    final total = widget.subtasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (total > 0) ...[
          Text(
            '子任务 $completedCount/$total 已完成',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.subtasks.map((sub) {
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
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !widget.adding,
                decoration: InputDecoration(
                  hintText: '添加子任务',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: widget.adding ? null : _submit,
              child: widget.adding
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    )
                  : const Text('添加'),
            ),
          ],
        ),
      ],
    );
  }
}
