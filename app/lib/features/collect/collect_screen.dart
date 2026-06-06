import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:image_picker/image_picker.dart';

import 'package:speech_to_text/speech_to_text.dart';

import 'package:todo_app/core/settings/collect_sound_settings.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';

import 'package:todo_app/core/sync/sync_engine.dart';

import 'package:todo_app/shared/utils/attachment_storage.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/utils/sounds.dart';

import 'package:todo_app/shared/utils/platform_capabilities.dart';

import 'package:todo_app/shared/widgets/app_snackbar.dart';

import 'package:todo_app/shared/widgets/big_task_card.dart';

import 'package:todo_app/shared/widgets/card_stage.dart';

import 'package:todo_app/shared/widgets/swipeable_card.dart';



class CollectScreen extends ConsumerStatefulWidget {

  const CollectScreen({super.key});



  @override

  ConsumerState<CollectScreen> createState() => _CollectScreenState();

}



class _CollectScreenState extends ConsumerState<CollectScreen> {

  final _controller = TextEditingController();

  late final FocusNode _focusNode;

  final _speech = SpeechToText();

  final _swipeKey = GlobalKey<SwipeableCardState>();

  bool _listening = false;

  final List<TaskAttachment> _attachments = [];

  CollectCardFeedback _feedback = CollectCardFeedback.none;

  Task? _lastUndoTask;

  int _feedbackEpoch = 0;

  bool _saving = false;

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

  /// 单击卡片时也要刷新光标；仅 requestFocus 在已聚焦时不会触发 listener。
  void _activateInput() {
    _ensureCaretVisible();
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _requestInputFocus({
    Duration delay = Duration.zero,
    bool recycleFocus = false,
  }) async {
    if (!mounted) return;
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
    _focusNode.requestFocus();

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _ensureCaretVisible();
  }

  @override

  void initState() {

    super.initState();

    _focusNode = FocusNode();
    _focusNode.addListener(_onInputFocusChange);

    _initSpeech();

    unawaited(_requestInputFocus());

  }

  void _onInputFocusChange() {
    if (_focusNode.hasFocus && mounted) {
      _ensureCaretVisible();
    }
  }



  Future<void> _initSpeech() async {

    await _speech.initialize();

  }



  @override

  void dispose() {

    _focusNode.removeListener(_onInputFocusChange);
    _controller.dispose();

    _focusNode.dispose();

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
      });
      _ensureCaretVisible();
    }

    final state = _swipeKey.currentState;
    if (state != null) {
      // 空白卡片向下滑出 → 恢复内容 → 原卡片从上方滑入
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
    final repo = await ref.read(taskRepositoryProvider.future);

    final task = await repo.createInbox(

      title: _controller.text.trim(),

      attachments: List.from(_attachments),

      transcriptionStatus:

          _attachments.any((a) => a.type == AttachmentType.audio)

              ? TranscriptionStatus.pending

              : TranscriptionStatus.none,

    );

    unawaited(triggerSyncIfSignedIn(ref));

    _controller.clear();
    _ensureCaretVisible();

    _attachments.clear();

    _lastUndoTask = task;

    if (mounted) {
      await _swipeKey.currentState?.resetPosition(enterFromBottom: true);

      await _requestInputFocus(recycleFocus: true);

      _showSaveSnackbar();
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

        if (isTouchFirstPlatform) {
          _focusNode.unfocus();
        }

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



  Future<void> _toggleSpeech() async {

    if (_listening) {

      await _speech.stop();

      setState(() => _listening = false);

      return;

    }



    if (!await _speech.initialize()) return;



    setState(() => _listening = true);

    await _speech.listen(

      onResult: (result) {

        _controller.text = result.recognizedWords;

        _controller.selection = TextSelection.collapsed(

          offset: _controller.text.length,

        );

        setState(() {});

      },

    );

  }



  @override

  Widget build(BuildContext context) {
    final body = Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Expanded(

          child: CardStage(

            swipeKey: _swipeKey,

            enabled: true,

            resetAfterAction: false,

            shouldAnimateFlyout: (_) async => _hasContent,

            onFlyoutFeedback: _collectFlyoutFeedback,

            onDragStart: () => _focusNode.unfocus(),

            onDragEnd: () => unawaited(_requestInputFocus(recycleFocus: true)),

            onSwipeUp: _onSwipeUp,

            rightLabel: '',

            leftLabel: '',

            child: BigTaskCard(
              mode: BigTaskCardMode.collect,

              controller: _controller,

              focusNode: _focusNode,

              onActivateInput: _activateInput,

              feedback: _feedback,

              onDismissFeedback: _dismissCardFeedback,

              onChanged: (_) => setState(() {}),

              attachments: _attachments,

              onRemoveAttachment: _removeAttachment,

              onPickImage: _pickImage,

              onStartSpeech: _toggleSpeech,

              isListening: _listening,

              onSave: () => _save(animated: true),

            ),

          ),

        ),

      ],

    );



    return body;

  }

}


