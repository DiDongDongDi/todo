import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/settings/process_sound_settings.dart';
import 'package:todo_app/core/stats/stats_provider.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/core/transcription/transcription_service.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/utils/sounds.dart';
import 'package:todo_app/shared/utils/platform_capabilities.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';
import 'package:todo_app/shared/widgets/card_stage.dart';
import 'package:todo_app/shared/widgets/progress_widgets.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';

class ProcessScreen extends ConsumerStatefulWidget {
  const ProcessScreen({super.key});

  @override
  ConsumerState<ProcessScreen> createState() => _ProcessScreenState();
}

class _ProcessScreenState extends ConsumerState<ProcessScreen> {
  int _index = 0;
  bool _editing = false;
  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();
  final _swipeKey = GlobalKey<SwipeableCardState>();
  Task? _lastUndoTask;
  TaskStatus? _lastUndoFrom;

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  Future<void> _undo() async {
    final task = _lastUndoTask;
    final from = _lastUndoFrom;
    if (task == null || from == null) return;

    final enterFromLeft = from == TaskStatus.trashed;
    final enterFromRight = from == TaskStatus.archived;
    if (!enterFromLeft && !enterFromRight) return;

    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.restoreToInbox(task.id);
    final tasks = await repo.watchInbox().first;

    _lastUndoTask = null;
    _lastUndoFrom = null;

    if (!mounted) return;

    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index < 0) return;

    setState(() {
      _index = index;
      _editing = false;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final state = _swipeKey.currentState;
    if (state != null) {
      await state.resetPosition(
        enterFromLeft: enterFromLeft,
        enterFromRight: enterFromRight,
      );
    }
  }

  void _showUndoSnackbar({
    required String message,
    required IconData icon,
    required AppSnackType type,
  }) {
    showAppSnackBar(
      context,
      message: message,
      icon: icon,
      type: type,
      action: SnackBarAction(
        label: '撤销',
        onPressed: _undo,
      ),
    );
  }

  Future<void> _animateFlyout(
    Offset flyout,
    Future<void> Function() action,
  ) async {
    final state = _swipeKey.currentState;
    if (state != null) {
      await state.animateFlyout(flyout, action);
    } else {
      await action();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(inboxTasksProvider);
    final statsAsync = ref.watch(statsProvider);
    final touchFirst = isTouchFirstPlatform;

    return inboxAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                '收集箱是空的，去收集页记一条吧',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        final clampedIndex = _index.clamp(0, tasks.length - 1);
        if (clampedIndex != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index = clampedIndex);
          });
        }
        final task = tasks[clampedIndex];
        final archivedToday = statsAsync.value?.archivedToday ?? 0;
        final progress = inboxProgress(archivedToday, tasks.length);

