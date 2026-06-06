import 'package:flutter/material.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';
import 'package:todo_app/shared/utils/haptics.dart';

typedef SwipeCallback = Future<void> Function();
typedef FlyoutFeedback = Future<void> Function();
typedef FlyoutGate = Future<bool> Function(Offset flyout);

class SwipeableCard extends StatefulWidget {
  const SwipeableCard({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onDragStart,
    this.onDragEnd,
    this.enabled = true,
    this.resetAfterAction = true,
    this.verticalEnterAnimation = false,
    this.shouldAnimateFlyout,
    this.onFlyoutFeedback,
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
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final bool enabled;
  final bool resetAfterAction;
  /// After a vertical flyout, slide the next card in from top/bottom (collect-style).
  final bool verticalEnterAnimation;
  final FlyoutGate? shouldAnimateFlyout;
  final FlyoutFeedback? onFlyoutFeedback;
  final String leftLabel;
  final String rightLabel;
  final String? upLabel;
  final String? downLabel;

  @override
  SwipeableCardState createState() => SwipeableCardState();
}

class SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  Offset _drag = Offset.zero;
  Animation<Offset>? _dragAnimation;
  bool _animating = false;
  bool _pointerActive = false;
  double _pointerTravel = 0;
  bool _dragStarted = false;

  static const _threshold = 80.0;
  static const _dragDeadZone = 8.0;
  static const _flyoutDuration = Duration(milliseconds: 180);
  static const _resetDuration = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  double _bandOpacity(double drag, double threshold) {
    return ((drag.abs() - 20) / threshold).clamp(0.0, 0.55);
  }

  /// Locks drag to directions that have registered swipe callbacks.
  Offset _constrainDrag(Offset drag) {
    var dx = drag.dx;
    var dy = drag.dy;

    final allowHorizontal =
        widget.onSwipeLeft != null || widget.onSwipeRight != null;
    final allowVertical =
        widget.onSwipeUp != null || widget.onSwipeDown != null;

    if (!allowHorizontal) {
      dx = 0;
    } else {
      if (widget.onSwipeLeft == null) {
        dx = dx.clamp(0, double.infinity);
      }
      if (widget.onSwipeRight == null) {
        dx = dx.clamp(double.negativeInfinity, 0);
      }
    }

    if (!allowVertical) {
      dy = 0;
    } else {
      if (widget.onSwipeUp == null) {
        dy = dy.clamp(0, double.infinity);
      }
      if (widget.onSwipeDown == null) {
        dy = dy.clamp(double.negativeInfinity, 0);
      }
    }

    return Offset(dx, dy);
  }

  Future<void> animateFlyout(
    Offset flyout,
    SwipeCallback action, {
    bool? resetAfter,
    FlyoutFeedback? feedback,
  }) async {
    if (_animating || !mounted) return;

    setState(() => _animating = true);
    final flyoutFeedback = feedback ?? widget.onFlyoutFeedback;
    if (flyoutFeedback != null) {
      await flyoutFeedback();
    } else {
      await AppHaptics.medium();
    }

    if (!mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final size = _cardSize();
    final target = Offset(
      flyout.dx * size.width,
      flyout.dy * size.height,
    );
    await _animateDragTo(target, _flyoutDuration, Curves.easeIn);
    if (!mounted) return;

    await action();
    if (!mounted) return;

    final shouldReset = resetAfter ?? widget.resetAfterAction;
    if (shouldReset) {
      if (widget.verticalEnterAnimation && flyout.dy != 0) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await resetPosition(
          enterFromBottom: flyout.dy < 0,
          enterFromTop: flyout.dy > 0,
        );
      } else {
        await resetPosition();
      }
    } else if (mounted) {
      setState(() => _animating = false);
    }
  }

  Size _cardSize() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.longestSide > 0) {
      return box.size;
    }
    return MediaQuery.sizeOf(context);
  }

  Future<void> _animateDragTo(
    Offset target,
    Duration duration,
    Curve curve,
  ) async {
    final begin = _drag;
    _motionController.duration = duration;
    _dragAnimation = Tween<Offset>(begin: begin, end: target).animate(
      CurvedAnimation(parent: _motionController, curve: curve),
    );
    setState(() {});

    _motionController.stop();
    _motionController.reset();
    await _motionController.forward();

    if (!mounted) return;
    setState(() {
      _drag = target;
      _dragAnimation = null;
    });
  }

  Future<void> resetPosition({
    bool animated = true,
    bool enterFromBottom = false,
    bool enterFromTop = false,
  }) async {
    if (!mounted) return;

    if (enterFromBottom && animated) {
      final height = _cardSize().height;
      setState(() => _drag = Offset(0, height * 1.2));
      await _animateDragTo(Offset.zero, _resetDuration, Curves.easeOut);
      if (mounted) setState(() => _animating = false);
      return;
    }

    if (enterFromTop && animated) {
      final height = _cardSize().height;
      setState(() => _drag = Offset(0, -height * 1.2));
      await _animateDragTo(Offset.zero, _resetDuration, Curves.easeOut);
      if (mounted) setState(() => _animating = false);
      return;
    }

    if (_drag == Offset.zero) {
      setState(() => _animating = false);
      return;
    }

    if (animated) {
      await _animateDragTo(Offset.zero, _resetDuration, Curves.easeOut);
    } else {
      setState(() => _drag = Offset.zero);
    }

    if (mounted) setState(() => _animating = false);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || _animating) return;
    _pointerActive = true;
    _pointerTravel = 0;
    _dragStarted = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.enabled || _animating || !_pointerActive) return;

    _pointerTravel += event.delta.distance;
    if (_pointerTravel < _dragDeadZone) return;

    if (!_dragStarted) {
      _dragStarted = true;
      widget.onDragStart?.call();
    }

    setState(() => _drag = _constrainDrag(_drag + event.delta));
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    if (!_pointerActive) return;
    _pointerActive = false;
    _pointerTravel = 0;
    _dragStarted = false;

    if (!widget.enabled || _animating) return;
    await _onDragEnd();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    final hadDrag = _dragStarted;
    _pointerActive = false;
    _pointerTravel = 0;
    _dragStarted = false;
    if (!widget.enabled || _animating) return;
    setState(() => _drag = Offset.zero);
    if (hadDrag) widget.onDragEnd?.call();
  }

  Future<void> _onDragEnd() async {
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
      widget.onDragEnd?.call();
      return;
    }

    if (widget.shouldAnimateFlyout != null &&
        !await widget.shouldAnimateFlyout!(flyout)) {
      setState(() => _drag = Offset.zero);
      await action();
      return;
    }

    await animateFlyout(flyout, action);
  }

  Widget _buildCardStack({
    required double width,
    required double height,
    required Offset offset,
    required ColorScheme colorScheme,
    required Color successColor,
    required Widget cardChild,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        if (offset.dx < -20)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(
                  alpha: _bandOpacity(offset.dx, _threshold),
                ),
              ),
            ),
          ),
        if (offset.dx > 20)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: successColor.withValues(
                  alpha: _bandOpacity(offset.dx, _threshold),
                ),
              ),
            ),
          ),
        if (offset.dx < -20)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 32),
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
        if (offset.dx > 20)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 32),
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
          offset: offset,
          child: Transform.rotate(
            angle: offset.dx * 0.0008,
            child: cardChild,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = context.semanticColors.success;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final cardChild = RepaintBoundary(
          child: SizedBox(
            width: width,
            height: height,
            child: widget.child,
          ),
        );

        final stack = _dragAnimation != null
            ? AnimatedBuilder(
                animation: _dragAnimation!,
                builder: (context, child) {
                  return _buildCardStack(
                    width: width,
                    height: height,
                    offset: _dragAnimation!.value,
                    colorScheme: colorScheme,
                    successColor: successColor,
                    cardChild: child!,
                  );
                },
                child: cardChild,
              )
            : _buildCardStack(
                width: width,
                height: height,
                offset: _drag,
                colorScheme: colorScheme,
                successColor: successColor,
                cardChild: cardChild,
              );

        return Listener(
          onPointerDown: widget.enabled ? _onPointerDown : null,
          onPointerMove: widget.enabled ? _onPointerMove : null,
          onPointerUp: widget.enabled ? _onPointerUp : null,
          onPointerCancel: widget.enabled ? _onPointerCancel : null,
          child: ClipRect(
            child: SizedBox(
              width: width,
              height: height,
              child: stack,
            ),
          ),
        );
      },
    );
  }
}
