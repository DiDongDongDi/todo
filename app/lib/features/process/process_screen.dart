import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/settings/process_sound_settings.dart';
import 'package:todo_app/core/settings/process_today_only_settings.dart';
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
import 'package:todo_app/shared/widgets/progress_widgets.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';
import 'package:todo_app/shared/widgets/task_schedule_editor.dart';

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
  bool _lastUndoWasDailyCompletion = false;

  bool _editIsDaily = false;
  DateTime? _editDailyUntil;
  DateTime? _editDueDate;
  final List<TaskAttachment> _editAttachments = [];
  bool _editRecording = false;
  final _editAudioRecorder = AppAudioRecorder();

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    unawaited(_editAudioRecorder.dispose());
    super.dispose();
  }

  Future<void> _undo() async {
    final task = _lastUndoTask;
    final from = _lastUndoFrom;
    if (task == null || from == null) return;

    final enterFromLeft = from == TaskStatus.trashed;
    final enterFromRight =
        from == TaskStatus.archived || _lastUndoWasDailyCompletion;
    if (!enterFromLeft && !enterFromRight) return;

    final repo = await ref.read(taskRepositoryProvider.future);
    if (_lastUndoWasDailyCompletion) {
      await repo.undoDailyCompletion(task.id);
    } else {
      await repo.restoreToInbox(task.id);
    }
    final tasks = ref.read(processTasksProvider).value ?? [];

    _lastUndoTask = null;
    _lastUndoFrom = null;
    _lastUndoWasDailyCompletion = false;

    if (!mounted) return;

    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index < 0) return;

    _editFocusNode.unfocus();
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    todayOnly
                        ? '今天没有计划任务'
                        : '收集箱是空的，去收集页记一条吧',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  FilterChip(
                    label: const Text('只看今日'),
                    selected: todayOnly,
                    onSelected: (value) => ref
                        .read(processTodayOnlyProvider.notifier)
                        .setEnabled(value),
                  ),
                ],
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
        if (!_editing) {
          _syncDisplayFromTask(task);
        }
        final archivedToday = statsAsync.value?.archivedToday ?? 0;
        final progress = inboxProgress(archivedToday, tasks.length);

        final shortcuts = _editing
            ? {
                const SingleActivator(LogicalKeyboardKey.enter): () =>
                    _saveEdit(task),
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    _exitEditMode(task),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('只看今日'),
                      selected: todayOnly,
                      onSelected: (value) => ref
                          .read(processTodayOnlyProvider.notifier)
                          .setEnabled(value),
                    ),
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
                child: BigTaskCard(
                  mode: BigTaskCardMode.process,
                  editing: _editing,
                  task: task,
                  controller: _editController,
                  focusNode: _editFocusNode,
                  onEnterEdit: () => _startEdit(task),
                  attachments:
                      _editing ? _editAttachments : task.attachments,
                  onRemoveAttachment:
                      _editing ? _removeEditAttachment : null,
                  onPickImage: _editing ? _pickEditImage : null,
                  onStartSpeech:
                      _editing && !kIsWeb ? _toggleEditRecording : null,
                  isListening: _editRecording,
                  onSave: _editing ? () => _saveEdit(task) : null,
                  onCancelEdit: _editing ? () => _exitEditMode(task) : null,
                  scheduleEditor: _editing
                      ? TaskScheduleEditor(
                          isDaily: _editIsDaily,
                          dailyUntil: _editDailyUntil,
                          dueDate: _editDueDate,
                          onDailyChanged: (value) =>
                              setState(() => _editIsDaily = value),
                          onDailyUntilChanged: (value) =>
                              setState(() => _editDailyUntil = value),
                          onDueDateChanged: (value) =>
                              setState(() => _editDueDate = value),
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
                  canGoPrevious: clampedIndex > 0,
                  canGoNext: clampedIndex < tasks.length - 1,
                  onRetryTranscription: task.canRetryTranscription
                      ? () => _retryTranscription(task)
                      : null,
                  scheduleLabel: scheduleLabel(task),
                  completeLabel: task.isDaily ? '今日完成' : '完成',
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
      _editFocusNode.unfocus();
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

  void _syncDisplayFromTask(Task task) {
    if (_editing) return;
    final display = task.displayTitle;
    if (_editController.text != display) {
      _editController.text = display;
    }
  }

  void _startEdit(Task task) {
    if (_editing) return;
    _editController.text = task.title;
    _editIsDaily = task.isDaily;
    _editDailyUntil = task.dailyUntil;
    _editDueDate = task.dueDate;
    _editAttachments
      ..clear()
      ..addAll(task.attachments);
    _editRecording = false;
    setState(() => _editing = true);
    _editFocusNode.requestFocus();
  }

  void _exitEditMode([Task? task]) {
    if (!_editing) return;
    _editFocusNode.unfocus();
    setState(() => _editing = false);
    if (task != null) {
      _syncDisplayFromTask(task);
    }
  }

  Future<void> _saveEdit(Task task) async {
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

    final updated = await repo.update(
      task.copyWith(
        title: _editController.text.trim(),
        attachments: List.from(_editAttachments),
        transcriptionStatus: transcriptionStatus,
        isDaily: _editIsDaily,
        dailyUntil: _editDailyUntil,
        dueDate: _editIsDaily ? null : _editDueDate,
        clearDailyUntil: _editIsDaily && _editDailyUntil == null,
        clearDueDate: _editIsDaily || _editDueDate == null,
      ),
    );

    if (hasAudio && transcriptionStatus == TranscriptionStatus.pending) {
      unawaited(ref.read(transcriptionServiceProvider).processTask(updated));
    }
    unawaited(triggerSyncIfSignedIn(ref));

    _exitEditMode(task);
  }

  void _removeEditAttachment(int index) {
    setState(() => _editAttachments.removeAt(index));
  }

  Future<void> _pickEditImage() async {
    final picker = ImagePicker();
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
  }

  Future<void> _toggleEditRecording() async {
    if (_editRecording) {
      final result = await _editAudioRecorder.stop();
      if (!mounted) return;
      setState(() => _editRecording = false);

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
      await AppHaptics.light();
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

    _editFocusNode.unfocus();
    try {
      await _editAudioRecorder.start();
      if (!mounted) return;
      setState(() => _editRecording = true);
      await AppHaptics.light();
    } catch (e) {
      debugPrint('Recording start failed: $e');
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '无法开始录音',
        icon: Icons.mic_off_outlined,
        type: AppSnackType.error,
      );
    }
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
    final isDaily = task.isDaily;

    if (isDaily) {
      await repo.completeDailyToday(task.id);
    } else {
      await repo.archive(task.id);
    }

    _lastUndoTask = task;
    _lastUndoFrom = isDaily ? TaskStatus.inbox : TaskStatus.archived;
    _lastUndoWasDailyCompletion = isDaily;
    _showUndoSnackbar(
      message: isDaily ? '今日已完成' : '已完成',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
    if (mounted) {
      final remaining = (ref.read(processTasksProvider).value?.length ?? 1) - 1;
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
