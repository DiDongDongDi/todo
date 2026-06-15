import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_template.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/utils/app_audio_recorder.dart';
import 'package:todo_app/shared/utils/attachment_storage.dart';
import 'package:todo_app/shared/utils/audio_storage.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/attachment_image.dart';
import 'package:todo_app/shared/widgets/audio_preview.dart';
import 'package:todo_app/shared/widgets/image_preview.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';
import 'package:todo_app/shared/widgets/task_check_in_editor.dart';
import 'package:todo_app/shared/widgets/task_schedule_editor.dart';

class TemplateEditScreen extends ConsumerStatefulWidget {
  const TemplateEditScreen({super.key, required this.templateId});

  final String templateId;

  @override
  ConsumerState<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends ConsumerState<TemplateEditScreen> {
  final _titleController = TextEditingController();
  final _subtaskControllers = <TextEditingController>[];
  final _attachments = <TaskAttachment>[];
  final _audioRecorder = AppAudioRecorder();

  bool _loading = true;
  bool _recording = false;
  TaskTemplate? _template;
  TaskRecurrence _recurrence = TaskRecurrence.none;
  DateTime? _dailyUntil;
  DateTime? _dueDate;
  int _checkInTarget = 1;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await ref.read(templateRepositoryProvider.future);
    final template = await repo.getById(widget.templateId);
    if (!mounted) return;

    if (template != null) {
      _titleController.text = template.title;
      _recurrence = template.recurrence;
      _dailyUntil = template.dailyUntil;
      _dueDate = template.dueDate;
      _checkInTarget = template.checkInTarget;
      _attachments
        ..clear()
        ..addAll(template.attachments);
      for (final title in template.subtaskTitles) {
        _subtaskControllers.add(TextEditingController(text: title));
      }
    }

    setState(() {
      _template = template;
      _loading = false;
    });
  }

  void _addSubtaskField() {
    unawaited(AppHaptics.light());
    setState(() => _subtaskControllers.add(TextEditingController()));
  }

