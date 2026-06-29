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

String extractSubtaskInsertedText(
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

String collapseClipboardForPasteMatch(String raw) {
  return raw
      .replaceAll('\r\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool insertedMatchesCollapsedClipboard(String inserted, String clipboardRaw) {
  if (inserted.isEmpty) return false;
  final collapsed = collapseClipboardForPasteMatch(clipboardRaw);
  final normalizedInserted = inserted.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed == normalizedInserted;
}

bool _insertedContainsWhitespace(String inserted) {
  return inserted.contains(RegExp(r'\s'));
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
  final List<GlobalKey> _rowKeys = [];
  final List<_SubtaskPasteFallbackFormatter> _pasteFormatters = [];
  int? _pendingFocusIndex;
  bool _pasteHandling = false;
  bool _suppressFocusNotify = false;
  bool _awaitingSubmitFocus = false;
  int _trackedControllerCount = 0;

  @override
  void initState() {
    super.initState();
    _trackedControllerCount = widget.controllers.length;
    _syncFocusNodes();
  }

  @override
  void didUpdateWidget(SubtaskTitleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父级可能在 setState 中就地 mutate 同一 List，old/new widget 的 length 会相同。
    // 追加行的聚焦在 build() 里通过 _trackedControllerCount 检测。
    _syncFocusNodes();
  }

  void _maybeScheduleAppendFocus() {
    final oldCount = _trackedControllerCount;
    final newCount = widget.controllers.length;
    if (_pendingFocusIndex == null &&
        newCount == oldCount + 1 &&
        newCount > 0 &&
        widget.controllers.last.text.isEmpty) {
      _pendingFocusIndex = newCount - 1;
      _suppressFocusNotify = true;
      _awaitingSubmitFocus = true;
    }
    _trackedControllerCount = newCount;
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.removeListener(_notifyFocusChanged);
      node.dispose();
    }
    _focusNodes.clear();
    _rowKeys.clear();
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

  Future<void> _handlePaste(int index) async {
    if (_pasteHandling) return;
    if (!mounted) return;
    if (index < 0 || index >= widget.controllers.length) return;

    _pasteHandling = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text;
      if (raw == null || raw.isEmpty) return;

      await _importLinesFromClipboard(
        index,
        raw,
        widget.controllers[index].value,
      );
    } finally {
      _pasteHandling = false;
    }
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

  TextInputFormatter _pasteFallbackFormatter(int index) {
    return _pasteFormatters[index];
  }

  void _syncPasteFormatters() {
    while (_pasteFormatters.length < widget.controllers.length) {
      final index = _pasteFormatters.length;
      _pasteFormatters.add(
        _SubtaskPasteFallbackFormatter(
          onPossiblePaste: (oldValue, newValue) =>
              _tryRecoverMultilinePaste(index, oldValue, newValue),
        ),
      );
    }
    while (_pasteFormatters.length > widget.controllers.length) {
      _pasteFormatters.removeLast();
    }
  }

  Future<void> _tryRecoverMultilinePaste(
    int index,
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) async {
    if (_pasteHandling) return;
    if (!mounted) return;
    if (index < 0 || index >= widget.controllers.length) return;

    final insertedLen = newValue.text.length - oldValue.text.length;
    if (insertedLen < 2 &&
        !newValue.text.contains('\n') &&
        !newValue.text.contains('\r')) {
      return;
    }

    _pasteHandling = true;
    try {
      if (newValue.text.contains('\n') || newValue.text.contains('\r')) {
        await _importFromMultilineText(index, oldValue, newValue);
        return;
      }

      final inserted = extractSubtaskInsertedText(oldValue, newValue);
      if (!_insertedContainsWhitespace(inserted)) {
        if (mounted) widget.controllers[index].value = newValue;
        return;
      }

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text;
      if (raw == null || (!raw.contains('\n') && !raw.contains('\r'))) {
        if (mounted) widget.controllers[index].value = newValue;
        return;
      }

      if (!insertedMatchesCollapsedClipboard(inserted, raw)) {
        if (mounted) widget.controllers[index].value = newValue;
        return;
      }

      final lines = parseSubtaskBatchImport(raw);
      if (lines.length <= 1) {
        if (mounted) widget.controllers[index].value = newValue;
        return;
      }

      if (!mounted) return;
      widget.controllers[index].value = oldValue;
      await _importLinesFromClipboard(index, raw, oldValue);
    } finally {
      _pasteHandling = false;
    }
  }

  Future<void> _importLinesFromClipboard(
    int index,
    String raw,
    TextEditingValue baseValue,
  ) async {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (!normalized.contains('\n')) {
      _pasteSingleLine(index, normalized);
      return;
    }

    final oldText = baseValue.text;
    final start = baseValue.selection.start.clamp(0, oldText.length);
    final end = baseValue.selection.end.clamp(0, oldText.length);
    final before = oldText.substring(0, start);
    final after = oldText.substring(end);

    var lines = parseSubtaskBatchImport(normalized);
    if (lines.isEmpty) return;

    if (before.isNotEmpty || after.isNotEmpty) {
      lines = [before + lines.first, ...lines.skip(1)];
      if (after.isNotEmpty) {
        lines[lines.length - 1] = lines.last + after;
      }
    }

    if (lines.length == 1) {
      widget.controllers[index].text = lines.first;
      widget.controllers[index].selection =
          TextSelection.collapsed(offset: lines.first.length);
      return;
    }

    widget.onImportLines?.call(index, lines);
  }

  Future<void> _importFromMultilineText(
    int index,
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) async {
    if (!mounted) return;
    if (index < 0 || index >= widget.controllers.length) return;

    final inserted = extractSubtaskInsertedText(oldValue, newValue);
    final source =
        inserted.contains('\n') || inserted.contains('\r')
            ? inserted
            : newValue.text;

    var lines = parseSubtaskBatchImport(source);
    if (lines.isEmpty) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = data?.text;
      if (raw == null || raw.isEmpty) return;
      await _importLinesFromClipboard(index, raw, oldValue);
      return;
    }

    final oldText = oldValue.text;
    final start = oldValue.selection.start.clamp(0, oldText.length);
    final end = oldValue.selection.end.clamp(0, oldText.length);
    final before = oldText.substring(0, start);
    final after = oldText.substring(end);

    if (before.isNotEmpty || after.isNotEmpty) {
      lines = [before + lines.first, ...lines.skip(1)];
      if (after.isNotEmpty) {
        lines[lines.length - 1] = lines.last + after;
      }
    }

    if (lines.length == 1) {
      widget.controllers[index].text = lines.first;
      widget.controllers[index].selection =
          TextSelection.collapsed(offset: lines.first.length);
      return;
    }

    widget.controllers[index].value = oldValue;
    widget.onImportLines?.call(index, lines);
  }

  void _syncRowKeys() {
    while (_rowKeys.length < widget.controllers.length) {
      _rowKeys.add(GlobalKey());
    }
    while (_rowKeys.length > widget.controllers.length) {
      _rowKeys.removeLast();
    }
  }

  void _scrollRowIntoView(int index) {
    void doScroll() {
      if (!mounted) return;
      if (index < 0 || index >= _rowKeys.length) return;
      final rowContext = _rowKeys[index].currentContext;
      if (rowContext == null) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }

    Future<void> scrollAfterLayout() async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      doScroll();
      // 对齐 KeyboardLift 280ms 动画，键盘 inset 稳定后再滚一次。
      for (var i = 0; i < 18; i++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
      doScroll();
    }

    unawaited(scrollAfterLayout());
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

  void _clearSubmitFocusSuppression({int retries = 5}) {
    _suppressFocusNotify = false;
    if (_focusNodes.any((node) => node.hasFocus) || retries <= 0) {
      _awaitingSubmitFocus = false;
      _notifyFocusChanged();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _clearSubmitFocusSuppression(retries: retries - 1);
    });
  }

  void _applyPendingFocus() {
    final focusIndex = _pendingFocusIndex;
    if (focusIndex == null) return;
    if (focusIndex < 0 || focusIndex >= _focusNodes.length) {
      _clearSubmitFocusSuppression();
      return;
    }

    unawaited(_applyPendingFocusAfterLayout());
  }

  Future<void> _applyPendingFocusAfterLayout() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _suppressFocusNotify = false;
      _awaitingSubmitFocus = false;
      return;
    }
    final index = _pendingFocusIndex;
    if (index == null || index < 0 || index >= _focusNodes.length) {
      _clearSubmitFocusSuppression();
      return;
    }
    _pendingFocusIndex = null;
    _focusNodes[index].requestFocus();
    _scrollRowIntoView(index);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _clearSubmitFocusSuppression();
  }

  Future<void> _handleSubmitted(int index) async {
    if (widget.controllers[index].text.trim().isEmpty) return;
    final onSubmitRow = widget.onSubmitRow;
    if (onSubmitRow == null) return;

    _suppressFocusNotify = true;
    _awaitingSubmitFocus = true;
    try {
      _pendingFocusIndex = await onSubmitRow(index);
      if (!mounted) {
        _suppressFocusNotify = false;
        _awaitingSubmitFocus = false;
        return;
      }
      _applyPendingFocus();
    } catch (_) {
      _suppressFocusNotify = false;
      _awaitingSubmitFocus = false;
      rethrow;
    }
  }

  void _notifyFocusChanged() {
    if (!mounted || _suppressFocusNotify) return;
    final focusedIndex = _focusNodes.indexWhere((node) => node.hasFocus);
    final anyFocused = focusedIndex >= 0;
    if (_awaitingSubmitFocus && !anyFocused) return;
    if (anyFocused) {
      _awaitingSubmitFocus = false;
      _scrollRowIntoView(focusedIndex);
    }
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
    _maybeScheduleAppendFocus();
    _syncFocusNodes();
    _syncRowKeys();
    _syncPasteFormatters();
    if (widget.controllers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.controllers.length, (index) {
        return Padding(
          key: _rowKeys[index],
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
                  onSubmitted: (_) {
                    if (widget.controllers[index].text.trim().isNotEmpty &&
                        widget.onSubmitRow != null) {
                      _suppressFocusNotify = true;
                      _awaitingSubmitFocus = true;
                    }
                    unawaited(_handleSubmitted(index));
                  },
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

/// Android 单行输入框粘贴时会把换行压成空格；拦截批量插入后改读剪贴板拆分。
class _SubtaskPasteFallbackFormatter extends TextInputFormatter {
  const _SubtaskPasteFallbackFormatter({
    required this.onPossiblePaste,
  });

  final Future<void> Function(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) onPossiblePaste;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text == oldValue.text) return newValue;

    final hasNewlines =
        newValue.text.contains('\n') || newValue.text.contains('\r');
    final insertedLen = newValue.text.length - oldValue.text.length;
    if (insertedLen < 2 && !hasNewlines) {
      return newValue;
    }

    if (!hasNewlines) {
      final inserted = extractSubtaskInsertedText(oldValue, newValue);
      if (!_insertedContainsWhitespace(inserted)) {
        return newValue;
      }
    }

    unawaited(onPossiblePaste(oldValue, newValue));
    return oldValue;
  }
}

/// 持久态子任务只读列表（处理页父任务卡片常态使用）。
class SubtaskListSection extends StatelessWidget {
  const SubtaskListSection({
    super.key,
    required this.subtasks,
    this.onSubtaskTap,
  });

  final List<Task> subtasks;
  final void Function(Task subtask)? onSubtaskTap;

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
          final row = Row(
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
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: onSubtaskTap != null
                ? InkWell(
                    onTap: () => onSubtaskTap!(sub),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: row,
                    ),
                  )
                : row,
          );
        }),
      ],
    );
  }
}
