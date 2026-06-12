import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/settings/collect_sound_settings.dart';
import 'package:todo_app/core/settings/volume_key_handler.dart';
import 'package:todo_app/core/settings/volume_key_platform.dart';
import 'package:todo_app/core/settings/volume_key_settings.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/core/transcription/transcription_service.dart';
import 'package:todo_app/shared/utils/app_audio_recorder.dart';
import 'package:todo_app/shared/utils/attachment_storage.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/utils/sounds.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/batch_import_dialog.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';
import 'package:todo_app/shared/widgets/card_stage.dart';
import 'package:todo_app/shared/widgets/save_template_dialog.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';
import 'package:todo_app/shared/widgets/tab_more_menu_button.dart';
import 'package:todo_app/shared/widgets/tab_page_header.dart';
import 'package:todo_app/shared/widgets/task_check_in_editor.dart';
import 'package:todo_app/shared/widgets/task_schedule_editor.dart';
import 'package:todo_app/shared/widgets/template_picker_sheet.dart';

class CollectScreen extends ConsumerStatefulWidget {
  const CollectScreen({super.key, this.isActive = true});

  /// 当前是否为 Shell 中选中的 tab。
  final bool isActive;

  @override
  ConsumerState<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends ConsumerState<CollectScreen> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  final _swipeKey = GlobalKey<SwipeableCardState>();
  final _audioRecorder = AppAudioRecorder();

  bool _recording = false;
  final List<TaskAttachment> _attachments = [];
  CollectCardFeedback _feedback = CollectCardFeedback.none;
  Task? _lastUndoTask;
  int _feedbackEpoch = 0;
  bool _saving = false;

  TaskRecurrence _recurrence = TaskRecurrence.none;
  DateTime? _dailyUntil;
  DateTime? _dueDate;
  int _checkInTarget = 1;
  final List<TextEditingController> _subtaskControllers = [];

  /// 拖拽/保存开始前输入法是否打开。
  bool? _keyboardWasOpenBeforeGesture;

  static const _switcherDuration = Duration(milliseconds: 200);

  /// 底部「取消」按钮：仅在有焦点或保存动画期间显示。
  bool get _inputUiVisible => _focusNode.hasFocus || _saving;

  void _ensureCaretVisible() {
    final text = _controller.text;
    final offset = text.length;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }

  void _cancelInput() {
    unawaited(AppHaptics.light());
    _focusNode.unfocus();
  }

  /// 单击卡片空白区：仅在未聚焦时请求焦点；已聚焦时不做任何事，避免键盘回弹。
  void _activateInput() {
    if (_focusNode.hasFocus) return;
    _ensureCaretVisible();
    _focusNode.requestFocus();
  }

  void _onDragStart() {
    _keyboardWasOpenBeforeGesture ??= _focusNode.hasFocus;
    _focusNode.unfocus();
  }

  void _onDragEnd() {
    if (_saving) return;
    final shouldRefocus = _keyboardWasOpenBeforeGesture == true;
    _keyboardWasOpenBeforeGesture = null;
    if (shouldRefocus) {
      unawaited(_requestInputFocus());
    }
  }

