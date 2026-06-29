import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_check_in.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/navigation/shell_navigation.dart';
import 'package:todo_app/core/repositories/playlist_repository.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/settings/process_queue_source_settings.dart';
import 'package:todo_app/core/settings/process_sound_settings.dart';
import 'package:todo_app/core/settings/restore_sound_settings.dart';
import 'package:todo_app/core/settings/volume_key_platform.dart';
import 'package:todo_app/core/settings/volume_key_settings.dart';
import 'package:todo_app/core/stats/stats_provider.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/core/transcription/transcription_service.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';
import 'package:todo_app/shared/utils/app_audio_recorder.dart';
import 'package:todo_app/shared/utils/attachment_storage.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/utils/sounds.dart';
import 'package:todo_app/shared/utils/platform_capabilities.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';
import 'package:todo_app/shared/widgets/card_deck_transition.dart';
import 'package:todo_app/shared/widgets/card_stage.dart';
import 'package:todo_app/shared/widgets/process_queue_selector.dart';
import 'package:todo_app/shared/widgets/process_task_search_sheet.dart';
import 'package:todo_app/shared/widgets/progress_widgets.dart';
import 'package:todo_app/shared/utils/template_save_flow.dart';
import 'package:todo_app/shared/widgets/save_template_dialog.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';
import 'package:todo_app/shared/widgets/tab_more_menu_button.dart';
import 'package:todo_app/shared/widgets/task_check_in_editor.dart';
import 'package:todo_app/shared/widgets/task_schedule_editor.dart';
import 'package:todo_app/core/settings/volume_key_handler.dart';

class ProcessScreen extends ConsumerStatefulWidget {
  const ProcessScreen({super.key, this.isActive = true});

  /// 当前是否为 Shell 中选中的 tab；失活时强制退出编辑 UI。
  final bool isActive;

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
  bool _lastUndoWasPeriodCompletion = false;
  bool _lastUndoWasPartialCheckIn = false;
  bool _lastUndoWasRestoreToInbox = false;

  TaskRecurrence _editRecurrence = TaskRecurrence.none;
  DateTime? _editDailyUntil;
  DateTime? _editDueDate;
  int _editCheckInTarget = 1;
  bool _editIsStarred = false;
  final List<TaskAttachment> _editAttachments = [];
  bool _editRecording = false;
  final _editAudioRecorder = AppAudioRecorder();
  bool _editPendingFocus = false;
  int _transientUiDepth = 0;

  String? _subtasksTaskId;
  List<Task> _subtasks = const [];
  final List<TextEditingController> _editSubtaskControllers = [];
  bool _editSubtaskFocused = false;
  bool _savingEdit = false;
  bool _shuffling = false;

  bool _deckTransitionActive = false;
  CardDeckTransitionMode? _deckMode;
  Task? _deckTopTask;
  Task? _deckBottomTask;
  Completer<void>? _deckTransitionCompleter;
  TextEditingController? _deckPreviewTopController;
  TextEditingController? _deckPreviewBottomController;

  /// 与收集页一致：底部按钮组由焦点驱动；tab 不可见时一律视为非编辑 UI。
  bool get _editUiVisible =>
      widget.isActive &&
      (_editFocusNode.hasFocus ||
          _editSubtaskFocused ||
          _editRecording ||
          _editPendingFocus ||
          _transientUiDepth > 0);

  @override
  void initState() {
    super.initState();
    _editFocusNode.addListener(_onEditFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVolumeKeyHandler());
  }

