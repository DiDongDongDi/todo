import 'package:flutter/material.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';
import 'package:todo_app/shared/utils/haptics.dart';

enum SwipeDirection { left, right, up, down }

typedef SwipeCallback = Future<void> Function();

class SwipeableCard extends StatefulWidget {
  const SwipeableCard({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.enabled = true,
    this.leftLabel = '放弃',
    this.rightLabel = '完成',
    this.upLabel,
    this.downLabel,
  });

  final Widget child;
  final SwipeCallback? onSwipeLeft;
  final SwipeCallback? onSwipeRight;
  final SwipeCallback? onSwipeUp;
  final SwipeCallback? onSwipeDown;
  final bool enabled;
  final String leftLabel;
  final String rightLabel;
  final String? upLabel;
  final String? downLabel;

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> {
  Offset _drag = Offset.zero;
  bool _animating = false;

  static const _threshold = 80.0;

  double _bandOpacity(double drag, double threshold) {
    return ((drag.abs() - 20) / threshold).clamp(0.0, 0.55);
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (!widget.enabled || _animating) return;

    final dx = _drag.dx;
    final dy = _drag.dy;
    SwipeCallback? action;
    Offset flyout = Offset.zero;

    if (dx.abs() > dy.abs()) {
      if (dx > _threshold && widget.onSwipeRight != null) {
        action = widget.onSwipeRight;
        flyout = const Offset(1.5, 0);
      } else if (dx < -_threshold && widget.onSwipeLeft != null) {
        action = widget.onSwipeLeft;
        flyout = const Offset(-1.5, 0);
      }
    } else {
      if (dy < -_threshold && widget.onSwipeUp != null) {
        action = widget.onSwipeUp;
        flyout = const Offset(0, -1.5);
      } else if (dy > _threshold && widget.onSwipeDown != null) {
        action = widget.onSwipeDown;
        flyout = const Offset(0, 1.5);
      }
    }

    if (action == null) {
      setState(() => _drag = Offset.zero);
      return;
    }

    setState(() => _animating = true);
    await AppHaptics.medium();

    final size = context.size ?? Size.zero;
    setState(() {
      _drag = Offset(flyout.dx * size.width, flyout.dy * size.height);
    });

    await Future<void>.delayed(const Duration(milliseconds: 220));
    await action();
    if (mounted) {
      setState(() {
        _drag = Offset.zero;
        _animating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = context.semanticColors.success;

    return GestureDetector(
      onPanUpdate: widget.enabled
          ? (d) => setState(() => _drag += d.delta)
          : null,
      onPanEnd: widget.enabled ? _onDragEnd : null,
      child: Stack(
        children: [
          if (_drag.dx < -20)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(
                    alpha: _bandOpacity(_drag.dx, _threshold),
                  ),
                ),
              ),
            ),
          if (_drag.dx > 20)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: successColor.withValues(
                    alpha: _bandOpacity(_drag.dx, _threshold),
                  ),
                ),
              ),
            ),
          if (_drag.dx < -20)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    widget.leftLabel,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          if (_drag.dx > 20)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: Text(
                    widget.rightLabel,
                    style: TextStyle(
                      color: successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: _drag,
            child: Transform.rotate(
              angle: _drag.dx * 0.0008,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