  Future<void> _requestInputFocus({Duration delay = Duration.zero}) async {
    if (!mounted || _recording) return;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    _ensureCaretVisible();
    FocusScope.of(context).requestFocus(_focusNode);

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _ensureCaretVisible();
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onInputFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVolumeKeyHandler());
  }

  @override
  void didUpdateWidget(CollectScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncVolumeKeyHandler();
      });
    }
  }

  void _syncVolumeKeyHandler() {
    final enabled = ref.read(volumeKeyShortcutsProvider).value ?? false;
    if (widget.isActive && enabled) {
      ref.read(volumeKeyHandlerProvider.notifier).registerCollect(_handleVolumeKey);
    } else {
      ref.read(volumeKeyHandlerProvider.notifier).registerCollect(null);
    }
  }

  void _handleVolumeKey(VolumeKeyDirection direction) {
    if (direction == VolumeKeyDirection.down) {
      unawaited(_save(animated: true));
    }
  }

  void _onInputFocusChange() {
    if (!mounted) return;
    if (_focusNode.hasFocus) {
      _ensureCaretVisible();
      setState(() {});
      return;
    }
    if (_saving) {
      setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusNode.hasFocus || _saving) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    ref.read(volumeKeyHandlerProvider.notifier).registerCollect(null);
    _focusNode.removeListener(_onInputFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  void _addSubtaskField() {
    setState(() => _subtaskControllers.add(TextEditingController()));
  }

  void _removeSubtaskField(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
    });
  }

  void _clearSubtaskFields() {
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    _subtaskControllers.clear();
  }

  List<String> get _subtaskTitles =>
      SubtaskTitleEditor.nonEmptyTitles(_subtaskControllers);

  bool get _hasContent =>
      _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;

  void _dismissCardFeedback() {
    if (_feedback == CollectCardFeedback.none) return;
    _feedbackEpoch++;
    setState(() => _feedback = CollectCardFeedback.none);
  }

  Future<void> _showCardFeedback(
    CollectCardFeedback feedback,
    Duration duration, {
    bool refocus = false,
  }) async {
    final epoch = ++_feedbackEpoch;
    setState(() => _feedback = feedback);
    await Future<void>.delayed(duration);
    if (!mounted || epoch != _feedbackEpoch) return;
    setState(() => _feedback = CollectCardFeedback.none);
    if (refocus) {
      await _requestInputFocus(delay: _switcherDuration);
    }
  }

  Future<void> _undoCreate() async {
    final task = _lastUndoTask;
    if (task == null) return;

    Future<void> restoreContent() async {
      final repo = await ref.read(taskRepositoryProvider.future);
      await repo.trash(task.id);
      unawaited(triggerSyncIfSignedIn(ref));

      _lastUndoTask = null;
      _feedbackEpoch++;

      if (!mounted) return;

      setState(() {
        _feedback = CollectCardFeedback.none;
        _controller.text = task.title;
        _attachments
          ..clear()
          ..addAll(task.attachments);
        _recurrence = task.recurrence;
        _dailyUntil = task.dailyUntil;
        _dueDate = task.dueDate;
        _checkInTarget = task.checkInTarget;
      });
      _ensureCaretVisible();
    }

    final state = _swipeKey.currentState;
    if (state != null) {
      await state.animateFlyout(
        const Offset(0, 1.2),
        restoreContent,
        resetAfter: false,
        feedback: () async => AppHaptics.light(),
      );
      if (!mounted) return;
      await _swipeKey.currentState?.resetPosition(enterFromTop: true);
    } else {
      await restoreContent();
    }

    if (!mounted) return;
    await _requestInputFocus();
  }

  void _showSaveSnackbar() {
    showAppSnackBar(
      context,
      message: '已收集',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
      action: SnackBarAction(
        label: '撤销',
        onPressed: _undoCreate,
      ),
    );
  }

  Future<void> _collectFlyoutFeedback() async {
    final preference = await ref.read(collectSoundProvider.future);
    await Future.wait([
      AppHaptics.medium(),
      AppSounds.playCollectSuccess(preference),
    ]);
  }

  Future<void> _onSwipeUp() async {
    if (!_hasContent) {
      final keepKeyboard = _keyboardWasOpenBeforeGesture ?? _focusNode.hasFocus;
      await AppHaptics.light();
      if (mounted) {
        await _showCardFeedback(
          CollectCardFeedback.emptyHint,
          const Duration(seconds: 1),
        );
      }
      if (keepKeyboard && mounted) {
        await _requestInputFocus();
      }
      return;
    }
    await _performSave();
  }

  Future<void> _performSave() async {
    if (_saving) return;
    _saving = true;
    _keyboardWasOpenBeforeGesture = null;

    try {
      final repo = await ref.read(taskRepositoryProvider.future);

      final hasAudio = _attachments.any((a) => a.type == AttachmentType.audio);
      final result = await repo.createInboxWithSubtasks(
        title: _controller.text.trim(),
        attachments: List.from(_attachments),
        transcriptionStatus:
            hasAudio ? TranscriptionStatus.pending : TranscriptionStatus.none,
        recurrence: _recurrence,
        dailyUntil: _recurrence != TaskRecurrence.none ? _dailyUntil : null,
        dueDate: _recurrence == TaskRecurrence.daily ? null : _dueDate,
        subtaskTitles: _subtaskTitles,
        checkInTarget: _checkInTarget,
      );
      final task = result.parent;

      unawaited(triggerSyncIfSignedIn(ref));

      if (hasAudio) {
        unawaited(ref.read(transcriptionServiceProvider).processTask(task));
      }

      if (!mounted) return;

      setState(() {
        _controller.clear();
        _attachments.clear();
        _recurrence = TaskRecurrence.none;
        _dailyUntil = null;
        _dueDate = null;
        _checkInTarget = 1;
        _clearSubtaskFields();
        _lastUndoTask = task;
      });
      _ensureCaretVisible();

      await _swipeKey.currentState?.resetPosition(enterFromBottom: true);
      if (!mounted) return;

      _showSaveSnackbar();
    } finally {
      _focusNode.unfocus();
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _save({bool animated = false}) async {
    if (_saving) return;

    if (!_hasContent) {
      final keepKeyboard = _focusNode.hasFocus;
      await AppHaptics.light();
      if (mounted) {
        await _showCardFeedback(
          CollectCardFeedback.emptyHint,
          const Duration(seconds: 1),
        );
      }
      if (keepKeyboard && mounted) {
        await _requestInputFocus();
      }
      return;
    }

    if (animated) {
      _focusNode.unfocus();
      final state = _swipeKey.currentState;
      if (state != null) {
        await state.animateFlyout(
          const Offset(0, -1.2),
          _performSave,
          resetAfter: false,
        );
      } else {
        await _performSave();
      }
    } else {
      await _performSave();
    }
  }

  Future<void> _pickImage() async {
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
      _attachments.add(
        TaskAttachment(type: AttachmentType.image, localPath: localPath),
      );
    });
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _toggleRecording() async {
    if (kIsWeb) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Web 版暂不支持录音，请使用移动端',
        icon: Icons.mic_off_outlined,
        type: AppSnackType.info,
      );
      return;
    }

    if (_recording) {
      final result = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _recording = false);

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
        _attachments.add(
          TaskAttachment(
            type: AttachmentType.audio,
            localPath: result.path,
            duration: result.durationSeconds,
          ),
        );
      });
      return;
    }

    final permitted = await _audioRecorder.hasPermission();
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

    _focusNode.unfocus();
    try {
      await _audioRecorder.start();
      if (!mounted) return;
      setState(() => _recording = true);
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

  @override
  Widget build(BuildContext context) {
    ref.listen(volumeKeyShortcutsProvider, (_, __) => _syncVolumeKeyHandler());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabPageHeader(
          title: '收集',
          actions: [
            TabMoreMenuButton<CollectMoreAction>(
              items: [
                TabMoreMenuEntry.item(
                  value: CollectMoreAction.saveTemplate,
                  icon: Icons.bookmark_outline,
                  label: '保存为模板',
                ),
                TabMoreMenuEntry.item(
                  value: CollectMoreAction.createFromTemplate,
                  icon: Icons.note_add_outlined,
                  label: '从模板创建',
                ),
                TabMoreMenuEntry.item(
                  value: CollectMoreAction.batchImport,
                  icon: Icons.playlist_add,
                  label: '批量导入',
                ),
              ],
              onSelected: _onCollectMoreAction,
            ),
          ],
        ),
        Expanded(
          child: CardStage(
            swipeKey: _swipeKey,
            enabled: true,
            resetAfterAction: false,
            shouldAnimateFlyout: (_) async => _hasContent,
            onFlyoutFeedback: _collectFlyoutFeedback,
            onDragStart: _onDragStart,
            onDragEnd: _onDragEnd,
            onSwipeUp: _onSwipeUp,
            rightLabel: '',
            leftLabel: '',
            child: BigTaskCard(
              mode: BigTaskCardMode.collect,
              controller: _controller,
              focusNode: _focusNode,
              onActivateInput: _activateInput,
              feedback: _recording ? CollectCardFeedback.listening : _feedback,
              onDismissFeedback: _dismissCardFeedback,
              onChanged: null,
              attachments: _attachments,
              onRemoveAttachment: _removeAttachment,
              onPickImage: _pickImage,
              onStartSpeech: kIsWeb ? null : _toggleRecording,
              isListening: _recording,
              onSave: () => _save(animated: true),
              onCancelEdit: _cancelInput,
              editing: _inputUiVisible,
              onAddSubtask: _addSubtaskField,
              scheduleEditor: TaskScheduleEditor(
                recurrence: _recurrence,
                dailyUntil: _dailyUntil,
                dueDate: _dueDate,
                onRecurrenceChanged: (value) =>
                    setState(() => _recurrence = value),
                onDailyUntilChanged: (value) =>
                    setState(() => _dailyUntil = value),
                onDueDateChanged: (value) =>
                    setState(() => _dueDate = value),
              ),
              checkInEditor: TaskCheckInEditor(
                checkInTarget: _checkInTarget,
                onCheckInTargetChanged: (value) =>
                    setState(() => _checkInTarget = value),
              ),
              subtaskEditor: SubtaskTitleEditor(
                controllers: _subtaskControllers,
                onRemove: _removeSubtaskField,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onCollectMoreAction(CollectMoreAction action) async {
    switch (action) {
      case CollectMoreAction.saveTemplate:
        await _saveDraftAsTemplate();
      case CollectMoreAction.createFromTemplate:
        await _createFromTemplate();
      case CollectMoreAction.batchImport:
        await _batchImport();
    }
  }

  Future<void> _saveDraftAsTemplate() async {
    if (!_hasContent) {
      showAppSnackBar(
        context,
        message: '请先输入内容',
        icon: Icons.edit_outlined,
        type: AppSnackType.warning,
      );
      return;
    }

    final name = await showSaveTemplateDialog(
      context,
      defaultTitle: _controller.text.trim(),
    );
    if (name == null || !mounted) return;

    final templateRepo = await ref.read(templateRepositoryProvider.future);
    await templateRepo.saveFromDraft(
      title: _controller.text.trim(),
      attachments: List.from(_attachments),
      recurrence: _recurrence,
      dailyUntil: _dailyUntil,
      dueDate: _dueDate,
      subtaskTitles: _subtaskTitles,
      titleOverride: name,
    );
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已保存为模板',
      icon: Icons.bookmark_outline,
      type: AppSnackType.success,
    );
  }

  Future<void> _createFromTemplate() async {
    final template = await showTemplatePickerSheet(context);
    if (template == null || !mounted) return;

    final templateRepo = await ref.read(templateRepositoryProvider.future);
    final created = await templateRepo.createTasksFromTemplate(template.id);
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已创建 ${created.length} 个任务',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
  }

  Future<void> _batchImport() async {
    final titles = await showBatchImportDialog(context);
    if (titles == null || titles.isEmpty || !mounted) return;

    final repo = await ref.read(taskRepositoryProvider.future);
    for (final title in titles) {
      await repo.createInbox(title: title);
    }
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已导入 ${titles.length} 条任务',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
  }
}