        final shortcuts = _editing
            ? {
                const SingleActivator(LogicalKeyboardKey.enter): () =>
                    _saveEdit(task),
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    setState(() => _editing = false),
              }
            : {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _trash(task, animated: true),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _archive(task, animated: true),
                const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                    _setIndex(clampedIndex - 1, tasks.length, animated: true),
                const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                    _setIndex(clampedIndex + 1, tasks.length, animated: true),
              };

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  ProcessProgressRing(
                    completed: archivedToday,
                    total: archivedToday + tasks.length,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${tasks.length} 待处理',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.task_alt_outlined),
                    tooltip: '已完成',
                    onPressed: () => context.push('/archive'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '回收站',
                    onPressed: () => context.push('/trash'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sync_outlined),
                    tooltip: '同步',
                    onPressed: () => context.push('/auth'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CardStage(
                swipeKey: _swipeKey,
                enabled: touchFirst && !_editing,
                verticalEnterAnimation: true,
                shouldAnimateFlyout: (flyout) async {
                  if (flyout.dy < 0) return clampedIndex < tasks.length - 1;
                  if (flyout.dy > 0) return clampedIndex > 0;
                  return true;
                },
                onSwipeLeft: () => _trash(task),
                onSwipeRight: () => _archive(task),
                onSwipeUp: () =>
                    _setIndex(clampedIndex + 1, tasks.length),
                onSwipeDown: () =>
                    _setIndex(clampedIndex - 1, tasks.length),
                child: GestureDetector(
                  onTap: _editing ? null : () => _startEdit(task),
                  child: BigTaskCard(
                    mode: _editing
                        ? BigTaskCardMode.process
                        : BigTaskCardMode.readOnly,
                    task: task,
                    controller: _editing ? _editController : null,
                    focusNode: _editing ? _editFocusNode : null,
                    onChanged: _editing ? (_) => setState(() {}) : null,
                    onTrash: () => _trash(task, animated: true),
                    onComplete: () => _archive(task, animated: true),
                    onPrevious: () => _setIndex(
                      clampedIndex - 1,
                      tasks.length,
                      animated: true,
                    ),
                    onNext: () => _setIndex(
                      clampedIndex + 1,
                      tasks.length,
                      animated: true,
                    ),
                    canGoPrevious: clampedIndex > 0,
                    canGoNext: clampedIndex < tasks.length - 1,
                    onRetryTranscription: task.canRetryTranscription
                        ? () => _retryTranscription(task)
                        : null,
                  ),
                ),
              ),
            ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _editing = false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: () => _saveEdit(task),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            if (progress >= 1 && tasks.isNotEmpty) const SizedBox(height: 4),
          ],
        );

        if (kIsWeb) return content;

        return CallbackShortcuts(
          bindings: shortcuts,
          child: Focus(
            autofocus: !_editing,
            child: content,
          ),
        );
      },
    );
  }

  Future<void> _setIndex(
    int newIndex,
    int length, {
    bool animated = false,
  }) async {
    final clamped = newIndex.clamp(0, length - 1);
    if (clamped == _index) return;

    Future<void> apply() async {
      setState(() {
        _index = clamped;
        _editing = false;
      });
      AppHaptics.selection();
    }

    if (animated) {
      final delta = clamped - _index;
      final flyout =
          delta > 0 ? const Offset(0, -1.5) : const Offset(0, 1.5);
      await _animateFlyout(flyout, apply);
    } else {
      await apply();
    }
  }

  void _startEdit(Task task) {
    _editController.text = task.title;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
    });
  }

  Future<void> _saveEdit(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.update(task.copyWith(title: _editController.text.trim()));
    setState(() => _editing = false);
  }

  Future<void> _archive(Task task, {bool animated = false}) async {
    if (animated) {
      await _animateFlyout(
        const Offset(1.5, 0),
        () => _performArchive(task),
      );
    } else {
      await _performArchive(task);
    }
  }

  Future<void> _performArchive(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.archive(task.id);

    _lastUndoTask = task;
    _lastUndoFrom = TaskStatus.archived;
    _showUndoSnackbar(
      message: '已完成',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
    if (mounted) {
      final remaining = (ref.read(inboxTasksProvider).value?.length ?? 1) - 1;
      if (remaining <= 0) showCelebrateOverlay(context);
    }

    unawaited(triggerSyncIfSignedIn(ref));
    unawaited(ref.read(statsProvider.notifier).recordArchive());
    unawaited(_playCompleteFeedback());
  }

  Future<void> _playCompleteFeedback() async {
    final settings = await ref.read(processSoundProvider.future);
    await Future.wait([
      AppHaptics.medium(),
      AppSounds.play(settings.complete),
    ]);
  }

  Future<void> _retryTranscription(Task task) async {
    await ref.read(transcriptionServiceProvider).retryTask(task);
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '正在重新转写…',
      icon: Icons.mic_none_outlined,
      type: AppSnackType.info,
    );
  }

  Future<void> _trash(Task task, {bool animated = false}) async {
    if (animated) {
      await _animateFlyout(
        const Offset(-1.5, 0),
        () => _performTrash(task),
      );
    } else {
      await _performTrash(task);
    }
  }

  Future<void> _performTrash(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.trash(task.id);

    _lastUndoTask = task;
    _lastUndoFrom = TaskStatus.trashed;
    _showUndoSnackbar(
      message: '已移至回收站',
      icon: Icons.delete_outline,
      type: AppSnackType.error,
    );

    unawaited(triggerSyncIfSignedIn(ref));
    unawaited(_playTrashFeedback());
  }

  Future<void> _playTrashFeedback() async {
    final settings = await ref.read(processSoundProvider.future);
    await Future.wait([
      AppHaptics.medium(),
      AppSounds.play(settings.trash),
    ]);
  }
}
