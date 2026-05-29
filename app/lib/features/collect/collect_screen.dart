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
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';
import 'package:todo_app/shared/widgets/card_stage.dart';
import 'package:todo_app/shared/widgets/hint_chip.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';

class CollectScreen extends ConsumerStatefulWidget {
  const CollectScreen({super.key});

  @override
  ConsumerState<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends ConsumerState<CollectScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _speech = SpeechToText();
  final _swipeKey = GlobalKey<SwipeableCardState>();
  bool _listening = false;
  final List<TaskAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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

  Future<void> _save({bool animated = false}) async {
    if (!_hasContent) {
      await AppHaptics.light();
      if (mounted) {
        showAppSnackBar(
          context,
          message: '先记下点什么',
          icon: Icons.edit_note_outlined,
          type: AppSnackType.warning,
          duration: const Duration(seconds: 1),
        );
      }
      return;
    }

    Future<void> doSave() async {
      final repo = await ref.read(taskRepositoryProvider.future);
      await repo.createInbox(
        title: _controller.text.trim(),
        attachments: List.from(_attachments),
        transcriptionStatus:
            _attachments.any((a) => a.type == AttachmentType.audio)
                ? TranscriptionStatus.pending
                : TranscriptionStatus.none,
      );
      await triggerSyncIfSignedIn(ref);

      _controller.clear();
      _attachments.clear();
      setState(() {});

      if (mounted) {
        showAppSnackBar(
          context,
          message: '已收集，去处理页看看',
          icon: Icons.check_circle_outline,
          type: AppSnackType.success,
          duration: const Duration(seconds: 2),
        );
      }
    }

    if (animated) {
      final state = _swipeKey.currentState;
      if (state != null) {
        await state.animateFlyout(const Offset(0, -1.5), doSave);
      } else {
        await doSave();
      }
    } else {
      await doSave();
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

  @override
  Widget build(BuildContext context) {
    final touchFirst = isTouchFirstPlatform;

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
        child: SafeArea(
          child: Column(
            children: [
              HintChip(
                text: touchFirst ? '上划保存' : 'Enter 保存',
              ),
              CardStage(
                swipeKey: _swipeKey,
                enabled: touchFirst,
                onSwipeUp: () => _save(),
                rightLabel: '',
                leftLabel: '',
                child: BigTaskCard(
                  mode: BigTaskCardMode.collect,
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (_) => setState(() {}),
                  onPickImage: _pickImage,
                  onStartSpeech: _toggleSpeech,
                  isListening: _listening,
                  onSave: () => _save(animated: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
