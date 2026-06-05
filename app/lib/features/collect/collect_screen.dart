import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:image_picker/image_picker.dart';

import 'package:speech_to_text/speech_to_text.dart';

import 'package:todo_app/core/models/task.dart';

import 'package:todo_app/core/repositories/task_repository.dart';

import 'package:todo_app/core/sync/sync_engine.dart';

import 'package:todo_app/shared/utils/haptics.dart';

import 'package:todo_app/shared/utils/platform_capabilities.dart';

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

  String? _stageMessage;

  int _feedbackEpoch = 0;



  @override

  void initState() {

    super.initState();

    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);

    _initSpeech();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      _focusNode.requestFocus();

    });

  }



  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey != LogicalKeyboardKey.enter) {

      return KeyEventResult.ignored;

    }

    // Shift+Enter 换行，Enter 保存。

    if (HardwareKeyboard.instance.isShiftPressed) {

      return KeyEventResult.ignored;

    }

    _save(animated: true);

    return KeyEventResult.handled;

  }



  Future<void> _initSpeech() async {

    await _speech.initialize();

  }



  @override

  void dispose() {

    _controller.dispose();

    _focusNode.dispose();

    super.dispose();

  }



  bool get _hasContent =>

      _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;



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

      _focusNode.requestFocus();

    }

  }



  Future<void> _showStageSavedMessage() async {

    final epoch = ++_feedbackEpoch;

    setState(() => _stageMessage = '已收集');

    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted || epoch != _feedbackEpoch) return;

    setState(() => _stageMessage = null);

    await _swipeKey.currentState?.resetPosition(enterFromBottom: true);

    if (mounted) _focusNode.requestFocus();

  }



  Future<void> _onSwipeUp() async {

    if (!_hasContent) {

      await _swipeKey.currentState?.resetPosition(animated: false);

      await AppHaptics.light();

      if (mounted) {

        await _showCardFeedback(

          CollectCardFeedback.emptyHint,

          const Duration(seconds: 1),

          refocus: true,

        );

      }

      return;

    }



    await _performSave();

  }



  Future<void> _performSave() async {

    final repo = await ref.read(taskRepositoryProvider.future);

    await repo.createInbox(

      title: _controller.text.trim(),

      attachments: List.from(_attachments),

      transcriptionStatus:

          _attachments.any((a) => a.type == AttachmentType.audio)

              ? TranscriptionStatus.pending

              : TranscriptionStatus.none,

    );

    unawaited(triggerSyncIfSignedIn(ref));

    _controller.clear();

    _attachments.clear();



    if (mounted) {

      await _showStageSavedMessage();

    }

  }



  Future<void> _save({bool animated = false}) async {

    if (!_hasContent) {

      await AppHaptics.light();

      if (mounted) {

        await _showCardFeedback(

          CollectCardFeedback.emptyHint,

          const Duration(seconds: 1),

          refocus: true,

        );

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

    setState(() {

      _attachments.add(

        TaskAttachment(type: AttachmentType.image, localPath: file.path),

      );

    });

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



  Widget? _buildStageOverlay(BuildContext context) {

    if (_stageMessage == null) return null;



    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;



    return IgnorePointer(

      child: Center(

        child: AnimatedSwitcher(

          duration: const Duration(milliseconds: 200),

          child: Text(

            _stageMessage!,

            key: ValueKey(_stageMessage),

            style: theme.textTheme.headlineMedium?.copyWith(

              color: colorScheme.onSurface.withValues(alpha: 0.45),

              fontWeight: FontWeight.w400,

              height: 1.35,

            ),

            textAlign: TextAlign.center,

          ),

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final touchFirst = isTouchFirstPlatform;



    final body = Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Expanded(

          child: CardStage(

            swipeKey: _swipeKey,

            enabled: touchFirst,

            resetAfterAction: false,

            overlay: _buildStageOverlay(context),

            onSwipeUp: _onSwipeUp,

            rightLabel: '',

            leftLabel: '',

            child: BigTaskCard(
              mode: BigTaskCardMode.collect,

              controller: _controller,

              focusNode: _focusNode,

              feedback: _feedback,

              onChanged: (_) => setState(() {}),

              onPickImage: _pickImage,

              onStartSpeech: _toggleSpeech,

              isListening: _listening,

              onSave: () => _save(animated: true),

            ),

          ),

        ),

      ],

    );



    return CallbackShortcuts(

      bindings: {

        const SingleActivator(LogicalKeyboardKey.enter): () => _save(animated: true),

        const SingleActivator(

          LogicalKeyboardKey.enter,

          control: true,

        ): () => _save(animated: true),

      },

      child: Focus(

        autofocus: true,

        child: body,

      ),

    );

  }

}