  @override
  void didUpdateWidget(ProcessScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (oldWidget.isActive && !widget.isActive) {
          _handleTabHidden();
        } else {
          _syncVolumeKeyHandler();
        }
      });
    }
  }

  void _syncVolumeKeyHandler() {
    final enabled = ref.read(volumeKeyShortcutsProvider).value ?? false;
    ref.read(volumeKeyHandlerProvider.notifier).setProcessBlocked(_editUiVisible);
    if (widget.isActive && enabled && !_editUiVisible) {
      ref.read(volumeKeyHandlerProvider.notifier).registerProcess(_handleVolumeKey);
    } else {
      ref.read(volumeKeyHandlerProvider.notifier).registerProcess(null);
    }
  }

  void _handleVolumeKey(VolumeKeyDirection direction) {
    final tasks = ref.read(processTasksProvider).value;
    if (tasks == null || tasks.isEmpty) return;
    final clampedIndex = _index.clamp(0, tasks.length - 1);
    switch (direction) {
      case VolumeKeyDirection.up:
        unawaited(_setIndex(clampedIndex - 1, tasks.length, animated: true));
      case VolumeKeyDirection.down:
        unawaited(_setIndex(clampedIndex + 1, tasks.length, animated: true));
    }
  }

  void _handleTabHidden() {
    _editPendingFocus = false;
    _transientUiDepth = 0;
    _editSubtaskFocused = false;
    _editFocusNode.unfocus();
    if (_editRecording) {
      _editRecording = false;
      unawaited(_editAudioRecorder.stop());
    }
    final task = _taskForBlurExit();
    _clearEditSubtaskFields();
    setState(() => _editing = false);
    if (task != null) {
      _syncDisplayFromTask(task);
    }
    _syncVolumeKeyHandler();
  }

  @override
  void dispose() {
    ref.read(volumeKeyHandlerProvider.notifier).registerProcess(null);
    ref.read(volumeKeyHandlerProvider.notifier).setProcessBlocked(false);
    _editFocusNode.removeListener(_onEditFocusChange);
    _editController.dispose();
    _editFocusNode.dispose();
    for (final c in _editSubtaskControllers) {
      c.dispose();
    }
    _deckPreviewTopController?.dispose();
    _deckPreviewBottomController?.dispose();
    unawaited(_editAudioRecorder.dispose());
    super.dispose();
  }

  void _onDeckTransitionComplete() {
    final completer = _deckTransitionCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _clearDeckTransitionState() {
    _deckTransitionCompleter = null;
    _deckPreviewTopController?.dispose();
    _deckPreviewTopController = null;
    _deckPreviewBottomController?.dispose();
    _deckPreviewBottomController = null;
    setState(() {
      _deckTransitionActive = false;
      _deckMode = null;
      _deckTopTask = null;
      _deckBottomTask = null;
    });
  }

  Widget _buildTransitionPreviewCard(
    Task task,
    TextEditingController controller,
  ) {
    return BigTaskCard(
      mode: BigTaskCardMode.process,
      editing: false,
      task: task,
      controller: controller,
      scheduleLabel: scheduleLabel(task),
      scheduleOverdue: isOverdue(task),
      checkInLabel: checkInLabel(task),
      completeLabel: completeLabelForCheckIn(task),
      canGoPrevious: false,
      canGoNext: false,
      isStarred: task.isStarred,
    );
  }

  Widget _buildDeckTransition() {
    return CardDeckTransition(
      key: ValueKey(
        'deck-${_deckMode?.name}-${_deckTopTask?.id}-${_deckBottomTask?.id}',
      ),
      mode: _deckMode!,
      topChild: _deckTopTask != null && _deckPreviewTopController != null
          ? _buildTransitionPreviewCard(
              _deckTopTask!,
              _deckPreviewTopController!,
            )
          : null,
      bottomChild: _deckBottomTask != null && _deckPreviewBottomController != null
          ? _buildTransitionPreviewCard(
              _deckBottomTask!,
              _deckPreviewBottomController!,
            )
          : null,
      onComplete: _onDeckTransitionComplete,
    );
  }

  Task? _taskForBlurExit() {
    final tasks = ref.read(processTasksProvider).value;
    if (tasks == null || tasks.isEmpty) return null;
    return tasks[_index.clamp(0, tasks.length - 1)];
  }

  void _onEditFocusChange() {
    if (!mounted) return;
    if (_editFocusNode.hasFocus) {
      _editPendingFocus = false;
      _ensureEditCaretVisible();
      setState(() {});
      _syncVolumeKeyHandler();
      return;
    }
    if (_editRecording ||
        _editSubtaskFocused ||
        _transientUiDepth > 0) {
      setState(() {});
      _syncVolumeKeyHandler();
      return;
    }
    // 延迟一帧再切换按钮，避免失焦后「保存/取消」被换掉导致 onPressed 丢失。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_editFocusNode.hasFocus ||
          _editSubtaskFocused ||
          _editRecording ||
          _transientUiDepth > 0) {
        return;
      }
      setState(() {});
      _syncVolumeKeyHandler();
      _scheduleEditSessionCleanup();
    });
  }

  void _scheduleEditSessionCleanup() {
    if (_savingEdit || _editUiVisible || !_editing) return;
    _exitEditMode(_taskForBlurExit());
  }

  void _beginTransientEditUi() {
    _transientUiDepth++;
    _syncVolumeKeyHandler();
  }

  void _endTransientEditUi() {
    if (_transientUiDepth > 0) _transientUiDepth--;
    if (!mounted) return;
    setState(() {});
    _syncVolumeKeyHandler();
    if (_editing && !_editUiVisible) {
      _editPendingFocus = true;
      unawaited(_requestEditFocus());
      return;
    }
    _scheduleEditSessionCleanup();
  }

  void _loadSubtasksIfNeeded(Task task) {
    if (task.isSubtask) {
      if (_subtasksTaskId != null) {
        setState(() {
          _subtasksTaskId = null;
          _subtasks = const [];
        });
      }
      return;
    }
    final parentId = task.id;
    if (_subtasksTaskId != parentId) {
      setState(() {
        _subtasksTaskId = parentId;
        _subtasks = const [];
      });
    }
    unawaited(_fetchSubtasks(parentId));
  }

  Future<void> _fetchSubtasks(String parentId) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    final subtasks = await repo.getSubtasks(parentId);
    if (!mounted || _subtasksTaskId != parentId) return;
    setState(() => _subtasks = subtasks);
  }

  void _addEditSubtaskField() {
    unawaited(AppHaptics.light());
    _editPendingFocus = true;
    setState(() => _editSubtaskControllers.add(TextEditingController()));
  }

  Future<int> _submitEditSubtaskRow(int index) async {
    _editPendingFocus = true;
    setState(() {
      _editSubtaskControllers.insert(index + 1, TextEditingController());
    });
    return index + 1;
  }

  void _removeEditSubtaskField(int index) {
    setState(() {
      _editSubtaskControllers[index].dispose();
      _editSubtaskControllers.removeAt(index);
    });
  }

  void _importEditSubtaskLines(int index, List<String> lines) {
    setState(() {
      SubtaskTitleEditor.importLinesIntoControllers(
        controllers: _editSubtaskControllers,
        index: index,
        lines: lines,
      );
    });
  }

  void _onEditSubtaskFocusChanged(bool focused) {
    if (_editSubtaskFocused == focused) return;
    setState(() => _editSubtaskFocused = focused);
    _syncVolumeKeyHandler();
    if (focused) {
      _editPendingFocus = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_editSubtaskFocused || _editPendingFocus) return;
      _scheduleEditSessionCleanup();
    });
  }

  void _clearEditSubtaskFields() {
    for (final c in _editSubtaskControllers) {
      c.dispose();
    }
    _editSubtaskControllers.clear();
  }

  List<String> get _editSubtaskTitles =>
      SubtaskTitleEditor.nonEmptyTitles(_editSubtaskControllers);

  Future<List<Task>> _createEditSubtasks(
    String parentId,
    List<String> titles,
  ) async {
    if (titles.isEmpty) return const [];

    final repo = await ref.read(taskRepositoryProvider.future);
    final created = <Task>[];
    for (final title in titles) {
      created.add(await repo.createSubtask(parentId: parentId, title: title));
    }
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return created;
    await _fetchSubtasks(parentId);
    return created;
  }

  Future<List<Task>> _waitForProcessTask(String taskId) async {
    for (var i = 0; i < 30; i++) {
      final tasks = ref.read(processTasksProvider).value;
      if (tasks != null && tasks.any((t) => t.id == taskId)) {
        return tasks;
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    return ref.read(processTasksProvider).value ?? [];
  }

  Future<void> _undo() async {
    final task = _lastUndoTask;
    final from = _lastUndoFrom;
    final wasPeriod = _lastUndoWasPeriodCompletion;
    final wasPartialCheckIn = _lastUndoWasPartialCheckIn;
    if (task == null || from == null) return;

    Future<void> restoreAndSwitch() async {
      final repo = await ref.read(taskRepositoryProvider.future);
      if (from == TaskStatus.trashed) {
        await repo.restoreToInbox(task.id);
      } else if (wasPartialCheckIn) {
        await repo.undoCheckIn(task.id, wasFinalCompletion: false);
      } else if (wasPeriod) {
        if (hasCheckInGoal(task)) {
          await repo.undoCheckIn(task.id, wasFinalCompletion: true);
        } else {
          await repo.undoDailyCompletion(task.id);
        }
      } else if (_lastUndoWasRestoreToInbox) {
        await repo.moveToSomeday(task.id);
      } else if (hasCheckInGoal(task)) {
        await repo.undoCheckIn(task.id, wasFinalCompletion: true);
      } else {
        await repo.restoreToInbox(task.id);
      }

      final tasks = await _waitForProcessTask(task.id);
      if (!mounted) return;

      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index < 0) return;

      _lastUndoTask = null;
      _lastUndoFrom = null;
      _lastUndoWasPeriodCompletion = false;
      _lastUndoWasPartialCheckIn = false;
      _lastUndoWasRestoreToInbox = false;
      setState(() {
        _index = index;
        _editing = false;
      });
      AppHaptics.light();
    }

    if (from == TaskStatus.trashed) {
      await _undoTrashWithDeckAnimation(task, restoreAndSwitch);
      return;
    }

    final enterFromLeft = from == TaskStatus.archived ||
        wasPeriod ||
        wasPartialCheckIn;
    final enterFromRight = from == TaskStatus.someday ||
        _lastUndoWasRestoreToInbox;
    if (!enterFromLeft && !enterFromRight) return;

    Future<void> playEnterAnimation() async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _swipeKey.currentState?.resetPosition(
        enterFromLeft: enterFromLeft,
        enterFromRight: enterFromRight,
      );
    }

    final state = _swipeKey.currentState;
    if (state != null) {
      await state.animateFlyout(
        const Offset(0, 1.5),
        restoreAndSwitch,
        resetAfter: false,
        feedback: AppHaptics.none,
      );
      if (!mounted) return;
      await playEnterAnimation();
    } else {
      await restoreAndSwitch();
      if (!mounted) return;
      await playEnterAnimation();
    }
  }

  Future<void> _undoTrashWithDeckAnimation(
    Task restoredTask,
    Future<void> Function() restoreAndSwitch,
  ) async {
    if (_deckTransitionActive) return;

    final tasks = ref.read(processTasksProvider).value ?? [];
    final currentTask = tasks.isNotEmpty
        ? tasks[_index.clamp(0, tasks.length - 1)]
        : null;

    _deckPreviewTopController?.dispose();
    _deckPreviewBottomController?.dispose();
    _deckPreviewTopController = currentTask != null
        ? TextEditingController(text: currentTask.displayTitle)
        : null;
    _deckPreviewBottomController =
        TextEditingController(text: restoredTask.displayTitle);

    _deckTransitionCompleter = Completer<void>();

    setState(() {
      _deckTransitionActive = true;
      _deckMode = CardDeckTransitionMode.undoRestore;
      _deckTopTask = currentTask;
      _deckBottomTask = restoredTask;
    });

    await _deckTransitionCompleter!.future;
    if (!mounted) return;

    await restoreAndSwitch();
    if (!mounted) return;

    _clearDeckTransitionState();
    await _swipeKey.currentState?.resetPosition(animated: false);
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
    Future<void> Function() action, {
    FlyoutFeedback? feedback,
  }) async {
    final state = _swipeKey.currentState;
    if (state != null) {
      await state.animateFlyout(flyout, action, feedback: feedback);
    } else {
      await action();
    }
  }

  Future<void> _shuffleProcessQueue(List<Task> tasks) async {
    if (tasks.length <= 1 || _shuffling || _editUiVisible) return;

    setState(() => _shuffling = true);
    try {
      await _animateFlyout(const Offset(0, -1.5), () async {
        final shuffled = List<Task>.from(tasks)..shuffle();
        final repo = await ref.read(taskRepositoryProvider.future);
        await repo.reorderInboxTasks(shuffled);
        unawaited(triggerSyncIfSignedIn(ref));
        await _waitForProcessTask(shuffled.first.id);
        if (!mounted) return;
        _editFocusNode.unfocus();
        setState(() {
          _index = 0;
          _editing = false;
        });
        AppHaptics.medium();
      });
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '任务顺序已随机打散',
        icon: Icons.shuffle,
        type: AppSnackType.success,
      );
    } finally {
      if (mounted) setState(() => _shuffling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(volumeKeyShortcutsProvider, (_, __) => _syncVolumeKeyHandler());
    ref.listen(processNavigationIntentProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _handleNavigationIntent(next);
      });
    });

    final tasksAsync = ref.watch(processTasksProvider);
    final queueSourceAsync = ref.watch(processQueueSourceProvider);
    final statsAsync = ref.watch(statsProvider);
    final searchableAsync = ref.watch(searchableProcessTasksProvider);
    final canSearch = (searchableAsync.value ?? []).isNotEmpty;
    final touchFirst = isTouchFirstPlatform;
    final queueSource = queueSourceAsync.value ?? const ProcessQueueSource.inbox();

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          if (_deckTransitionActive) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(
                  context,
                  taskCount: 0,
                  archivedToday: statsAsync.value?.archivedToday ?? 0,
                  canSearch: canSearch,
                  onSearch: () => _openTaskSearch(),
                ),
                Expanded(child: _buildDeckTransition()),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(
                context,
                taskCount: 0,
                archivedToday: statsAsync.value?.archivedToday ?? 0,
                canSearch: canSearch,
                onSearch: () => _openTaskSearch(),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _emptyQueueMessage(queueSource),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final clampedIndex = _index.clamp(0, tasks.length - 1);
        if (clampedIndex != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index = clampedIndex);
          });
        }
        final task = tasks[clampedIndex];
        if (!_editing) {
          _syncDisplayFromTask(task);
        }
        final taskForSubtasks = task;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(processTasksProvider).value;
          if (current == null || current.isEmpty) return;
          final idx = _index.clamp(0, current.length - 1);
          if (current[idx].id != taskForSubtasks.id) return;
          _loadSubtasksIfNeeded(current[idx]);
        });
        final archivedToday = statsAsync.value?.archivedToday ?? 0;
        final progress = inboxProgress(archivedToday, tasks.length);
        final allInbox = ref.watch(inboxTasksProvider).value ?? [];
        String? parentTitle;
        if (task.parentId != null) {
          for (final t in allInbox) {
            if (t.id == task.parentId) {
              parentTitle = t.title;
              break;
            }
          }
        }

        final isSomedayQueue = queueSource.kind == ProcessQueueKind.someday;

        final shortcuts = _editUiVisible
            ? {
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  control: true,
                ): () => _saveEdit(task),
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  meta: true,
                ): () => _saveEdit(task),
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    _cancelEdit(task),
              }
            : {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _archive(task, animated: true),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    isSomedayQueue
                        ? _restoreToInbox(task, animated: true)
                        : _moveToSomeday(task, animated: true),
                const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                    _setIndex(clampedIndex - 1, tasks.length, animated: true),
                const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                    _setIndex(clampedIndex + 1, tasks.length, animated: true),
              };

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(
              context,
              taskCount: tasks.length,
              archivedToday: archivedToday,
              canSearch: canSearch,
              onSearch: () => _openTaskSearch(currentTask: task),
              onShuffle: () => _shuffleProcessQueue(tasks),
              onSaveTemplate: () => _saveCurrentAsTemplate(task),
              onDeleteCurrentTask:
                  _deckTransitionActive ? null : () => _trash(task),
            ),
            Expanded(
              child: _deckTransitionActive
                  ? _buildDeckTransition()
                  : CardStage(
                swipeKey: _swipeKey,
                enabled: touchFirst && !_editUiVisible && !_deckTransitionActive,
                verticalEnterAnimation: true,
                onFlyoutFeedback: AppHaptics.none,
                leftLabel: '完成',
                rightLabel: isSomedayQueue ? '移回收集箱' : '将来也许',
                leftBandColor: context.semanticColors.success,
                rightBandColor: Theme.of(context).colorScheme.primary,
                shouldAnimateFlyout: (flyout) async {
                  if (flyout.dy != 0) return tasks.length > 1;
                  return true;
                },
                onSwipeLeft: () => _archive(task),
                onSwipeRight: () => isSomedayQueue
                    ? _restoreToInbox(task)
                    : _moveToSomeday(task),
                onSwipeUp: () =>
                    _setIndex(clampedIndex + 1, tasks.length),
                onSwipeDown: () =>
                    _setIndex(clampedIndex - 1, tasks.length),
                child: BigTaskCard(
                  mode: BigTaskCardMode.process,
                  editing: _editUiVisible,
                  task: task,
                  controller: _editController,
                  focusNode: _editFocusNode,
                  onEnterEdit: () => _startEdit(task),
                  attachments:
                      _editUiVisible ? _editAttachments : task.attachments,
                  onRemoveAttachment:
                      _editUiVisible ? _removeEditAttachment : null,
                  onPickImage: _editUiVisible ? _pickEditImage : null,
                  onStartSpeech:
                      _editUiVisible && !kIsWeb ? _toggleEditRecording : null,
                  isListening: _editRecording,
                  onSave: _editUiVisible ? () => _saveEdit(task) : null,
                  onCancelEdit: _editUiVisible ? () => _cancelEdit(task) : null,
                  scheduleEditor: _editUiVisible
                      ? TaskScheduleEditor(
                          recurrence: _editRecurrence,
                          dailyUntil: _editDailyUntil,
                          dueDate: _editDueDate,
                          onRecurrenceChanged: (value) =>
                              setState(() => _editRecurrence = value),
                          onDailyUntilChanged: (value) =>
                              setState(() => _editDailyUntil = value),
                          onDueDateChanged: (value) =>
                              setState(() => _editDueDate = value),
                          onTransientUiOpening: _beginTransientEditUi,
                          onTransientUiClosed: _endTransientEditUi,
                        )
                      : null,
                  checkInEditor: _editUiVisible
                      ? TaskCheckInEditor(
                          checkInTarget: _editCheckInTarget,
                          onCheckInTargetChanged: (value) =>
                              setState(() => _editCheckInTarget = value),
                          onTransientUiOpening: _beginTransientEditUi,
                          onTransientUiClosed: _endTransientEditUi,
                        )
                      : null,
                  onSomeday: () => isSomedayQueue
                      ? _restoreToInbox(task, animated: true)
                      : _moveToSomeday(task, animated: true),
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
                  canGoPrevious: tasks.length > 1,
                  canGoNext: tasks.length > 1,
                  onRetryTranscription: task.canRetryTranscription
                      ? () => _retryTranscription(task)
                      : null,
                  scheduleLabel: scheduleLabel(task),
                  scheduleOverdue: isOverdue(task),
                  checkInLabel: checkInLabel(task),
                  onResetCheckInProgress: !_editUiVisible &&
                          hasResettableCheckInProgress(task)
                      ? () => _resetCheckInProgress(task)
                      : null,
                  completeLabel: completeLabelForCheckIn(task),
                  parentTitle: parentTitle,
                  onTapParent: task.parentId != null
                      ? () => context.push('/task/${task.parentId}')
                      : null,
                  subtaskSection: !task.isSubtask &&
                          !_editUiVisible &&
                          _subtasks.isNotEmpty
                      ? SubtaskListSection(subtasks: _subtasks)
                      : null,
                  subtaskEditor: !task.isSubtask && _editUiVisible
                      ? SubtaskTitleEditor(
                          controllers: _editSubtaskControllers,
                          onRemove: _removeEditSubtaskField,
                          onAnyFieldFocusChanged: _onEditSubtaskFocusChanged,
                          onSubmitRow: _submitEditSubtaskRow,
                          onImportLines: _importEditSubtaskLines,
                        )
                      : null,
                  onAddSubtask: !task.isSubtask && _editUiVisible
                      ? _addEditSubtaskField
                      : null,
                  isStarred: _editUiVisible ? _editIsStarred : task.isStarred,
                  onToggleStar: _editUiVisible
                      ? () => setState(() => _editIsStarred = !_editIsStarred)
                      : null,
                ),
              ),
            ),
            if (progress >= 1 && tasks.isNotEmpty) const SizedBox(height: 4),
          ],
        );

        if (kIsWeb) return content;

        return CallbackShortcuts(
          bindings: shortcuts,
          child: Focus(
            autofocus: !_editUiVisible && !_editing,
            child: content,
          ),
        );
      },
    );
  }

  int _wrapIndex(int index, int length) {
    if (length <= 0) return 0;
    return ((index % length) + length) % length;
  }

  Future<void> _setIndex(
    int newIndex,
    int length, {
    bool animated = false,
  }) async {
    if (length <= 0) return;
    if (length == 1) {
      if (_index != 0) {
        _editFocusNode.unfocus();
        setState(() {
          _index = 0;
          _editing = false;
        });
      }
      return;
    }

    final target = _wrapIndex(newIndex, length);
    if (target == _index) return;

    // Use raw newIndex so wrap-around keeps the swipe direction (up = next, down = prev).
    final forward = newIndex > _index;

    Future<void> apply() async {
      _editFocusNode.unfocus();
      setState(() {
        _index = target;
        _editing = false;
      });
      AppHaptics.selection();
    }

    if (animated) {
      final flyout =
          forward ? const Offset(0, -1.5) : const Offset(0, 1.5);
      await _animateFlyout(flyout, apply, feedback: AppHaptics.none);
    } else {
      await apply();
    }
  }

  void _syncDisplayFromTask(Task task) {
    if (_editing) return;
    final display = task.displayTitle;
    if (_editController.text != display) {
      _editController.text = display;
    }
  }

  void _syncEditDraftFromTask(Task task) {
    _editRecurrence = task.recurrence;
    _editDailyUntil = task.dailyUntil;
    _editDueDate = task.dueDate;
    _editCheckInTarget = task.checkInTarget;
    _editIsStarred = task.isStarred;
    _editAttachments
      ..clear()
      ..addAll(task.attachments);
  }

  void _ensureEditCaretVisible() {
    final text = _editController.text;
    _editController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _requestEditFocus() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_editing) return;

    _ensureEditCaretVisible();
    FocusScope.of(context).requestFocus(_editFocusNode);

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_editing) return;
    _ensureEditCaretVisible();
  }

  void _startEdit(Task task) {
    if (_editUiVisible) return;
    if (_editing) {
      _syncDisplayFromTask(task);
      _editing = false;
    }
    _editController.text = task.title;
    _editRecurrence = task.recurrence;
    _editDailyUntil = task.dailyUntil;
    _editDueDate = task.dueDate;
    _editCheckInTarget = task.checkInTarget;
    _editIsStarred = task.isStarred;
    _editAttachments
      ..clear()
      ..addAll(task.attachments);
    _editRecording = false;
    _clearEditSubtaskFields();
    _editPendingFocus = true;
    setState(() => _editing = true);
    _syncVolumeKeyHandler();
    unawaited(_requestEditFocus());
  }

  void _exitEditMode([Task? task]) {
    if (!_editing && !_editUiVisible) return;
    _editPendingFocus = false;
    _editSubtaskFocused = false;
    _clearEditSubtaskFields();
    setState(() => _editing = false);
    _editFocusNode.unfocus();
    if (task != null) {
      _syncDisplayFromTask(task);
      _syncEditDraftFromTask(task);
    }
    _syncVolumeKeyHandler();
  }

  void _cancelEdit(Task task) {
    unawaited(AppHaptics.light());
    _exitEditMode(task);
  }

  Future<void> _saveEdit(Task task) async {
    await AppHaptics.light();
    _savingEdit = true;
    final pendingSubtaskTitles = List<String>.from(_editSubtaskTitles);
    try {
      final repo = await ref.read(taskRepositoryProvider.future);
      final hasAudio =
          _editAttachments.any((a) => a.type == AttachmentType.audio);
      final audioChanged = hasAudio &&
          _editAttachments.any(
            (a) =>
                a.type == AttachmentType.audio &&
                !task.attachments.any((o) => o.localPath == a.localPath),
          );

      var transcriptionStatus = task.transcriptionStatus;
      if (!hasAudio) {
        transcriptionStatus = TranscriptionStatus.none;
      } else if (audioChanged) {
        transcriptionStatus = TranscriptionStatus.pending;
      }

      final editDue =
          _editRecurrence == TaskRecurrence.daily ? null : _editDueDate;
      final normalizedDue = normalizeRecurringDueDate(
        recurrence: _editRecurrence,
        dueDate: editDue,
      );

      final updated = await repo.update(
        task.copyWith(
          title: _editController.text.trim(),
          attachments: List.from(_editAttachments),
          transcriptionStatus: transcriptionStatus,
          recurrence: _editRecurrence,
          dailyUntil:
              _editRecurrence != TaskRecurrence.none ? _editDailyUntil : null,
          dueDate: normalizedDue,
          clearDailyUntil:
              _editRecurrence == TaskRecurrence.none || _editDailyUntil == null,
          clearDueDate:
              _editRecurrence == TaskRecurrence.daily || editDue == null,
          checkInTarget: _editCheckInTarget.clamp(1, 99),
          isStarred: _editIsStarred,
        ),
      );

      if (hasAudio && transcriptionStatus == TranscriptionStatus.pending) {
        unawaited(ref.read(transcriptionServiceProvider).processTask(updated));
      }
      unawaited(triggerSyncIfSignedIn(ref));

      var createdSubs = const <Task>[];
      if (!task.isSubtask && pendingSubtaskTitles.isNotEmpty) {
        try {
          createdSubs =
              await _createEditSubtasks(task.id, pendingSubtaskTitles);
        } catch (e) {
          if (mounted) {
            showAppSnackBar(
              context,
              message: '无法添加子任务',
              icon: Icons.error_outline,
              type: AppSnackType.error,
            );
          }
        }
      }

      _exitEditMode(updated);

      final targetId = createdSubs.isNotEmpty
          ? createdSubs.last.id
          : updated.id;
      final tasks = await _waitForProcessTask(targetId);
      if (!mounted) return;
      final idx = tasks.indexWhere((t) => t.id == targetId);
      if (idx >= 0) setState(() => _index = idx);
    } finally {
      _savingEdit = false;
    }
  }

  void _removeEditAttachment(int index) {
    setState(() => _editAttachments.removeAt(index));
  }

  Future<void> _pickEditImage() async {
    unawaited(AppHaptics.light());
    _beginTransientEditUi();
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final localPath = await persistImageAttachment(file);
      if (localPath == null) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: '无法读取所选图片',
          icon: Icons.error_outline,
          type: AppSnackType.error,
        );
        return;
      }

      setState(() {
        _editAttachments.add(
          TaskAttachment(type: AttachmentType.image, localPath: localPath),
        );
      });
    } finally {
      if (mounted) _endTransientEditUi();
    }
  }

  Future<void> _toggleEditRecording() async {
    unawaited(AppHaptics.light());
    if (_editRecording) {
      final result = await _editAudioRecorder.stop();
      if (!mounted) return;
      setState(() => _editRecording = false);
      _syncVolumeKeyHandler();

      if (result == null) {
        showAppSnackBar(
          context,
          message: '录音失败，请检查麦克风权限',
          icon: Icons.mic_off_outlined,
          type: AppSnackType.error,
        );
        return;
      }

      setState(() {
        _editAttachments.add(
          TaskAttachment(
            type: AttachmentType.audio,
            localPath: result.path,
            duration: result.durationSeconds,
          ),
        );
      });
      return;
    }

    final permitted = await _editAudioRecorder.hasPermission();
    if (!permitted) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '需要麦克风权限才能录音',
        icon: Icons.mic_off_outlined,
        type: AppSnackType.error,
      );
      return;
    }

    _beginTransientEditUi();
    _editFocusNode.unfocus();
    try {
      await _editAudioRecorder.start();
      if (!mounted) return;
      setState(() => _editRecording = true);
      _syncVolumeKeyHandler();
    } catch (e) {
      debugPrint('Recording start failed: $e');
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '无法开始录音',
        icon: Icons.mic_off_outlined,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) _endTransientEditUi();
    }
  }

  Future<void> _archive(Task task, {bool animated = false}) async {
    if (animated) {
      await _animateFlyout(
        const Offset(-1.5, 0),
        () => _performArchive(task),
        feedback: AppHaptics.none,
      );
    } else {
      await _performArchive(task);
    }
  }

  Future<void> _resetCheckInProgress(Task task) async {
    if (!hasResettableCheckInProgress(task)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重置打卡进度'),
          content: Text(
            '确定将「${task.displayTitle}」的打卡进度重置为 0/${task.checkInTarget}？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重置'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await AppHaptics.light();
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.resetCheckInProgress(task.id);
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '打卡进度已重置',
      icon: Icons.restart_alt,
      type: AppSnackType.success,
    );
  }

  Future<void> _performArchive(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    final result = await repo.checkIn(task.id);
    final updated = result.task;
    final recurring = isRecurring(task);
    final partial = result.result == CheckInResult.partial;

    _lastUndoTask = task;
    _lastUndoWasPartialCheckIn = partial;
    if (partial) {
      _lastUndoFrom = TaskStatus.inbox;
      _lastUndoWasPeriodCompletion = false;
    } else if (recurring) {
      _lastUndoFrom = TaskStatus.inbox;
      _lastUndoWasPeriodCompletion = true;
    } else {
      _lastUndoFrom = TaskStatus.archived;
      _lastUndoWasPeriodCompletion = false;
    }

    final message = partial
        ? checkInSnackbar(task, updated.checkInCount)
        : completeSnackbarFor(task);
    _showUndoSnackbar(
      message: message,
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
    if (mounted && !partial) {
      final remaining = (ref.read(processTasksProvider).value?.length ?? 1) - 1;
      if (remaining <= 0) showCelebrateOverlay(context);
    }

    unawaited(triggerSyncIfSignedIn(ref));
    if (!partial) {
      unawaited(ref.read(statsProvider.notifier).recordArchive());
    }
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

  Future<void> _trash(Task task) async {
    if (_deckTransitionActive || _editUiVisible) return;

    final tasks = ref.read(processTasksProvider).value;
    if (tasks == null || tasks.isEmpty) return;

    final index = _index.clamp(0, tasks.length - 1);
    final nextTask = index + 1 < tasks.length ? tasks[index + 1] : null;

    _deckPreviewTopController?.dispose();
    _deckPreviewBottomController?.dispose();
    _deckPreviewTopController = TextEditingController(text: task.displayTitle);
    if (nextTask != null) {
      _deckPreviewBottomController =
          TextEditingController(text: nextTask.displayTitle);
    } else {
      _deckPreviewBottomController = null;
    }

    _deckTransitionCompleter = Completer<void>();

    unawaited(_playTrashFeedback());

    setState(() {
      _deckTransitionActive = true;
      _deckMode = CardDeckTransitionMode.delete;
      _deckTopTask = task;
      _deckBottomTask = nextTask;
    });

    await _deckTransitionCompleter!.future;
    if (!mounted) return;

    await _performTrash(task);
    if (!mounted) return;

    _clearDeckTransitionState();
    await _swipeKey.currentState?.resetPosition(animated: false);
  }

  Future<void> _performTrash(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.trash(task.id);

    _lastUndoTask = task;
    _lastUndoFrom = TaskStatus.trashed;
    _lastUndoWasPeriodCompletion = false;
    _lastUndoWasPartialCheckIn = false;
    _showUndoSnackbar(
      message: '已移至回收站',
      icon: Icons.delete_outline,
      type: AppSnackType.error,
    );

    unawaited(triggerSyncIfSignedIn(ref));
  }

  Future<void> _moveToSomeday(Task task, {bool animated = false}) async {
    if (animated) {
      await _animateFlyout(
        const Offset(1.5, 0),
        () => _performMoveToSomeday(task),
        feedback: AppHaptics.none,
      );
    } else {
      await _performMoveToSomeday(task);
    }
  }

  Future<void> _performMoveToSomeday(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.moveToSomeday(task.id);

    _lastUndoTask = task;
    _lastUndoFrom = TaskStatus.someday;
    _lastUndoWasPeriodCompletion = false;
    _lastUndoWasPartialCheckIn = false;
    _showUndoSnackbar(
      message: '已移至将来也许',
      icon: Icons.lightbulb_outline,
      type: AppSnackType.info,
    );

    unawaited(triggerSyncIfSignedIn(ref));
    unawaited(_playSomedayFeedback());
  }

  Future<void> _restoreToInbox(Task task, {bool animated = false}) async {
    if (animated) {
      await _animateFlyout(
        const Offset(1.5, 0),
        () => _performRestoreToInbox(task),
        feedback: AppHaptics.none,
      );
    } else {
      await _performRestoreToInbox(task);
    }
  }

  Future<void> _performRestoreToInbox(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.restoreToInbox(task.id);

    _lastUndoTask = task;
    _lastUndoFrom = TaskStatus.inbox;
    _lastUndoWasPeriodCompletion = false;
    _lastUndoWasPartialCheckIn = false;
    _lastUndoWasRestoreToInbox = true;
    _showUndoSnackbar(
      message: '已移回收集箱',
      icon: Icons.inbox_outlined,
      type: AppSnackType.success,
    );

    unawaited(triggerSyncIfSignedIn(ref));
    unawaited(_playRestoreFeedback());
  }

  Future<void> _playSomedayFeedback() async {
    final settings = await ref.read(processSoundProvider.future);
    await Future.wait([
      AppHaptics.medium(),
      AppSounds.play(settings.someday),
    ]);
  }

  Future<void> _playRestoreFeedback() async {
    final preference = await ref.read(restoreSoundProvider.future);
    await Future.wait([
      AppHaptics.medium(),
      AppSounds.play(preference),
    ]);
  }

  Future<void> _playTrashFeedback() async {
    final settings = await ref.read(processSoundProvider.future);
    await Future.wait([
      AppHaptics.medium(),
      AppSounds.play(settings.trash),
    ]);
  }

  Future<void> _openTaskSearch({Task? currentTask}) async {
    final searchable = ref.read(searchableProcessTasksProvider).value ?? [];
    if (searchable.isEmpty) return;

    final allTasks = <Task>[
      ...ref.read(inboxTasksProvider).value ?? [],
      ...ref.read(somedayTasksProvider).value ?? [],
    ];

    final selected = await showProcessTaskSearchSheet(
      context,
      tasks: searchable,
      allTasks: allTasks,
      currentTaskId: currentTask?.id,
    );
    if (selected == null || !mounted) return;
    await _jumpToTask(selected);
  }

  Future<void> _jumpToTask(Task target) async {
    var processTasks = ref.read(processTasksProvider).value ?? [];
    var index = processTasks.indexWhere((t) => t.id == target.id);
    if (index >= 0) {
      await _setIndex(index, processTasks.length, animated: true);
      return;
    }

    final currentSource =
        ref.read(processQueueSourceProvider).value ?? const ProcessQueueSource.inbox();
    final playlists = ref.read(playlistsProvider).value ?? [];
    final neededSource = resolveQueueSourceForTask(
      target,
      currentSource: currentSource,
      playlists: playlists,
    );

    if (currentSource != neededSource) {
      await ref.read(processQueueSourceProvider.notifier).setSource(neededSource);
      processTasks = await _waitForProcessTask(target.id);
      if (!mounted) return;
      index = processTasks.indexWhere((t) => t.id == target.id);
      if (index >= 0) {
        await _setIndex(index, processTasks.length, animated: true);
        return;
      }
    }

    final queueSource = ref.read(processQueueSourceProvider).value ??
        const ProcessQueueSource.inbox();
    if (queueSource.kind == ProcessQueueKind.daily) {
      final inbox = ref.read(inboxTasksProvider).value ?? [];
      final inInbox = inbox.any((t) => t.id == target.id);
      if (inInbox) {
        await ref
            .read(processQueueSourceProvider.notifier)
            .setSource(const ProcessQueueSource.inbox());
        processTasks = await _waitForProcessTask(target.id);
        if (!mounted) return;
        index = processTasks.indexWhere((t) => t.id == target.id);
        if (index >= 0) {
          await _setIndex(index, processTasks.length, animated: true);
          return;
        }
      }
    }

    if (!mounted) return;
    context.push('/task/${target.id}');
  }

  Future<void> _handleNavigationIntent(ProcessNavigationIntent intent) async {
    await ref
        .read(processQueueSourceProvider.notifier)
        .setSource(intent.queueSource);
    final tasks = await _waitForProcessTask(intent.taskId);
    if (!mounted) return;
    final index = tasks.indexWhere((t) => t.id == intent.taskId);
    if (index >= 0) {
      await _setIndex(index, tasks.length, animated: true);
    }
    ref.read(processNavigationIntentProvider.notifier).state = null;
  }

  String _emptyQueueMessage(ProcessQueueSource source) {
    return switch (source.kind) {
      ProcessQueueKind.inbox => '收集箱是空的，去收集页记一条吧',
      ProcessQueueKind.daily => '今天没有计划任务',
      ProcessQueueKind.someday => '将来也许列表是空的',
      ProcessQueueKind.playlist => '该清单暂无可用任务',
    };
  }

  Widget _buildTopBar(
    BuildContext context, {
    required int taskCount,
    required int archivedToday,
    required bool canSearch,
    VoidCallback? onSearch,
    VoidCallback? onShuffle,
    VoidCallback? onSaveTemplate,
    VoidCallback? onDeleteCurrentTask,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: [
          ProcessProgressRing(
            completed: archivedToday,
            total: archivedToday + taskCount,
          ),
          const SizedBox(width: 12),
          Text(
            '$taskCount 待处理',
            style: theme.textTheme.bodyMedium,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: '搜索任务',
                      onPressed: canSearch ? onSearch : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.shuffle),
                      tooltip: '随机打散',
                      onPressed: taskCount > 1 &&
                              onShuffle != null &&
                              !_editUiVisible &&
                              !_shuffling
                          ? onShuffle
                          : null,
                    ),
                    const ProcessQueueSelector(),
                    TabMoreMenuButton<ProcessMoreAction>(
                      items: [
                        TabMoreMenuEntry.item(
                          value: ProcessMoreAction.someday,
                          icon: Icons.lightbulb_outline,
                          label: '将来也许',
                        ),
                        TabMoreMenuEntry.item(
                          value: ProcessMoreAction.archive,
                          icon: Icons.task_alt_outlined,
                          label: '已完成',
                        ),
                        TabMoreMenuEntry.item(
                          value: ProcessMoreAction.trash,
                          icon: Icons.delete_outline,
                          label: '回收站',
                        ),
                        if (onSaveTemplate != null ||
                            onDeleteCurrentTask != null) ...[
                          const TabMoreMenuEntry.divider(),
                          if (onSaveTemplate != null)
                            TabMoreMenuEntry.item(
                              value: ProcessMoreAction.saveTemplate,
                              icon: Icons.bookmark_outline,
                              label: '保存为模板',
                            ),
                          if (onDeleteCurrentTask != null)
                            TabMoreMenuEntry.item(
                              value: ProcessMoreAction.delete,
                              icon: Icons.delete_outline,
                              label: '删除当前任务',
                            ),
                        ],
                      ],
                      onSelected: (action) {
                        switch (action) {
                          case ProcessMoreAction.someday:
                            context.push('/someday');
                          case ProcessMoreAction.archive:
                            context.push('/archive');
                          case ProcessMoreAction.trash:
                            context.push('/trash');
                          case ProcessMoreAction.saveTemplate:
                            onSaveTemplate?.call();
                          case ProcessMoreAction.delete:
                            onDeleteCurrentTask?.call();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentAsTemplate(Task task) async {
    final name = await showSaveTemplateDialog(
      context,
      defaultTitle: task.title,
    );
    if (name == null || !mounted) return;

    final result = await confirmAndSaveTemplate(
      context: context,
      ref: ref,
      name: name,
      save: ({replaceTemplateId}) async {
        final templateRepo = await ref.read(templateRepositoryProvider.future);
        await templateRepo.saveFromTask(
          task.id,
          titleOverride: name,
          replaceTemplateId: replaceTemplateId,
        );
      },
    );
    if (!result.saved || !mounted) return;
    showAppSnackBar(
      context,
      message: result.replaced ? '已替换模板' : '已保存为模板',
      icon: Icons.bookmark_outline,
      type: AppSnackType.success,
    );
  }
}
