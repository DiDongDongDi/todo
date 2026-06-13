import 'dart:async';

import 'package:flutter/material.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/widgets/haptic_tap_scope.dart';

enum ProcessMoreAction {
  askAi,
  createPlaylist,
  someday,
  archive,
  trash,
  sync,
  saveTemplate,
  delete,
}

enum CollectMoreAction {
  saveTemplate,
  createFromTemplate,
  batchImport,
}

class TabMoreMenuEntry<T> {
  const TabMoreMenuEntry.item({
    required this.value,
    required this.icon,
    required this.label,
  }) : isDivider = false;

  const TabMoreMenuEntry.divider()
      : value = null,
        icon = null,
        label = null,
        isDivider = true;

  final T? value;
  final IconData? icon;
  final String? label;
  final bool isDivider;
}

class TabMoreMenuButton<T> extends StatefulWidget {
  const TabMoreMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
  });

  final List<TabMoreMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  State<TabMoreMenuButton<T>> createState() => _TabMoreMenuButtonState<T>();
}

class _TabMoreMenuButtonState<T> extends State<TabMoreMenuButton<T>>
    with SingleTickerProviderStateMixin {
  final _anchorKey = GlobalKey();
  OverlayEntry? _entry;
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _slideY;

  static const _openDuration = Duration(milliseconds: 220);
  static const _closeDuration = Duration(milliseconds: 160);
  static const _menuMinWidth = 200.0;
  static const _menuGap = 4.0;
  static const _menuRadius = 16.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _openDuration);
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _slideY = Tween<double>(begin: -6, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _removeEntry(immediate: true);
    _controller.dispose();
    super.dispose();
  }

  void _removeEntry({bool immediate = false}) {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    if (immediate) {
      entry.remove();
      return;
    }
    _controller.duration = _closeDuration;
    _controller.reverse().whenComplete(() {
      if (!mounted) {
        entry.remove();
        return;
      }
      entry.remove();
    });
  }

  void _openMenu() {
    if (_entry != null) {
      _removeEntry();
      return;
    }

    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null) return;

    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final anchor = renderBox.localToGlobal(Offset.zero);
    final anchorSize = renderBox.size;
    final screenSize = MediaQuery.sizeOf(context);

    unawaited(AppHaptics.selection());

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeEntry,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: anchor.dy + anchorSize.height + _menuGap,
              left: (anchor.dx + anchorSize.width - _menuMinWidth)
                  .clamp(8.0, screenSize.width - _menuMinWidth - 8),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideY.value),
                      child: Transform.scale(
                        scale: _scale.value,
                        alignment: Alignment.topRight,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Material(
                  elevation: 3,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_menuRadius),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: _menuMinWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in widget.items)
                            if (item.isDivider)
                              Divider(
                                height: 1,
                                indent: 12,
                                endIndent: 12,
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              )
                            else
                              _TabMoreMenuRow(
                                icon: item.icon!,
                                label: item.label!,
                                onTap: () {
                                  _removeEntry();
                                  widget.onSelected(item.value as T);
                                },
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);
    _controller.duration = _openDuration;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return SuppressTapHaptic(
      child: IconButton(
        key: _anchorKey,
        icon: const Icon(Icons.more_vert),
        tooltip: '更多',
        onPressed: _openMenu,
      ),
    );
  }
}

class _TabMoreMenuRow extends StatelessWidget {
  const _TabMoreMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: colorScheme.surfaceContainerHigh,
        splashColor: colorScheme.surfaceContainerHigh,
        highlightColor: colorScheme.surfaceContainerHigh,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
