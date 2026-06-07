import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';
import 'package:todo_app/shared/utils/audio_storage.dart';
import 'package:todo_app/shared/widgets/attachment_image.dart';
import 'package:todo_app/shared/widgets/audio_preview.dart';
import 'package:todo_app/shared/widgets/image_preview.dart';
enum BigTaskCardMode { collect, process, readOnly }

enum CollectCardFeedback { none, emptyHint, listening }

class BigTaskCard extends StatelessWidget {
  const BigTaskCard({
    super.key,
    required this.mode,
    this.task,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.attachments = const [],
    this.onRemoveAttachment,
    this.onPickImage,
    this.onStartSpeech,
    this.isListening = false,
    this.onSave,
    this.onActivateInput,
    this.feedback = CollectCardFeedback.none,
    this.onDismissFeedback,
    this.onTrash,
    this.onComplete,
    this.onPrevious,
    this.onNext,
    this.canGoPrevious = true,
    this.canGoNext = true,
    this.onRetryTranscription,
    this.scheduleLabel,
    this.completeLabel = '完成',
    this.scheduleEditor,
    this.onCancelEdit,
  });

  final BigTaskCardMode mode;
  final Task? task;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final List<TaskAttachment> attachments;
  final ValueChanged<int>? onRemoveAttachment;
  final VoidCallback? onPickImage;
  final VoidCallback? onStartSpeech;
  final bool isListening;
  final VoidCallback? onSave;
  final VoidCallback? onActivateInput;
  final CollectCardFeedback feedback;
  final VoidCallback? onDismissFeedback;
  final VoidCallback? onTrash;
  final VoidCallback? onComplete;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onRetryTranscription;
  final String? scheduleLabel;
  final String completeLabel;
  final Widget? scheduleEditor;
  final VoidCallback? onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                if (scheduleEditor != null) ...[
                  const SizedBox(height: 8),
                  scheduleEditor!,
                ],
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
                      icon: Icon(isListening ? Icons.stop : Icons.mic_none_outlined),
                      tooltip: isListening ? '停止录音' : '录音',
                      style: IconButton.styleFrom(
                        backgroundColor: isListening
                            ? colorScheme.errorContainer
                            : null,
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
              ] else if (mode == BigTaskCardMode.process) ...[
                const SizedBox(height: 12),
                if (scheduleEditor != null) scheduleEditor!,
                const SizedBox(height: 8),
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
                      icon: Icon(
                        isListening ? Icons.stop : Icons.mic_none_outlined,
                      ),
                      tooltip: isListening ? '停止录音' : '录音',
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: isListening
                            ? colorScheme.errorContainer
                            : null,
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
              ] else if (mode == BigTaskCardMode.readOnly && task != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: onTrash,
                      icon: Icon(Icons.close, color: colorScheme.error),
                      tooltip: '删除',
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.errorContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.check, size: 20),
                      label: Text(completeLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.semanticColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (task!.canRetryTranscription &&
                        onRetryTranscription != null) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: onRetryTranscription,
                        icon: const Icon(Icons.refresh),
                        tooltip: '重试转写',
                      ),
                    ],
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: canGoPrevious ? onPrevious : null,
                      icon: const Icon(Icons.keyboard_arrow_up),
                      tooltip: '上一条',
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: canGoNext ? onNext : null,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: '下一条',
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
    if (mode == BigTaskCardMode.collect) {
      return _buildContent(context);
    }

    if (mode == BigTaskCardMode.process) {
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // expands 空态时 TextField 命中区常小于视觉区域；用 Listener（非
            // GestureDetector）在首次 pointerDown 即聚焦，避免与 TextField 手势冲突。
            // 仅包裹文本区，附件缩略图不在其内，避免点图预览时唤起键盘。
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => onActivateInput?.call(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: feedback == CollectCardFeedback.emptyHint ||
                            feedback == CollectCardFeedback.listening
                        ? 0
                        : 1,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      showCursor: true,
                      cursorColor: colorScheme.primary,
                      onChanged: onChanged,
                      expands: true,
                      maxLines: null,
                      scrollPhysics: const NeverScrollableScrollPhysics(),
                      textAlignVertical: TextAlignVertical.top,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.35,
                      ),
                      decoration: const InputDecoration(
                        hintText: '记下一件事…',
                      ),
                    ),
                  ),
                  if (feedback == CollectCardFeedback.emptyHint)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDismissFeedback,
                        child: _buildCollectCenterHint(
                          context,
                          _feedbackMessage(feedback),
                        ),
                      ),
                    ),
                  if (feedback == CollectCardFeedback.listening)
                    Positioned.fill(
                      child: _buildCollectCenterHint(
                        context,
                        _feedbackMessage(feedback),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imageAttachments = _imageAttachments(attachments);
                  final audioAttachments = _audioAttachments(attachments);
                  final attachment = attachments[index];
                  return _AttachmentThumbnail(
                    attachment: attachment,
                    imageAttachments: imageAttachments,
                    audioAttachments: audioAttachments,
                    onRemove: onRemoveAttachment == null
                        ? null
                        : () => onRemoveAttachment!(index),
                  );
                },
              ),
            ),
          ],
        ],
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => focusNode?.requestFocus(),
              child: TextField(
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
              ),
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imageAttachments = _imageAttachments(attachments);
                  final audioAttachments = _audioAttachments(attachments);
                  final attachment = attachments[index];
                  return _AttachmentThumbnail(
                    attachment: attachment,
                    imageAttachments: imageAttachments,
                    audioAttachments: audioAttachments,
                    onRemove: onRemoveAttachment == null
                        ? null
                        : () => onRemoveAttachment!(index),
                  );
                },
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayTask.displayTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: displayTask.title.trim().isEmpty &&
                    displayTask.transcriptionStatus ==
                        TranscriptionStatus.pending
                ? colorScheme.onSurface.withValues(alpha: 0.45)
                : null,
          ),
        ),
        if (scheduleLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            scheduleLabel!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheduleLabel!.startsWith('已逾期')
                  ? colorScheme.error
                  : colorScheme.primary,
            ),
          ),
        ],
        if (displayTask.note != null && displayTask.note!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(displayTask.note!, style: theme.textTheme.bodyLarge),
        ],
        if (displayTask.attachments.isNotEmpty) ...[
          const SizedBox(height: 20),
          Builder(
            builder: (context) {
              final imageAttachments =
                  _imageAttachments(displayTask.attachments);
              final audioAttachments =
                  _audioAttachments(displayTask.attachments);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayTask.attachments.map((a) {
                  return _AttachmentThumbnail(
                    attachment: a,
                    imageAttachments: imageAttachments,
                    audioAttachments: audioAttachments,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    );
  }

  String _feedbackMessage(CollectCardFeedback value) {
    return switch (value) {
      CollectCardFeedback.emptyHint => '先记下点什么',
      CollectCardFeedback.listening => '录音中…',
      CollectCardFeedback.none => '',
    };
  }

  static List<TaskAttachment> _imageAttachments(List<TaskAttachment> attachments) {
    return attachments
        .where((a) => a.type == AttachmentType.image)
        .toList();
  }

  static List<TaskAttachment> _audioAttachments(List<TaskAttachment> attachments) {
    return attachments
        .where((a) => a.type == AttachmentType.audio)
        .toList();
  }

  /// 与保存成功时卡片内「已收集」轻提示一致。
  Widget _buildCollectCenterHint(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Text(
        message,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.45),
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _AttachmentThumbnail extends StatelessWidget {
  const _AttachmentThumbnail({
    required this.attachment,
    this.imageAttachments = const [],
    this.audioAttachments = const [],
    this.onRemove,
  });

  final TaskAttachment attachment;
  final List<TaskAttachment> imageAttachments;
  final List<TaskAttachment> audioAttachments;
  final VoidCallback? onRemove;

  bool get _isPreviewable =>
      attachment.type == AttachmentType.image ||
      attachment.type == AttachmentType.audio;

  void _openPreview(BuildContext context) {
    if (!_isPreviewable) return;

    FocusManager.instance.primaryFocus?.unfocus();

    if (attachment.type == AttachmentType.image) {
      final images =
          imageAttachments.isNotEmpty ? imageAttachments : [attachment];
      final index = images.indexWhere(
        (a) =>
            a.localPath == attachment.localPath &&
            a.remoteUrl == attachment.remoteUrl,
      );

      showAttachmentImagePreview(
        context,
        attachments: images,
        initialIndex: index >= 0 ? index : 0,
      );
      return;
    }

    final audios =
        audioAttachments.isNotEmpty ? audioAttachments : [attachment];
    final index = audios.indexWhere(
      (a) =>
          a.localPath == attachment.localPath &&
          a.remoteUrl == attachment.remoteUrl,
    );

    showAttachmentAudioPreview(
      context,
      attachments: audios,
      initialIndex: index >= 0 ? index : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isImage = attachment.type == AttachmentType.image;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _isPreviewable ? () => _openPreview(context) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: isImage
                  ? AttachmentImage(
                      attachment,
                      fit: BoxFit.cover,
                    )
                  : ColoredBox(
                      color: colorScheme.secondaryContainer,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mic_none_outlined,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          if (attachment.duration != null &&
                              attachment.duration! > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              formatAudioDuration(attachment.duration),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
