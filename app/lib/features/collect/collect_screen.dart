import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';
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

  Future<void> _save() async {
    if (!_hasContent) {
      await AppHaptics.light();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('先记下点什么'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.createInbox(
      title: _controller.text.trim(),
      attachments: List.from(_attachments),
      transcriptionStatus: _attachments.any((a) => a.type == AttachmentType.audio)
          ? TranscriptionStatus.pending
          : TranscriptionStatus.none,
    );
    await triggerSyncIfSignedIn(ref);

    _controller.clear();
    _attachments.clear();
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已收集，去处理页看看'),
          duration: Duration(seconds: 2),
        ),
      );
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
    return SafeArea(
      child: SwipeableCard(
        onSwipeUp: _save,
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
        ),
      ),
    );
  }
}
