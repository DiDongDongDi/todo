import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:todo_app/core/import/task_batch_import_parser.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

Future<List<String>?> showBatchImportDialog(BuildContext context) async {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => const _BatchImportDialog(),
  );
}

class _BatchImportDialog extends StatefulWidget {
  const _BatchImportDialog();

  @override
  State<_BatchImportDialog> createState() => _BatchImportDialogState();
}

class _BatchImportDialogState extends State<_BatchImportDialog> {
  final _controller = TextEditingController();
  List<String> _preview = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePreview);
    _controller.dispose();
    super.dispose();
  }

  void _updatePreview() {
    setState(() {
      _preview = parseBatchImportTasks(_controller.text);
    });
  }

  void _confirm() {
    final titles = parseBatchImportTasks(_controller.text);
    if (titles.isEmpty) {
      showAppSnackBar(
        context,
        message: '未识别到任务，请检查格式',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
      return;
    }
    Navigator.pop(context, titles);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets;
    final keyboardOpen = viewInsets.bottom > 0;
    const reservedHeight = 148.0;
    final maxContentHeight = (mediaQuery.size.height -
            viewInsets.top -
            viewInsets.bottom -
            reservedHeight)
        .clamp(120.0, 520.0);

    return AlertDialog(
      scrollable: true,
      title: const Text('批量导入'),
      insetPadding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: keyboardOpen ? 12 : 24,
      ),
      content: SizedBox(
        width: min(480, mediaQuery.size.width - 48),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '粘贴滴答清单等导出的文本，以「- 」开头的每行代表一条任务。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: keyboardOpen ? 2 : 4,
                maxLines: keyboardOpen ? 5 : 8,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: '粘贴任务文本…',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '预览：${_preview.length} 条任务',
                style: theme.textTheme.labelLarge,
              ),
              if (_preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...List.generate(_preview.length, (index) {
                  final title = _preview[index];
                  final firstLine = title.split('\n').first;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0) const Divider(height: 1),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text('${index + 1}'),
                        title: Text(
                          firstLine,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('导入'),
        ),
      ],
    );
  }
}
