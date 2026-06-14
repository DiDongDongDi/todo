import 'package:flutter/material.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';
import 'package:todo_app/shared/widgets/haptic_tap_scope.dart';
import 'package:todo_app/shared/widgets/keyboard_lift.dart';

/// 任务卡片底部栏切换动画时长（与 screen 层 footer grace 对齐）。
const kTaskCardFooterDuration = Duration(milliseconds: 200);

enum ProcessFooterMode { edit, action }

/// 收集/处理页共用的底部工具栏，带高度平滑与淡入淡出过渡。
class TaskCardFooter extends StatelessWidget {
  const TaskCardFooter._({
    required this.child,
  });

  final Widget child;

  /// 收集页底部：计划行 + 工具行（取消按钮可淡入淡出）。
  factory TaskCardFooter.collect({
    required BuildContext context,
    required bool showCancel,
    Widget? scheduleRow,
    required VoidCallback? onPickImage,
    required VoidCallback? onStartSpeech,
    required bool isListening,
    required VoidCallback? onCancelEdit,
    required VoidCallback? onSave,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TaskCardFooter._(
      child: _FooterShell(
        context: context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (scheduleRow != null) ...[
              const SizedBox(height: 8),
              scheduleRow,
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
                  icon: Icon(
                    isListening ? Icons.stop : Icons.mic_none_outlined,
                  ),
                  tooltip: isListening ? '停止录音' : '录音',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        isListening ? colorScheme.errorContainer : null,
                  ),
                ),
                const Spacer(),
                _AnimatedCancelSlot(
                  visible: showCancel,
                  onCancelEdit: onCancelEdit,
                ),
                Focus(
                  canRequestFocus: false,
                  child: FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 处理页底部：编辑栏与操作栏在同一 KeyboardLift 内切换。
  factory TaskCardFooter.process({
    required BuildContext context,
    required ProcessFooterMode mode,
    Widget? scheduleRow,
    required VoidCallback? onPickImage,
    required VoidCallback? onStartSpeech,
    required bool isListening,
    required VoidCallback? onCancelEdit,
    required VoidCallback? onSave,
    required VoidCallback? onSomeday,
    required VoidCallback? onComplete,
    required String completeLabel,
    required bool showRetryTranscription,
    required VoidCallback? onRetryTranscription,
    required VoidCallback? onPrevious,
    required VoidCallback? onNext,
    required bool canGoPrevious,
    required bool canGoNext,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;

    final editFooter = Column(
      key: const ValueKey('process_edit'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        if (scheduleRow != null) scheduleRow,
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

    final actionFooter = Column(
      key: const ValueKey('process_action'),
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
                backgroundColor: semanticColors.success,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onSomeday,
              icon: const Icon(Icons.lightbulb_outline),
              tooltip: '将来也许',
            ),
            if (showRetryTranscription && onRetryTranscription != null) ...[
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
    );

    return TaskCardFooter._(
      child: _FooterShell(
        context: context,
        child: AnimatedSwitcher(
          duration: kTaskCardFooterDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: _fadeTransition,
          child: mode == ProcessFooterMode.edit ? editFooter : actionFooter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => child;
}

class _FooterShell extends StatelessWidget {
  const _FooterShell({
    required this.context,
    required this.child,
  });

  final BuildContext context;
  final Widget child;

  @override
  Widget build(BuildContext buildContext) {
    return KeyboardLift(
      bottomObstruction: shellBottomObstruction(context),
      child: AnimatedSize(
        duration: kTaskCardFooterDuration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: SuppressTapHaptic(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AnimatedCancelSlot extends StatelessWidget {
  const _AnimatedCancelSlot({
    required this.visible,
    required this.onCancelEdit,
  });

  final bool visible;
  final VoidCallback? onCancelEdit;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: kTaskCardFooterDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: AnimatedSwitcher(
        duration: kTaskCardFooterDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: _fadeTransition,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.centerRight,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: visible
            ? Row(
                key: const ValueKey('cancel'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: onCancelEdit,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                ],
              )
            : const SizedBox.shrink(key: ValueKey('no_cancel')),
      ),
    );
  }
}

Widget _fadeTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}
