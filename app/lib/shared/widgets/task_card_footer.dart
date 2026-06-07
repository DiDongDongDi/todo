import 'package:flutter/material.dart';

/// 收集 Tab 大卡片底部：计划编辑器 + 图片/录音/保存。
class TaskCardCollectFooter extends StatelessWidget {
  const TaskCardCollectFooter({
    super.key,
    this.scheduleEditor,
    required this.onPickImage,
    required this.onStartSpeech,
    required this.isListening,
    required this.onSave,
    this.focusNode,
    this.compact = false,
  });

  final Widget? scheduleEditor;
  final VoidCallback? onPickImage;
  final VoidCallback? onStartSpeech;
  final bool isListening;
  final VoidCallback? onSave;
  final FocusNode? focusNode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scheduleEditor != null) ...[
          const SizedBox(height: 8),
          scheduleEditor!,
        ],
        SizedBox(height: compact ? 8 : 16),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: onPickImage,
              icon: const Icon(Icons.image_outlined),
              tooltip: '添加图片',
              visualDensity:
                  compact ? VisualDensity.compact : VisualDensity.standard,
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onStartSpeech,
              icon: Icon(isListening ? Icons.stop : Icons.mic_none_outlined),
              tooltip: isListening ? '停止录音' : '录音',
              visualDensity:
                  compact ? VisualDensity.compact : VisualDensity.standard,
              style: IconButton.styleFrom(
                backgroundColor:
                    isListening ? colorScheme.errorContainer : null,
              ),
            ),
            const Spacer(),
            Focus(
              canRequestFocus: false,
              child: FilledButton.icon(
                onPressed: () {
                  final keepKeyboard = focusNode?.hasFocus ?? false;
                  onSave?.call();
                  if (keepKeyboard &&
                      focusNode != null &&
                      !focusNode!.hasFocus) {
                    focusNode!.requestFocus();
                  }
                },
                icon: const Icon(Icons.check, size: 20),
                label: const Text('保存'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 处理 Tab 编辑模式底部：计划编辑器 + 图片/录音/取消/保存。
class TaskCardProcessFooter extends StatelessWidget {
  const TaskCardProcessFooter({
    super.key,
    this.scheduleEditor,
    required this.onPickImage,
    required this.onStartSpeech,
    required this.isListening,
    required this.onSave,
    required this.onCancelEdit,
    this.compact = false,
  });

  final Widget? scheduleEditor;
  final VoidCallback? onPickImage;
  final VoidCallback? onStartSpeech;
  final bool isListening;
  final VoidCallback? onSave;
  final VoidCallback? onCancelEdit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scheduleEditor != null) scheduleEditor!,
        SizedBox(height: compact ? 4 : 8),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: onPickImage,
              icon: const Icon(Icons.image_outlined),
              tooltip: '添加图片',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onStartSpeech,
              icon: Icon(isListening ? Icons.stop : Icons.mic_none_outlined),
              tooltip: isListening ? '停止录音' : '录音',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor:
                    isListening ? colorScheme.errorContainer : null,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onCancelEdit,
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onSave,
              child: const Text('保存'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 键盘弹出时，固定在输入法上方的工具栏容器。
class TaskCardKeyboardToolbar extends StatelessWidget {
  const TaskCardKeyboardToolbar({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: child,
        ),
      ),
    );
  }
}
