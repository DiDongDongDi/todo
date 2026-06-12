import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:todo_app/core/import/subtask_batch_import_parser.dart';
import 'package:todo_app/core/models/task.dart';

TextStyle? subtaskTitleInputStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium;
}

InputDecoration subtaskTitleInputDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: colorScheme.outlineVariant),
  );

  return InputDecoration(
    hintText: '子任务',
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    ),
    isDense: true,
    filled: true,
    fillColor: colorScheme.surfaceContainerHigh,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),
    border: fieldBorder,
    enabledBorder: fieldBorder,
    focusedBorder: fieldBorder.copyWith(
      borderSide: BorderSide(color: colorScheme.primary),
    ),
  );
}

/// 草稿态子任务标题编辑（收集页保存前、处理页编辑态使用）。
class SubtaskTitleEditor extends StatefulWidget {
  const SubtaskTitleEditor({
    super.key,
    required this.controllers,
    required this.onRemove,
    this.onAnyFieldFocusChanged,
    this.onSubmitRow,
    this.onImportLines,
  });

  final List<TextEditingController> controllers;
  final ValueChanged<int> onRemove;
  final ValueChanged<bool>? onAnyFieldFocusChanged;
  final Future<int> Function(int index)? onSubmitRow;
  final void Function(int index, List<String> lines)? onImportLines;

  static List<String> nonEmptyTitles(Iterable<TextEditingController> controllers) {
    return controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Replaces row [index] with [lines].first and inserts the rest below.
  static void importLinesIntoControllers({
    required List<TextEditingController> controllers,
    required int index,
    required List<String> lines,
  }) {
    if (lines.isEmpty || index < 0 || index >= controllers.length) return;

    controllers[index].text = lines.first;
    for (var i = lines.length - 1; i >= 1; i--) {
      controllers.insert(index + 1, TextEditingController(text: lines[i]));
    }
  }

  @override
  State<SubtaskTitleEditor> createState() => _SubtaskTitleEditorState();
}

class _SubtaskTitleEditorState extends State<SubtaskTitleEditor> {
  final List<FocusNode> _focusNodes = [];
  int? _pendingFocusIndex;
  bool _pasteHandling = false;

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
  }

  @override
  void didUpdateWidget(SubtaskTitleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父级可能就地 mutate 同一 List，old/new widget 的 length 会相同。
    _syncFocusNodes();
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.removeListener(_notifyFocusChanged);
      node.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }

  bool _isPasteKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final keyboard = HardwareKeyboard.instance;
    final isModifierPaste = event.logicalKey == LogicalKeyboardKey.keyV &&
        (keyboard.isControlPressed || keyboard.isMetaPressed);
    final isShiftInsert = event.logicalKey == LogicalKeyboardKey.insert &&
        keyboard.isShiftPressed;

