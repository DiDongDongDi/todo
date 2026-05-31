import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/shared/utils/platform_capabilities.dart';

enum BigTaskCardMode { collect, process, readOnly }

class BigTaskCard extends StatelessWidget {
  const BigTaskCard({
    super.key,
    required this.mode,
    this.task,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onPickImage,
    this.onStartSpeech,
    this.isListening = false,
    this.onSave,
  });

  final BigTaskCardMode mode;
  final Task? task;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onPickImage;
  final VoidCallback? onStartSpeech;
  final bool isListening;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final touchFirst = isTouchFirstPlatform;

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildContentArea(context),
              ),
              if (mode == BigTaskCardMode.collect) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: onPickImage,
                      icon: const Icon(Icons.image_outlined),
                      tooltip: '添加图片',
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: onStartSpeech,
                      icon: Icon(isListening ? Icons.mic : Icons.mic_none_outlined),
                      tooltip: '语音输入',
                      style: IconButton.styleFrom(
                        backgroundColor: isListening
                            ? colorScheme.errorContainer
                            : null,
                      ),
                    ),
                    const Spacer(),
                    if (!touchFirst)
                      FilledButton.icon(
                        onPressed: onSave,
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text('保存'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea(BuildContext context) {
    if (mode == BigTaskCardMode.collect || mode == BigTaskCardMode.process) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => focusNode?.requestFocus(),
        child: _buildContent(context),
      );
    }

    return SingleChildScrollView(
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (mode == BigTaskCardMode.collect) {
      return TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: colorScheme.onSurface,
          height: 1.35,
        ),
        decoration: const InputDecoration(
          hintText: '记下一件事…',
        ),
      );
    }

    final displayTask = task;
    if (displayTask == null) {
      return Center(
        child: Text(
          '暂无任务',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    if (mode == BigTaskCardMode.process && controller != null) {
      return TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: colorScheme.onSurface,
          height: 1.35,
        ),
        decoration: const InputDecoration(border: InputBorder.none),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayTask.title.isEmpty ? '（无标题）' : displayTask.title,
          style: theme.textTheme.headlineMedium,
        ),
        if (displayTask.note != null && displayTask.note!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(displayTask.note!, style: theme.textTheme.bodyLarge),
        ],
        if (displayTask.attachments.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: displayTask.attachments.map((a) {
              return Chip(
                avatar: Icon(
                  a.type == AttachmentType.image
                      ? Icons.image_outlined
                      : Icons.audiotrack_outlined,
                ),
                label: Text(
                  a.type == AttachmentType.image ? '图片' : '录音',
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