  void _removeSubtaskField(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
    });
  }

  void _importSubtaskLines(int index, List<String> lines) {
    setState(() {
      SubtaskTitleEditor.importLinesIntoControllers(
        controllers: _subtaskControllers,
        index: index,
        lines: lines,
      );
    });
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _pickImage() async {
    unawaited(AppHaptics.light());
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

  Future<void> _toggleRecording() async {
    unawaited(AppHaptics.light());
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

  Future<bool> _persist() async {
    final template = _template;
    if (template == null) return false;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showAppSnackBar(
        context,
        message: '请输入模板标题',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
      return false;
    }

    setState(() => _saving = true);
    try {
      final repo = await ref.read(templateRepositoryProvider.future);
      final updated = await repo.update(
        template.copyWith(
          title: title,
          attachments: List.from(_attachments),
          recurrence: _recurrence,
          dailyUntil: _recurrence != TaskRecurrence.none ? _dailyUntil : null,
          dueDate: _recurrence == TaskRecurrence.daily ? null : _dueDate,
          clearDailyUntil:
              _recurrence == TaskRecurrence.none || _dailyUntil == null,
          clearDueDate: _recurrence == TaskRecurrence.daily || _dueDate == null,
          subtaskTitles: _subtaskControllers
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList(),
          checkInTarget: _checkInTarget.clamp(1, 99),
        ),
      );
      unawaited(triggerSyncIfSignedIn(ref));
      if (!mounted) return false;
      setState(() {
        _template = updated;
        _saving = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _saving = false);
      showAppSnackBar(
        context,
        message: '无法保存模板',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
      return false;
    }
  }

  Future<void> _save() async {
    if (!await _persist()) return;
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '模板已保存',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
    context.pop();
  }

  Future<void> _createTask() async {
    if (!await _persist()) return;
    final repo = await ref.read(templateRepositoryProvider.future);
    final created = await repo.createTasksFromTemplate(widget.templateId);
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已创建 ${created.length} 个任务',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
  }

  Widget _buildAttachmentPreview(BuildContext context) {
    if (_attachments.isEmpty) return const SizedBox.shrink();

    final imageAttachments =
        _attachments.where((a) => a.type == AttachmentType.image).toList();
    final audioAttachments =
        _attachments.where((a) => a.type == AttachmentType.audio).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _attachments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return _TemplateAttachmentThumbnail(
                attachment: _attachments[index],
                imageAttachments: imageAttachments,
                audioAttachments: audioAttachments,
                onRemove: () => _removeAttachment(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const compact = VisualDensity.compact;
    const gap = SizedBox(width: 4);

    return Row(
      children: [
        TaskScheduleEditor(
          recurrence: _recurrence,
          dailyUntil: _dailyUntil,
          dueDate: _dueDate,
          onRecurrenceChanged: (value) => setState(() => _recurrence = value),
          onDailyUntilChanged: (value) => setState(() => _dailyUntil = value),
          onDueDateChanged: (value) => setState(() => _dueDate = value),
        ),
        const SizedBox(width: 8),
        TaskCheckInEditor(
          checkInTarget: _checkInTarget,
          onCheckInTargetChanged: (value) =>
              setState(() => _checkInTarget = value),
        ),
        const Spacer(),
        IconButton.filledTonal(
          onPressed: _pickImage,
          icon: const Icon(Icons.image_outlined),
          tooltip: '添加图片',
          visualDensity: compact,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        gap,
        IconButton.filledTonal(
          onPressed: !kIsWeb ? _toggleRecording : null,
          icon: Icon(
            _recording ? Icons.stop : Icons.mic_none_outlined,
          ),
          tooltip: _recording ? '停止录音' : '录音',
          visualDensity: compact,
          style: IconButton.styleFrom(
            backgroundColor:
                _recording ? colorScheme.errorContainer : null,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_template == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('模板不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑模板'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
          ),
          _buildAttachmentPreview(context),
          const SizedBox(height: 16),
          _buildToolbarRow(context),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                '子任务',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addSubtaskField,
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
          if (_subtaskControllers.isNotEmpty) ...[
            const SizedBox(height: 8),
            SubtaskTitleEditor(
              controllers: _subtaskControllers,
              onRemove: _removeSubtaskField,
              onImportLines: _importSubtaskLines,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _createTask,
            child: const Text('创建任务'),
          ),
        ],
      ),
    );
  }
}

class _TemplateAttachmentThumbnail extends StatelessWidget {
  const _TemplateAttachmentThumbnail({
    required this.attachment,
    this.imageAttachments = const [],
    this.audioAttachments = const [],
    this.onRemove,
  });

  final TaskAttachment attachment;
  final List<TaskAttachment> imageAttachments;
  final List<TaskAttachment> audioAttachments;
  final VoidCallback? onRemove;

  bool get _isPreviewable =>
      attachment.type == AttachmentType.image ||
      attachment.type == AttachmentType.audio;

  void _openPreview(BuildContext context) {
    if (!_isPreviewable) return;

    FocusManager.instance.primaryFocus?.unfocus();

    if (attachment.type == AttachmentType.image) {
      final images =
          imageAttachments.isNotEmpty ? imageAttachments : [attachment];
      final index = images.indexWhere(
        (a) =>
            a.localPath == attachment.localPath &&
            a.remoteUrl == attachment.remoteUrl,
      );

      showAttachmentImagePreview(
        context,
        attachments: images,
        initialIndex: index >= 0 ? index : 0,
      );
      return;
    }

    final audios =
        audioAttachments.isNotEmpty ? audioAttachments : [attachment];
    final index = audios.indexWhere(
      (a) =>
          a.localPath == attachment.localPath &&
          a.remoteUrl == attachment.remoteUrl,
    );

    showAttachmentAudioPreview(
      context,
      attachments: audios,
      initialIndex: index >= 0 ? index : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isImage = attachment.type == AttachmentType.image;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _isPreviewable ? () => _openPreview(context) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: isImage
                  ? AttachmentImage(
                      attachment,
                      fit: BoxFit.cover,
                    )
                  : ColoredBox(
                      color: colorScheme.secondaryContainer,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mic_none_outlined,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          if (attachment.duration != null &&
                              attachment.duration! > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              formatAudioDuration(attachment.duration),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
