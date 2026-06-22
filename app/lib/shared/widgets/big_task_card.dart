import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';
import 'package:todo_app/shared/utils/audio_storage.dart';
import 'package:todo_app/shared/widgets/attachment_image.dart';
import 'package:todo_app/shared/widgets/audio_preview.dart';
import 'package:todo_app/shared/widgets/haptic_tap_scope.dart';
import 'package:todo_app/shared/widgets/image_preview.dart';
import 'package:todo_app/shared/widgets/keyboard_lift.dart';
import 'package:todo_app/shared/widgets/task_star_button.dart';
enum BigTaskCardMode { collect, process }

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
    this.onSomeday,
    this.onComplete,
    this.onPrevious,
    this.onNext,
    this.canGoPrevious = true,
    this.canGoNext = true,
    this.onRetryTranscription,
    this.scheduleLabel,
    this.scheduleOverdue = false,
    this.completeLabel = '完成',
    this.scheduleEditor,
    this.checkInEditor,
    this.checkInLabel,
    this.onResetCheckInProgress,
    this.onCancelEdit,
    this.editing = false,
    this.onEnterEdit,
    this.parentTitle,
    this.onTapParent,
    this.subtaskEditor,
    this.subtaskSection,
    this.onAddSubtask,
    this.isStarred = false,
    this.onToggleStar,
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
  final VoidCallback? onSomeday;
  final VoidCallback? onComplete;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onRetryTranscription;
  final String? scheduleLabel;
  final bool scheduleOverdue;
  final String completeLabel;
  final Widget? scheduleEditor;
  final Widget? checkInEditor;
  final String? checkInLabel;
  final VoidCallback? onResetCheckInProgress;
  final VoidCallback? onCancelEdit;

  /// 处理 tab：false 时标题为只读 [TextField]，true 时可编辑。
  final bool editing;

  /// 只读标题被点击时进入编辑（处理 tab）。
  final VoidCallback? onEnterEdit;

  final String? parentTitle;
  final VoidCallback? onTapParent;

  /// 收集页：保存前的子任务标题编辑区。
  final Widget? subtaskEditor;

  /// 处理页：父任务的子任务只读列表。
  final Widget? subtaskSection;

  /// 底部工具栏「添加子任务」按钮。
  final VoidCallback? onAddSubtask;

  final bool isStarred;
  final VoidCallback? onToggleStar;

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
        clipBehavior: Clip.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: _buildContentArea(context),
              ),
            ),
            if (mode == BigTaskCardMode.collect)
              _keyboardLiftedFooter(
                context,
                [
                  const SizedBox(height: 8),
                  _buildScheduleCheckInEditorsRow(
                    scheduleEditor: scheduleEditor,
                    checkInEditor: checkInEditor,
                  ),
                  const SizedBox(height: 16),
                  _buildToolbarRow(
                    context,
                    showCancel: editing,
                  ),
                ],
              )
            else if (mode == BigTaskCardMode.process && task != null)
              editing
                  ? _keyboardLiftedFooter(
                      context,
                      [
                        const SizedBox(height: 12),
                        _buildScheduleCheckInEditorsRow(
                          scheduleEditor: scheduleEditor,
                          checkInEditor: checkInEditor,
                        ),
                        const SizedBox(height: 8),
                        _buildToolbarRow(
                          context,
                          showCancel: true,
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: onComplete,
                                icon: const Icon(Icons.check, size: 20),
                                label: Text(completeLabel),
                                style: FilledButton.styleFrom(
                                  backgroundColor: context.semanticColors.success,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: onSomeday,
                                icon: const Icon(Icons.lightbulb_outline),
                                tooltip: '将来也许',
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
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCheckInEditorsRow({
    required Widget? scheduleEditor,
    required Widget? checkInEditor,
  }) {
    if (scheduleEditor == null &&
        checkInEditor == null &&
        onToggleStar == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        if (onToggleStar != null) ...[
          TaskStarButton(
            isStarred: isStarred,
            onToggle: onToggleStar!,
            compact: true,
          ),
          if (scheduleEditor != null || checkInEditor != null)
            const SizedBox(width: 8),
        ],
        if (scheduleEditor != null) scheduleEditor,
        if (scheduleEditor != null && checkInEditor != null)
          const SizedBox(width: 8),
        if (checkInEditor != null) checkInEditor,
      ],
    );
  }

  Widget _buildToolbarRow(
    BuildContext context, {
    required bool showCancel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    const compact = VisualDensity.compact;
    const gap = SizedBox(width: 4);

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onPickImage,
          icon: const Icon(Icons.image_outlined),
          tooltip: '添加图片',
          visualDensity: compact,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        gap,
        IconButton.filledTonal(
          onPressed: onStartSpeech,
          icon: Icon(
            isListening ? Icons.stop : Icons.mic_none_outlined,
          ),
          tooltip: isListening ? '停止录音' : '录音',
          visualDensity: compact,
          style: IconButton.styleFrom(
            backgroundColor:
                isListening ? colorScheme.errorContainer : null,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        if (onAddSubtask != null) ...[
          gap,
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: IconButton.filledTonal(
              onPressed: onAddSubtask,
              icon: const Icon(Icons.playlist_add_outlined),
              tooltip: '添加子任务',
              visualDensity: compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (showCancel) ...[
          TextButton(
            onPressed: onCancelEdit,
            style: TextButton.styleFrom(
              visualDensity: compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('取消'),
          ),
          gap,
        ],
        Focus(
          canRequestFocus: false,
          child: FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              visualDensity: compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }

  Widget _keyboardLiftedFooter(BuildContext context, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return KeyboardLift(
      bottomObstruction: shellBottomObstruction(context),
      backgroundColor: colorScheme.surfaceContainerHighest,
      child: SuppressTapHaptic(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea(BuildContext context) {
    return _buildContent(context);
  }

  /// 只读态用 [GestureDetector.onTap] 进入编辑，避免 pointerDown 立刻禁用滑动手势。
  /// 编辑态仍用 [Listener] 在 pointerDown 时聚焦，此时滑动已关闭。
  Widget _wrapProcessContent(
    BuildContext context, {
    required bool pendingTitle,
    required Task displayTask,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final titleField = _buildFlexibleTitleField(
      context,
      fieldController: controller!,
      readOnly: !editing,
      textColor: pendingTitle && !editing
          ? colorScheme.onSurface.withValues(alpha: 0.45)
          : null,
    );

    final titleWidget = editing
        ? Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (focusNode != null && !focusNode!.hasFocus) {
                focusNode!.requestFocus();
              }
            },
            child: titleField,
          )
        // 只读标题不参与命中测试，避免 TextField.onTap 抢走点击导致无法聚焦。
        : IgnorePointer(child: titleField);

    final content = SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: keyboardContentScrollPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (parentTitle != null && parentTitle!.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTapParent,
                icon: const Icon(Icons.subdirectory_arrow_left, size: 18),
                label: Text(
                  parentTitle!,
                  overflow: TextOverflow.ellipsis,
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          titleWidget,
          if (isStarred) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.star, color: Colors.amber, size: 24),
            ),
          ],
          if (editing && subtaskEditor != null) ...[
            const SizedBox(height: 20),
            subtaskEditor!,
          ],
          if (!editing) ...[
            if (scheduleLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                scheduleLabel!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheduleOverdue
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
              ),
            ],
            if (checkInLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                checkInLabel!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              if (onResetCheckInProgress != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onResetCheckInProgress,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    child: const Text('重置进度'),
                  ),
                ),
              ],
            ],
            if (displayTask.attachments.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayTask.attachments.map((a) {
                  return _AttachmentThumbnail(
                    attachment: a,
                    imageAttachments: _imageAttachments(displayTask.attachments),
                    audioAttachments: _audioAttachments(displayTask.attachments),
                  );
                }).toList(),
              ),
            ],
            if (subtaskSection != null) ...[
              const SizedBox(height: 20),
              subtaskSection!,
            ],
          ],
        ],
      ),
    );

    if (editing) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onEnterEdit,
      child: content,
    );
  }

  /// 不撑满父级高度，避免键盘动画期间逐帧重排；空白区由 [Listener] 负责聚焦。
  Widget _buildFlexibleTitleField(
    BuildContext context, {
    required TextEditingController fieldController,
    required bool readOnly,
    String? hintText,
    InputDecoration? decoration,
    VoidCallback? onTap,
    bool autofocus = false,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: fieldController,
        focusNode: focusNode,
        readOnly: readOnly,
        autofocus: autofocus,
        showCursor: !readOnly,
        cursorColor: colorScheme.primary,
        onTap: readOnly ? onTap : null,
        onChanged: onChanged,
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textAlignVertical: TextAlignVertical.top,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: textColor ?? colorScheme.onSurface,
          height: 1.35,
        ),
        decoration: decoration ??
            (hintText != null
                ? InputDecoration(hintText: hintText)
                : const InputDecoration(border: InputBorder.none)),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (mode == BigTaskCardMode.collect) {
      final scrollContent = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => onActivateInput?.call(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: keyboardContentScrollPadding(context),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Opacity(
                      opacity: feedback == CollectCardFeedback.emptyHint ||
                              feedback == CollectCardFeedback.listening
                          ? 0
                          : 1,
                      child: _buildFlexibleTitleField(
                        context,
                        fieldController: controller!,
                        readOnly: false,
                        hintText: '记下一件事…',
                      ),
                    ),
                    if (subtaskEditor != null) ...[
                      const SizedBox(height: 12),
                      subtaskEditor!,
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );

      final hasFeedbackOverlay = feedback == CollectCardFeedback.emptyHint ||
          feedback == CollectCardFeedback.listening;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: hasFeedbackOverlay
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      scrollContent,
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
                  )
                : scrollContent,
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
      final pendingTitle = displayTask.title.trim().isEmpty &&
          displayTask.transcriptionStatus == TranscriptionStatus.pending;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _wrapProcessContent(
              context,
              pendingTitle: pendingTitle,
              displayTask: displayTask,
            ),
          ),
          if (editing && attachments.isNotEmpty) ...[
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

    return const SizedBox.shrink();
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
