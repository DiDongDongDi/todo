import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'package:todo_app/shared/utils/speech_intent_platform.dart';

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
    if (!mounted || _listening) return;
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

    unawaited(_requestInputFocus());

  }

  void _onInputFocusChange() {
    if (_focusNode.hasFocus && mounted) {
      _ensureCaretVisible();
    }
  }



  void _showSpeechUnavailable() {
    showAppSnackBar(
      context,
      message: '无法使用语音输入，请检查麦克风权限或系统语音识别设置',
      icon: Icons.mic_off_outlined,
      type: AppSnackType.error,
    );
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speech.isAvailable) return true;

    final ready = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        setState(() => _listening = false);
        showAppSnackBar(
          context,
          message: _speechErrorMessage(error.errorMsg),
          icon: Icons.mic_off_outlined,
          type: AppSnackType.error,
        );
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == SpeechToText.listeningStatus) {
          setState(() => _listening = true);
        } else if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          if (_listening) setState(() => _listening = false);
        }
      },
      debugLogging: kDebugMode,
    );

    if (!ready && mounted) _showSpeechUnavailable();
    return ready;
  }

  String _speechErrorMessage(String code) {
    return switch (code) {
      'error_speech_timeout' => '没有听到说话，请再试一次',
      'error_no_match' => '未识别到语音，请再试一次',
      'error_permission' || 'error_audio_error' => '无法使用麦克风，请检查权限',
      'error_network' || 'error_network_timeout' => '语音识别需要网络连接',
      _ => '语音识别出错：$code',
    };
  }

  void _showMiuiSpeechEngineHint() {
    showAppSnackBar(
      context,
      message: '系统语音引擎未就绪。可在「设置 → 小爱同学」授权语音，或安装 Google 应用后重试',
      icon: Icons.info_outline,
      type: AppSnackType.warning,
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _toggleSpeechViaIntent() async {
    _focusNode.unfocus();
    setState(() => _listening = true);

    final result = await SpeechIntentPlatform.recognize();
    if (!mounted) return;

    if (result.text?.trim().isNotEmpty == true) {
      setState(() => _listening = false);
      _controller.text = result.text!.trim();
      _ensureCaretVisible();
      setState(() {});
      await AppHaptics.light();
      return;
    }

    if (result.permissionDenied) {
      setState(() => _listening = false);
      _showSpeechUnavailable();
      return;
    }

    if (result.cancelled) {
      setState(() => _listening = false);
      return;
    }

    if (result.engineFailed) {
      _showMiuiSpeechEngineHint();
    }

    // 系统面板失败时，回退到应用内实时识别
    setState(() => _listening = false);
    await _toggleSpeechInline();
  }

  Future<void> _toggleSpeechInline() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    _focusNode.unfocus();

    if (!await _ensureSpeechReady()) return;
    if (!mounted) return;

    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      _showSpeechUnavailable();
      return;
    }

    setState(() => _listening = true);

    try {
      String? localeId;
      final locales = await _speech.locales();
      for (final locale in locales) {
        if (locale.localeId.startsWith('zh')) {
          localeId = locale.localeId;
          break;
        }
      }
      localeId ??= locales.isNotEmpty ? locales.first.localeId : null;

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
          setState(() {});
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          localeId: localeId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      if (!_speech.isListening) {
        setState(() => _listening = false);
        _showSpeechUnavailable();
        return;
      }

      await AppHaptics.light();
    } catch (_) {
      if (!mounted) return;
      setState(() => _listening = false);
      _showSpeechUnavailable();
    }
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
    if (await SpeechIntentPlatform.isSupported) {
      await _toggleSpeechViaIntent();
      return;
    }
    await _toggleSpeechInline();
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

              feedback:
                  _listening ? CollectCardFeedback.listening : _feedback,

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


