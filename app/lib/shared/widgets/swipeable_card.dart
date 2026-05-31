import 'package:flutter/material.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';
import 'package:todo_app/shared/utils/haptics.dart';

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
  SwipeableCardState createState() => SwipeableCardState();
}

class SwipeableCardState extends State<SwipeableCard> {
  Offset _drag = Offset.zero;
  bool _animating = false;

  static const _threshold = 80.0;
  static const _flyoutDuration = Duration(milliseconds: 220);

  double _bandOpacity(double drag, double threshold) {
    return ((drag.abs() - 20) / threshold).clamp(0.0, 0.55);
  }

  Future<void> animateFlyout(Offset flyout, SwipeCallback action) async {
    if (_animating || !mounted) return;

    setState(() => _animating = true);
    await AppHaptics.medium();

    if (!mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final box = context.findRenderObject() as RenderBox?;
    final size = box != null && box.hasSize && box.size.longestSide > 0
        ? box.size
        : MediaQuery.sizeOf(context);

    setState(() {
      _drag = Offset(flyout.dx * size.width, flyout.dy * size.height);
    });

    await Future<void>.delayed(_flyoutDuration);
    await action();
    if (mounted) {
      setState(() {
        _drag = Offset.zero;
        _animating = false;
      });
    }
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

    await animateFlyout(flyout, action);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = context.semanticColors.success;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          onPanUpdate: widget.enabled
              ? (d) => setState(() => _drag += d.delta)
              : null,
          onPanEnd: widget.enabled ? _onDragEnd : null,
          child: ClipRect(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
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
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: widget.child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
