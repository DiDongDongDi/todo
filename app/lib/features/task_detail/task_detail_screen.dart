import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_check_in.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/core/transcription/transcription_service.dart';
import 'package:todo_app/shared/utils/app_audio_recorder.dart';
import 'package:todo_app/shared/utils/attachment_storage.dart';
import 'package:todo_app/shared/utils/audio_storage.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/attachment_image.dart';
import 'package:todo_app/shared/widgets/audio_preview.dart';
import 'package:todo_app/shared/widgets/haptic_tap_scope.dart';
import 'package:todo_app/shared/widgets/image_preview.dart';
import 'package:todo_app/shared/widgets/keyboard_lift.dart';
import 'package:todo_app/shared/widgets/save_template_dialog.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';
import 'package:todo_app/shared/widgets/task_check_in_editor.dart';
import 'package:todo_app/shared/widgets/task_schedule_editor.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _loading = true;
  bool _editingSubtasks = false;
  bool _editingTask = false;
  Task? _task;
  List<Task> _subtasks = const [];
  List<Task> _subtaskSnapshot = const [];
  final List<TextEditingController> _editSubtaskControllers = [];
  final List<String?> _editSubtaskIds = [];

  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();
  TaskRecurrence _editRecurrence = TaskRecurrence.none;
  DateTime? _editDailyUntil;
  DateTime? _editDueDate;
  int _editCheckInTarget = 1;
  final List<TaskAttachment> _editAttachments = [];
  bool _editRecording = false;
  final _editAudioRecorder = AppAudioRecorder();
  bool _editPendingFocus = false;
  int _transientUiDepth = 0;

  bool get _editTaskUiVisible =>
      _editFocusNode.hasFocus ||
      _editRecording ||
      _editPendingFocus ||
      _transientUiDepth > 0;

  @override
  void initState() {
    super.initState();
    _editFocusNode.addListener(_onEditFocusChange);
    _load();
  }

  @override
  void dispose() {
    _editFocusNode.removeListener(_onEditFocusChange);
    _editController.dispose();
    _editFocusNode.dispose();
    _clearEditSubtaskFields();
    unawaited(_editAudioRecorder.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    final repo = await ref.read(taskRepositoryProvider.future);
    final task = await repo.getById(widget.taskId);
    final subtasks =
        task != null ? await repo.getSubtasks(widget.taskId) : <Task>[];
    if (!mounted) return;
    setState(() {
      _task = task;
      _subtasks = subtasks;
      _loading = false;
    });
  }

  void _onEditFocusChange() {
    if (!mounted) return;
    if (_editFocusNode.hasFocus) {
      _editPendingFocus = false;
      _ensureEditCaretVisible();
    }
    setState(() {});
  }

  void _beginTransientEditUi() {
    _transientUiDepth++;
  }

  void _endTransientEditUi() {
    if (_transientUiDepth > 0) _transientUiDepth--;
    if (!mounted) return;
    setState(() {});
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
    if (!mounted || !_editingTask) return;

    _ensureEditCaretVisible();
    FocusScope.of(context).requestFocus(_editFocusNode);

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_editingTask) return;
    _ensureEditCaretVisible();
  }

  void _syncEditFieldsFromTask(Task task) {
    _editController.text = task.displayTitle;
    _editRecurrence = task.recurrence;
    _editDailyUntil = task.dailyUntil;
    _editDueDate = task.dueDate;
    _editCheckInTarget = task.checkInTarget;
    _editAttachments
      ..clear()
      ..addAll(task.attachments);
  }

  void _startTaskEdit() {
    final task = _task;
    if (task == null || _editTaskUiVisible) return;
    if (_editingSubtasks) {
      _cancelSubtaskEdit();
    }
    _syncEditFieldsFromTask(task);
    _editRecording = false;
    _editPendingFocus = true;
    setState(() => _editingTask = true);
    unawaited(_requestEditFocus());
  }

  void _exitTaskEditMode([Task? task]) {
    if (!_editingTask && !_editTaskUiVisible) return;
    _editPendingFocus = false;
    setState(() => _editingTask = false);
    _editFocusNode.unfocus();
    if (task != null) {
      _syncEditFieldsFromTask(task);
    }
    if (_editRecording) {
      _editRecording = false;
      unawaited(_editAudioRecorder.stop());
    }
  }

  void _cancelTaskEdit() {
    final task = _task;
    if (task == null) return;
    unawaited(AppHaptics.light());
    _exitTaskEditMode(task);
  }

  Future<void> _saveTaskEdit() async {
    final task = _task;
    if (task == null) return;
    await AppHaptics.light();

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

    try {
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

      setState(() => _task = updated);
      _exitTaskEditMode(updated);
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '已保存',
        icon: Icons.check_circle_outline,
        type: AppSnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '无法保存',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
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

  void _clearEditSubtaskFields() {
    for (final c in _editSubtaskControllers) {
      c.dispose();
    }
    _editSubtaskControllers.clear();
    _editSubtaskIds.clear();
  }

  void _enterSubtaskEdit({bool addEmptyRow = false}) {
    if (_editingTask) {
      _cancelTaskEdit();
    }
    _clearEditSubtaskFields();
    _subtaskSnapshot = List.from(_subtasks);
    for (final sub in _subtasks) {
      _editSubtaskControllers.add(TextEditingController(text: sub.title));
      _editSubtaskIds.add(sub.id);
    }
    if (addEmptyRow && _editSubtaskControllers.isEmpty) {
      _editSubtaskControllers.add(TextEditingController());
      _editSubtaskIds.add(null);
    }
    setState(() => _editingSubtasks = true);
  }

  void _addEditSubtaskField() {
    setState(() {
      _editSubtaskControllers.add(TextEditingController());
      _editSubtaskIds.add(null);
    });
  }

  Future<int> _submitEditSubtaskRow(int index) async {
    setState(() {
      _editSubtaskControllers.insert(index + 1, TextEditingController());
      _editSubtaskIds.insert(index + 1, null);
    });
    return index + 1;
  }

  void _removeEditSubtaskField(int index) {
    setState(() {
      _editSubtaskControllers[index].dispose();
      _editSubtaskControllers.removeAt(index);
      _editSubtaskIds.removeAt(index);
    });
  }

  void _importEditSubtaskLines(int index, List<String> lines) {
    setState(() {
      SubtaskTitleEditor.importLinesIntoControllers(
        controllers: _editSubtaskControllers,
        index: index,
        lines: lines,
      );
      for (var i = 1; i < lines.length; i++) {
        _editSubtaskIds.insert(index + i, null);
      }
    });
  }

  void _cancelSubtaskEdit() {
    _clearEditSubtaskFields();
    setState(() {
      _editingSubtasks = false;
      _subtaskSnapshot = const [];
    });
  }

  Future<void> _saveSubtaskEdit() async {
    final repo = await ref.read(taskRepositoryProvider.future);
    final snapshotById = {for (final s in _subtaskSnapshot) s.id: s};
    final currentIds = _editSubtaskIds.whereType<String>().toSet();

    try {
      for (final id in snapshotById.keys) {
        if (!currentIds.contains(id)) {
          await repo.trash(id);
        }
      }

      for (var i = 0; i < _editSubtaskControllers.length; i++) {
        final title = _editSubtaskControllers[i].text.trim();
        final id = _editSubtaskIds[i];

        if (id == null) {
          if (title.isNotEmpty) {
            await repo.createSubtask(parentId: widget.taskId, title: title);
          }
          continue;
        }

        if (title.isEmpty) {
          await repo.trash(id);
          continue;
        }

        final original = snapshotById[id];
        if (original != null && original.title != title) {
          await repo.update(original.copyWith(title: title));
        }
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '无法保存子任务',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
      return;
    }

    _clearEditSubtaskFields();
    setState(() {
      _editingSubtasks = false;
      _subtaskSnapshot = const [];
    });
    await _load();
    unawaited(triggerSyncIfSignedIn(ref));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已保存子任务',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
  }

  Future<void> _saveAsTemplate() async {
    final task = _task;
    if (task == null) return;

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

  Future<void> _resetCheckInProgress() async {
    final task = _task;
    if (task == null || !hasResettableCheckInProgress(task)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重置打卡进度'),
          content: Text(
            '确定将「${task.displayTitle}」的打卡进度重置为 0/${task.checkInTarget}？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重置'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await AppHaptics.light();
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.resetCheckInProgress(task.id);
    unawaited(triggerSyncIfSignedIn(ref));
    await _load();
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '打卡进度已重置',
      icon: Icons.restart_alt,
      type: AppSnackType.success,
    );
  }

  Future<void> _deleteParentTask() async {
    final task = _task;
    if (task == null || _editingTask || _editingSubtasks) return;

    final subtaskCount = _subtasks.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          title: const Text('删除父任务'),
          content: Text(
            subtaskCount > 0
                ? '确定删除「${task.displayTitle}」？其 $subtaskCount 条子任务也将一并删除。'
                : '确定删除「${task.displayTitle}」？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.trash(task.id);
    unawaited(triggerSyncIfSignedIn(ref));
    await AppHaptics.medium();
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已删除',
      icon: Icons.delete_outline,
      type: AppSnackType.error,
    );
    context.pop();
  }

  Widget _buildSubtaskToolbar(BuildContext context) {
    const compact = VisualDensity.compact;
    const gap = SizedBox(width: 4);

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: _addEditSubtaskField,
          icon: const Icon(Icons.playlist_add_outlined),
          tooltip: '添加子任务',
          visualDensity: compact,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _cancelSubtaskEdit,
          style: TextButton.styleFrom(
            visualDensity: compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('取消'),
        ),
        gap,
        Focus(
          canRequestFocus: false,
          child: FilledButton(
            onPressed: _saveSubtaskEdit,
            style: FilledButton.styleFrom(
              visualDensity: compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtaskSection(BuildContext context) {
    if (_editingSubtasks) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          SubtaskTitleEditor(
            controllers: _editSubtaskControllers,
            onRemove: _removeEditSubtaskField,
            onSubmitRow: _submitEditSubtaskRow,
            onImportLines: _importEditSubtaskLines,
          ),
          const SizedBox(height: 16),
          _buildSubtaskToolbar(context),
        ],
      );
    }

    if (_subtasks.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          SubtaskListSection(subtasks: _subtasks),
          if (!_editingTask) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _enterSubtaskEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑子任务'),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          '暂无子任务',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (!_editingTask) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _enterSubtaskEdit(addEmptyRow: true),
              icon: const Icon(Icons.playlist_add_outlined, size: 18),
              label: const Text('添加子任务'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentWrap(
    BuildContext context, {
    required List<TaskAttachment> attachments,
    ValueChanged<int>? onRemove,
  }) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final imageAttachments =
        attachments.where((a) => a.type == AttachmentType.image).toList();
    final audioAttachments =
        attachments.where((a) => a.type == AttachmentType.audio).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < attachments.length; i++)
          _TaskAttachmentThumbnail(
            attachment: attachments[i],
            imageAttachments: imageAttachments,
            audioAttachments: audioAttachments,
            onRemove: onRemove == null ? null : () => onRemove(i),
          ),
      ],
    );
  }

  Widget _buildTaskHeader(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_editingTask) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _editController,
            focusNode: _editFocusNode,
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: theme.textTheme.headlineSmall,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
          if (_editTaskUiVisible && _editAttachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _editAttachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imageAttachments = _editAttachments
                      .where((a) => a.type == AttachmentType.image)
                      .toList();
                  final audioAttachments = _editAttachments
                      .where((a) => a.type == AttachmentType.audio)
                      .toList();
                  return _TaskAttachmentThumbnail(
                    attachment: _editAttachments[index],
                    imageAttachments: imageAttachments,
                    audioAttachments: audioAttachments,
                    onRemove: () => _removeEditAttachment(index),
                  );
                },
              ),
            ),
          ],
        ],
      );
    }

    final readOnlyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          task.displayTitle,
          style: theme.textTheme.headlineSmall,
        ),
        if (scheduleLabel(task) != null) ...[
          const SizedBox(height: 8),
          Text(
            scheduleLabel(task)!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isOverdue(task)
                  ? colorScheme.error
                  : colorScheme.primary,
            ),
          ),
        ],
        if (checkInLabel(task) != null) ...[
          const SizedBox(height: 4),
          Text(
            checkInLabel(task)!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
            ),
          ),
          if (hasResettableCheckInProgress(task)) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _resetCheckInProgress,
                child: const Text('重置进度'),
              ),
            ),
          ],
        ],
        if (task.attachments.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildAttachmentWrap(context, attachments: task.attachments),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _startTaskEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('编辑任务'),
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _startTaskEdit,
      child: readOnlyContent,
    );
  }

  Widget _buildTaskEditFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const compact = VisualDensity.compact;
    const gap = SizedBox(width: 4);

    return KeyboardLift(
      bottomObstruction: shellBottomObstruction(context),
      child: SuppressTapHaptic(
        child: ColoredBox(
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(
                children: [
                  TaskScheduleEditor(
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
                  ),
                  const SizedBox(width: 8),
                  TaskCheckInEditor(
                    checkInTarget: _editCheckInTarget,
                    onCheckInTargetChanged: (value) =>
                        setState(() => _editCheckInTarget = value),
                    onTransientUiOpening: _beginTransientEditUi,
                    onTransientUiClosed: _endTransientEditUi,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _pickEditImage,
                    icon: const Icon(Icons.image_outlined),
                    tooltip: '添加图片',
                    visualDensity: compact,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  gap,
                  IconButton.filledTonal(
                    onPressed: !kIsWeb ? _toggleEditRecording : null,
                    icon: Icon(
                      _editRecording ? Icons.stop : Icons.mic_none_outlined,
                    ),
                    tooltip: _editRecording ? '停止录音' : '录音',
                    visualDensity: compact,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          _editRecording ? colorScheme.errorContainer : null,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _cancelTaskEdit,
                    style: TextButton.styleFrom(
                      visualDensity: compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('取消'),
                  ),
                  gap,
                  Focus(
                    canRequestFocus: false,
                    child: FilledButton(
                      onPressed: _saveTaskEdit,
                      style: FilledButton.styleFrom(
                        visualDensity: compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final task = _task;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('任务不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('父任务'),
        actions: [
          if (!_editingTask && !_editingSubtasks) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              onPressed: _deleteParentTask,
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_outline),
              tooltip: '保存为模板',
              onPressed: _saveAsTemplate,
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _buildTaskHeader(context, task),
                _buildSubtaskSection(context),
              ],
            ),
          ),
          if (_editingTask) _buildTaskEditFooter(context),
        ],
      ),
    );
  }
}

class _TaskAttachmentThumbnail extends StatelessWidget {
  const _TaskAttachmentThumbnail({
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
