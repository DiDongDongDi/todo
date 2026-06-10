import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:todo_app/core/import/task_batch_import_parser.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

Future<List<String>?> showBatchImportDialog(BuildContext context) async {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => const _BatchImportSheet(),
  );
}

class _BatchImportSheet extends StatefulWidget {
  const _BatchImportSheet();

  @override
  State<_BatchImportSheet> createState() => _BatchImportSheetState();
}

class _BatchImportSheetState extends State<_BatchImportSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _preview = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updatePreview);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleFocusAfterSheetAnimation();
    });
  }

  void _scheduleFocusAfterSheetAnimation() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _focusNode.requestFocus();
      return;
    }

    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(onStatus);
        if (mounted) {
          _focusNode.requestFocus();
        }
      }
    }

    animation.addStatusListener(onStatus);
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePreview);
    _controller.dispose();
    _focusNode.dispose();
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
    final sheetHeight = min(
      mediaQuery.size.height * 0.75,
      mediaQuery.size.height -
          viewInsets.bottom -
          mediaQuery.padding.top -
          24,
    ).clamp(240.0, mediaQuery.size.height * 0.85);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                '批量导入',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
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
                      focusNode: _focusNode,
                      minLines: 3,
                      maxLines: 8,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: '粘贴任务文本…',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _confirm,
                    child: const Text('导入'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
