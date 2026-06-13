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
import 'package:todo_app/core/models/task_hierarchy.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/settings/process_sound_settings.dart';
import 'package:todo_app/core/settings/process_today_only_settings.dart';
import 'package:todo_app/core/settings/volume_key_handler.dart';
import 'package:todo_app/core/settings/volume_key_platform.dart';
import 'package:todo_app/core/settings/volume_key_settings.dart';
import 'package:todo_app/core/stats/stats_provider.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/core/transcription/transcription_service.dart';
import 'package:todo_app/shared/utils/app_audio_recorder.dart';
import 'package:todo_app/shared/utils/attachment_storage.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/utils/sounds.dart';
import 'package:todo_app/shared/utils/platform_capabilities.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';
import 'package:todo_app/shared/widgets/card_stage.dart';
import 'package:todo_app/shared/widgets/process_task_search_sheet.dart';
import 'package:todo_app/shared/widgets/progress_widgets.dart';
import 'package:todo_app/shared/widgets/save_template_dialog.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';
import 'package:todo_app/shared/widgets/tab_more_menu_button.dart';
import 'package:todo_app/shared/widgets/task_check_in_editor.dart';
import 'package:todo_app/shared/widgets/task_schedule_editor.dart';

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

  TaskRecurrence _editRecurrence = TaskRecurrence.none;
  DateTime? _editDailyUntil;
  DateTime? _editDueDate;
  int _editCheckInTarget = 1;
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
    unawaited(_editAudioRecorder.dispose());
    super.dispose();
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
    setState(() => _editSubtaskControllers.add(TextEditingController()));
  }

  Future<int> _submitEditSubtaskRow(int index) async {
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
    if (focused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

    final enterFromLeft = from == TaskStatus.trashed;
    final enterFromRight =
        from == TaskStatus.archived || wasPeriod || wasPartialCheckIn;
    if (!enterFromLeft && !enterFromRight) return;

    Future<void> restoreAndSwitch() async {
      final repo = await ref.read(taskRepositoryProvider.future);
      if (wasPartialCheckIn) {
        await repo.undoCheckIn(task.id, wasFinalCompletion: false);
      } else if (wasPeriod) {
        if (hasCheckInGoal(task)) {
          await repo.undoCheckIn(task.id, wasFinalCompletion: true);
        } else {
          await repo.undoDailyCompletion(task.id);
        }
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

      _editFocusNode.unfocus();
      setState(() {
        _index = index;
        _editing = false;
      });
      AppHaptics.light();
    }

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

  @override
  Widget build(BuildContext context) {
    ref.listen(volumeKeyShortcutsProvider, (_, __) => _syncVolumeKeyHandler());

    final tasksAsync = ref.watch(processTasksProvider);
    final todayOnlyAsync = ref.watch(processTodayOnlyProvider);
    final statsAsync = ref.watch(statsProvider);
    final touchFirst = isTouchFirstPlatform;
    final todayOnly = todayOnlyAsync.value ?? false;

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(
                context,
                taskCount: 0,
                archivedToday: statsAsync.value?.archivedToday ?? 0,
                todayOnly: todayOnly,
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      todayOnly
                          ? '今天没有计划任务'
                          : '收集箱是空的，去收集页记一条吧',
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
            _buildTopBar(
              context,
              taskCount: tasks.length,
              archivedToday: archivedToday,
              todayOnly: todayOnly,
              onSearch: () => _openTaskSearch(tasks, task),
              onSaveTemplate: () => _saveCurrentAsTemplate(task),
            ),
            Expanded(
              child: CardStage(
                swipeKey: _swipeKey,
                enabled: touchFirst && !_editUiVisible,
                verticalEnterAnimation: true,
                onFlyoutFeedback: AppHaptics.none,
                shouldAnimateFlyout: (flyout) async {
                  if (flyout.dy != 0) return tasks.length > 1;
                  return true;
                },
                onSwipeLeft: () => _trash(task),
                onSwipeRight: () => _archive(task),
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
                  canGoPrevious: tasks.length > 1,
                  canGoNext: tasks.length > 1,
                  onRetryTranscription: task.canRetryTranscription
                      ? () => _retryTranscription(task)
                      : null,
                  scheduleLabel: scheduleLabel(task),
                  scheduleOverdue: isOverdue(task),
                  checkInLabel: checkInLabel(task),
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
        const Offset(1.5, 0),
        () => _performArchive(task),
        feedback: AppHaptics.none,
      );
    } else {
      await _performArchive(task);
    }
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

  Future<void> _trash(Task task, {bool animated = false}) async {
    if (animated) {
      await _animateFlyout(
        const Offset(-1.5, 0),
        () => _performTrash(task),
        feedback: AppHaptics.none,
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

  Future<void> _openTaskSearch(List<Task> processTasks, Task currentTask) async {
    final inbox = ref.read(inboxTasksProvider).value ?? [];
    final searchable = inbox.where((t) => shouldIncludeInSearch(t)).toList();
    if (searchable.isEmpty) return;

    final selected = await showProcessTaskSearchSheet(
      context,
      tasks: searchable,
      currentTaskId: currentTask.id,
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

    final todayOnly = ref.read(processTodayOnlyProvider).value ?? false;
    if (todayOnly) {
      final inbox = ref.read(inboxTasksProvider).value ?? [];
      final unfiltered = filterProcessTasks(inbox, todayOnly: false);
      if (unfiltered.any((t) => t.id == target.id)) {
        await ref.read(processTodayOnlyProvider.notifier).setEnabled(false);
        processTasks = await _waitForProcessTask(target.id);
        if (!mounted) return;
        index = processTasks.indexWhere((t) => t.id == target.id);
        if (index >= 0) {
          await _setIndex(index, processTasks.length, animated: true);
          return;
        }
      }
    }

    if (target.parentId == null) {
      final inbox = ref.read(inboxTasksProvider).value ?? [];
      final todayOnly = ref.read(processTodayOnlyProvider).value ?? false;
      if (hasOpenSubtasks(target, inbox, todayOnly: todayOnly)) {
        if (!mounted) return;
        context.push('/task/${target.id}');
        return;
      }
    }

    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '该任务当前不在处理队列中',
      icon: Icons.info_outline,
      type: AppSnackType.info,
    );
  }

  Widget _buildTopBar(
    BuildContext context, {
    required int taskCount,
    required int archivedToday,
    required bool todayOnly,
    VoidCallback? onSearch,
    VoidCallback? onSaveTemplate,
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
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索任务',
            onPressed: taskCount > 0 ? onSearch : null,
          ),
          IconButton(
            icon: Icon(
              todayOnly ? Icons.today : Icons.today_outlined,
              color: todayOnly ? theme.colorScheme.primary : null,
            ),
            tooltip: '只看今日',
            onPressed: () => ref
                .read(processTodayOnlyProvider.notifier)
                .setEnabled(!todayOnly),
          ),
          TabMoreMenuButton<ProcessMoreAction>(
            items: [
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
              TabMoreMenuEntry.item(
                value: ProcessMoreAction.sync,
                icon: Icons.sync_outlined,
                label: '同步配置',
              ),
              if (onSaveTemplate != null) ...[
                const TabMoreMenuEntry.divider(),
                TabMoreMenuEntry.item(
                  value: ProcessMoreAction.saveTemplate,
                  icon: Icons.bookmark_outline,
                  label: '保存为模板',
                ),
              ],
            ],
            onSelected: (action) {
              switch (action) {
                case ProcessMoreAction.archive:
                  context.push('/archive');
                case ProcessMoreAction.trash:
                  context.push('/trash');
                case ProcessMoreAction.sync:
                  context.push('/auth');
                case ProcessMoreAction.saveTemplate:
                  onSaveTemplate?.call();
              }
            },
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

    final templateRepo = await ref.read(templateRepositoryProvider.future);
    await templateRepo.saveFromTask(task.id, titleOverride: name);
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已保存为模板',
      icon: Icons.bookmark_outline,
      type: AppSnackType.success,
    );
  }
}
