import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/settings/collect_sound_settings.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/core/transcription/transcription_service.dart';
import 'package:todo_app/shared/utils/app_audio_recorder.dart';
import 'package:todo_app/shared/utils/attachment_storage.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/utils/sounds.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';
import 'package:todo_app/shared/widgets/card_stage.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';
import 'package:todo_app/shared/widgets/task_schedule_editor.dart';

class CollectScreen extends ConsumerStatefulWidget {
  const CollectScreen({super.key});

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

  bool _isDaily = false;
  DateTime? _dailyUntil;
  DateTime? _dueDate;

  /// 手势/保存开始前输入法是否打开；用于保存后保持相同状态。
  bool? _keyboardWasOpenBeforeGesture;

  /// 保存后递增以重建 TextField，重连 IME 且无需 unfocus。
  int _collectInputEpoch = 0;

  static const _switcherDuration = Duration(milliseconds: 200);

  void _ensureCaretVisible() {
    final text = _controller.text;
    final offset = text.length;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }

  void _activateInput() {
    _ensureCaretVisible();
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  void _rebuildInputField() {
    setState(() => _collectInputEpoch++);
  }

  void _rememberKeyboardState() {
    _keyboardWasOpenBeforeGesture ??= _focusNode.hasFocus;
  }

  Future<void> _requestInputFocus({
    Duration delay = Duration.zero,
    bool recycleFocus = false,
  }) async {
    if (!mounted || _recording) return;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    if (recycleFocus && _focusNode.hasFocus) {
      _focusNode.unfocus();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    _ensureCaretVisible();
    if (mounted) {
      FocusScope.of(context).requestFocus(_focusNode);
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _ensureCaretVisible();
  }

  /// 保存/动画结束后恢复输入状态，不主动收起再弹起键盘。
  Future<void> _restoreInputAfterSave({
    required bool keepKeyboard,
    Duration delay = Duration.zero,
  }) async {
    if (!mounted || _recording) return;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    if (!keepKeyboard) {
      _focusNode.unfocus();
      return;
    }

    // 动画结束后重建 TextField，重连 IME 且不收起键盘。
    _rebuildInputField();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    _ensureCaretVisible();
    if (!_focusNode.hasFocus && mounted) {
      FocusScope.of(context).requestFocus(_focusNode);
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _ensureCaretVisible();
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onInputFocusChange);
    unawaited(_requestInputFocus());
  }

  void _onInputFocusChange() {
    if (_focusNode.hasFocus && mounted) {
      _ensureCaretVisible();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onInputFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

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
      await _requestInputFocus(
        delay: _switcherDuration,
        recycleFocus: true,
      );
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
        _isDaily = task.isDaily;
        _dailyUntil = task.dailyUntil;
        _dueDate = task.dueDate;
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
    await _requestInputFocus(recycleFocus: true);
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
      final keepKeyboard = _focusNode.hasFocus;
      await AppHaptics.light();
      if (mounted) {
        await _showCardFeedback(
          CollectCardFeedback.emptyHint,
          const Duration(seconds: 1),
        );
      }
      if (keepKeyboard && mounted && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
      return;
    }
    await _performSave();
  }

  Future<void> _performSave() async {
    final keepKeyboard = _keyboardWasOpenBeforeGesture ?? _focusNode.hasFocus;
    _keyboardWasOpenBeforeGesture = null;

    final repo = await ref.read(taskRepositoryProvider.future);

    final hasAudio = _attachments.any((a) => a.type == AttachmentType.audio);
    final task = await repo.createInbox(
      title: _controller.text.trim(),
      attachments: List.from(_attachments),
      transcriptionStatus:
          hasAudio ? TranscriptionStatus.pending : TranscriptionStatus.none,
      isDaily: _isDaily,
      dailyUntil: _isDaily ? _dailyUntil : null,
      dueDate: _isDaily ? null : _dueDate,
    );

    unawaited(triggerSyncIfSignedIn(ref));

    if (hasAudio) {
      unawaited(ref.read(transcriptionServiceProvider).processTask(task));
    }

    if (!mounted) return;

    setState(() {
      _controller.clear();
      _attachments.clear();
      _isDaily = false;
      _dailyUntil = null;
      _dueDate = null;
      _lastUndoTask = task;
    });
    _ensureCaretVisible();

    await _swipeKey.currentState?.resetPosition(enterFromBottom: true);
    if (!mounted) return;

    _showSaveSnackbar();
    await _restoreInputAfterSave(
      keepKeyboard: keepKeyboard,
      delay: _switcherDuration,
    );
    if (keepKeyboard && mounted && !_focusNode.hasFocus) {
      _ensureCaretVisible();
      FocusScope.of(context).requestFocus(_focusNode);
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
      if (keepKeyboard && mounted && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
      return;
    }

    _saving = true;
    try {
      if (animated) {
        _rememberKeyboardState();
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
    } finally {
      _saving = false;
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
      await AppHaptics.light();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CardStage(
            swipeKey: _swipeKey,
            enabled: true,
            resetAfterAction: false,
            shouldAnimateFlyout: (_) async => _hasContent,
            onFlyoutFeedback: _collectFlyoutFeedback,
            onDragStart: _rememberKeyboardState,
            onSwipeUp: _onSwipeUp,
            rightLabel: '',
            leftLabel: '',
            child: BigTaskCard(
              mode: BigTaskCardMode.collect,
              controller: _controller,
              focusNode: _focusNode,
              inputFieldKey: ValueKey('collect-input-$_collectInputEpoch'),
              onActivateInput: _activateInput,
              feedback: _recording ? CollectCardFeedback.listening : _feedback,
              onDismissFeedback: _dismissCardFeedback,
              onChanged: (_) => setState(() {}),
              attachments: _attachments,
              onRemoveAttachment: _removeAttachment,
              onPickImage: _pickImage,
              onStartSpeech: kIsWeb ? null : _toggleRecording,
              isListening: _recording,
              onSave: () => _save(animated: true),
              scheduleEditor: TaskScheduleEditor(
                isDaily: _isDaily,
                dailyUntil: _dailyUntil,
                dueDate: _dueDate,
                onDailyChanged: (value) =>
                    setState(() => _isDaily = value),
                onDailyUntilChanged: (value) =>
                    setState(() => _dailyUntil = value),
                onDueDateChanged: (value) =>
                    setState(() => _dueDate = value),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