    return isModifierPaste || isShiftInsert;
  }

  KeyEventResult _handlePasteKey(int index, FocusNode node, KeyEvent event) {
    if (!_isPasteKeyEvent(event)) return KeyEventResult.ignored;
    unawaited(_handlePaste(index));
    return KeyEventResult.handled;
  }

  void _pasteSingleLine(int index, String text) {
    final controller = widget.controllers[index];
    final selection = controller.selection;
    final value = controller.text;
    final start = selection.start.clamp(0, value.length);
    final end = selection.end.clamp(0, value.length);
    final updated = value.replaceRange(start, end, text);
    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  Future<void> _handlePaste(int index) async {
    if (_pasteHandling) return;
    if (!mounted) return;
    if (index < 0 || index >= widget.controllers.length) return;

    _pasteHandling = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text;
      if (raw == null || raw.isEmpty) return;

      final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      if (!normalized.contains('\n')) {
        _pasteSingleLine(index, normalized);
        return;
      }

      final controller = widget.controllers[index];
      final selection = controller.selection;
      final value = controller.text;
      final start = selection.start.clamp(0, value.length);
      final end = selection.end.clamp(0, value.length);
      final before = value.substring(0, start);
      final after = value.substring(end);

      var lines = parseSubtaskBatchImport(normalized);
      if (lines.isEmpty) return;

      if (before.isNotEmpty || after.isNotEmpty) {
        lines = [before + lines.first, ...lines.skip(1)];
        if (after.isNotEmpty) {
          lines[lines.length - 1] = lines.last + after;
        }
      }

      if (lines.length == 1) {
        controller.text = lines.first;
        controller.selection =
            TextSelection.collapsed(offset: lines.first.length);
        return;
      }

      widget.onImportLines?.call(index, lines);
    } finally {
      _pasteHandling = false;
    }
  }

  TextInputFormatter _pasteFallbackFormatter(int index) {
    return _SubtaskPasteFallbackFormatter(
      onMultilinePaste: () => _handlePaste(index),
      onRecoverCollapsedPaste: (oldValue, newValue) =>
          _recoverCollapsedMultilinePaste(index, oldValue, newValue),
    );
  }

  Future<void> _recoverCollapsedMultilinePaste(
    int index,
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) async {
    if (!mounted) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text;
    if (raw == null || (!raw.contains('\n') && !raw.contains('\r'))) {
      return;
    }

    final inserted = _extractInsertedText(oldValue, newValue);
    if (inserted.isEmpty) return;

    final collapsed = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
    final insertedTrimmed = inserted.replaceAll(RegExp(r' +'), ' ').trim();

    if (insertedTrimmed != collapsed && !collapsed.contains(insertedTrimmed)) {
      return;
    }

    widget.controllers[index].value = oldValue;
    await _handlePaste(index);
  }

  String _extractInsertedText(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    if (newText.length <= oldText.length) return '';

    final selection = oldValue.selection;
    final start = selection.start.clamp(0, oldText.length);
    final end = selection.end.clamp(0, oldText.length);
    final prefix = oldText.substring(0, start);
    final suffix = oldText.substring(end);

    if (!newText.startsWith(prefix) || !newText.endsWith(suffix)) {
      return newText.substring(start, newText.length - suffix.length);
    }

    return newText.substring(start, newText.length - suffix.length);
  }

  void _syncFocusNodes() {
    var changed = false;
    while (_focusNodes.length < widget.controllers.length) {
      final index = _focusNodes.length;
      final node = FocusNode(
        onKeyEvent: (node, event) => _handlePasteKey(index, node, event),
      );
      node.addListener(_notifyFocusChanged);
      _focusNodes.add(node);
      changed = true;
    }
    while (_focusNodes.length > widget.controllers.length) {
      final node = _focusNodes.removeLast();
      node.removeListener(_notifyFocusChanged);
      node.dispose();
      changed = true;
    }
    for (var i = 0; i < _focusNodes.length; i++) {
      final index = i;
      _focusNodes[i].onKeyEvent =
          (node, event) => _handlePasteKey(index, node, event);
    }
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifyFocusChanged();
        _applyPendingFocus();
      });
    } else {
      _applyPendingFocus();
    }
  }

  void _applyPendingFocus() {
    final focusIndex = _pendingFocusIndex;
    if (focusIndex == null) return;
    if (focusIndex < 0 || focusIndex >= _focusNodes.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = _pendingFocusIndex;
      if (index == null || index < 0 || index >= _focusNodes.length) return;
      _pendingFocusIndex = null;
      _focusNodes[index].requestFocus();
    });
  }

  Future<void> _handleSubmitted(int index) async {
    if (widget.controllers[index].text.trim().isEmpty) return;
    final onSubmitRow = widget.onSubmitRow;
    if (onSubmitRow == null) return;

    _pendingFocusIndex = await onSubmitRow(index);
    if (!mounted) return;
    _applyPendingFocus();
  }

  void _notifyFocusChanged() {
    if (!mounted) return;
    final anyFocused = _focusNodes.any((node) => node.hasFocus);
    widget.onAnyFieldFocusChanged?.call(anyFocused);
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
    int index,
  ) {
    final buttonItems = editableTextState.contextMenuButtonItems.map((item) {
      if (item.type != ContextMenuButtonType.paste) return item;
      return ContextMenuButtonItem(
        onPressed: () {
          ContextMenuController.removeAny();
          unawaited(_handlePaste(index));
        },
        type: ContextMenuButtonType.paste,
      );
    }).toList();

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncFocusNodes();
    if (widget.controllers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.controllers.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controllers[index],
                  focusNode: _focusNodes[index],
                  style: subtaskTitleInputStyle(context),
                  decoration: subtaskTitleInputDecoration(context),
                  textInputAction: TextInputAction.next,
                  maxLines: 1,
                  inputFormatters: [_pasteFallbackFormatter(index)],
                  contextMenuBuilder: (context, editableTextState) =>
                      _buildContextMenu(context, editableTextState, index),
                  onSubmitted: (_) => _handleSubmitted(index),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => widget.onRemove(index),
                tooltip: '移除',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// 单行 [TextField] 粘贴时会把换行压成空格；在 formatter 层拦截并改读剪贴板。
class _SubtaskPasteFallbackFormatter extends TextInputFormatter {
  const _SubtaskPasteFallbackFormatter({
    required this.onMultilinePaste,
    required this.onRecoverCollapsedPaste,
  });

  final Future<void> Function() onMultilinePaste;
  final Future<void> Function(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) onRecoverCollapsedPaste;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.contains('\n') || newValue.text.contains('\r')) {
      unawaited(onMultilinePaste());
      return oldValue;
    }

    final insertedLen = newValue.text.length - oldValue.text.length;
    if (insertedLen > 1) {
      unawaited(onRecoverCollapsedPaste(oldValue, newValue));
    }

    return newValue;
  }
}

/// 持久态子任务只读列表（处理页父任务卡片常态使用）。
class SubtaskListSection extends StatelessWidget {
  const SubtaskListSection({
    super.key,
    required this.subtasks,
  });

  final List<Task> subtasks;

  @override
  Widget build(BuildContext context) {
    if (subtasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completedCount =
        subtasks.where((t) => t.status == TaskStatus.archived).length;
    final total = subtasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '子任务 $completedCount/$total 已完成',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...subtasks.map((sub) {
          final done = sub.status == TaskStatus.archived;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: done ? colorScheme.primary : colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sub.title,
                    style: done
                        ? theme.textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          )
                        : theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
