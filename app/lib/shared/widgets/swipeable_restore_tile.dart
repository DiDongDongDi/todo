import 'package:flutter/material.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';
import 'package:todo_app/shared/utils/haptics.dart';

typedef RestoreCallback = Future<void> Function();

class SwipeableRestoreTile extends StatefulWidget {
  const SwipeableRestoreTile({
    super.key,
    required this.task,
    required this.onRestore,
    this.restoreIcon = Icons.undo,
    this.restoreTooltip = '恢复到收集箱',
  });

  final Task task;
  final RestoreCallback onRestore;
  final IconData restoreIcon;
  final String restoreTooltip;

  @override
  SwipeableRestoreTileState createState() => SwipeableRestoreTileState();
}

class SwipeableRestoreTileState extends State<SwipeableRestoreTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  Offset _drag = Offset.zero;
  Animation<Offset>? _dragAnimation;
  bool _animating = false;
  bool _pointerActive = false;
  double _pointerTravel = 0;

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

  double _bandOpacity(double drag) {
    return ((drag.abs() - 20) / _threshold).clamp(0.0, 0.55);
  }

  Size _tileSize() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.longestSide > 0) {
      return box.size;
    }
    return Size(MediaQuery.sizeOf(context).width, 72);
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

  Future<void> animateFlyout(
    Offset flyout,
    RestoreCallback action,
  ) async {
    if (_animating || !mounted) return;

    setState(() => _animating = true);
    await AppHaptics.medium();

    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final size = _tileSize();
    final target = Offset(flyout.dx * size.width, flyout.dy * size.height);
    await _animateDragTo(target, _flyoutDuration, Curves.easeIn);
    if (!mounted) return;

    await action();
    if (mounted) setState(() => _animating = false);
  }

  Future<void> restore({bool animated = true}) async {
    if (_animating) return;
    if (animated) {
      await animateFlyout(const Offset(-1.5, 0), widget.onRestore);
    } else {
      await widget.onRestore();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_animating) return;
    _pointerActive = true;
    _pointerTravel = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_animating || !_pointerActive) return;

    _pointerTravel += event.delta.distance;
    if (_pointerTravel < _dragDeadZone) return;

    setState(() {
      _drag = Offset(
        (_drag.dx + event.delta.dx).clamp(double.negativeInfinity, 0),
        0,
      );
    });
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    if (!_pointerActive) return;
    _pointerActive = false;
    _pointerTravel = 0;

    if (_animating) return;
    await _onDragEnd();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerActive = false;
    _pointerTravel = 0;
    if (_animating) return;
    setState(() => _drag = Offset.zero);
  }

  Future<void> _onDragEnd() async {
    if (_animating) return;

    if (_drag.dx < -_threshold) {
      await restore();
      return;
    }

    if (_drag != Offset.zero) {
      await _animateDragTo(Offset.zero, _resetDuration, Curves.easeOut);
    }
  }

  Widget _buildStack({
    required Offset offset,
    required Color successColor,
    required Widget tileChild,
  }) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (offset.dx < -20)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: successColor.withValues(
                  alpha: _bandOpacity(offset.dx),
                ),
                borderRadius: BorderRadius.circular(20),
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
                  '恢复',
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
            child: tileChild,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final successColor = context.semanticColors.success;
    final task = widget.task;

    final tileChild = Card(
      child: ListTile(
        title: Text(task.title),
        subtitle: task.note != null ? Text(task.note!) : null,
        trailing: IconButton(
          icon: Icon(widget.restoreIcon),
          tooltip: widget.restoreTooltip,
          onPressed: () => restore(),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = _dragAnimation != null
            ? AnimatedBuilder(
                animation: _dragAnimation!,
                builder: (context, child) {
                  return _buildStack(
                    offset: _dragAnimation!.value,
                    successColor: successColor,
                    tileChild: child!,
                  );
                },
                child: tileChild,
              )
            : _buildStack(
                offset: _drag,
                successColor: successColor,
                tileChild: tileChild,
              );

        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: ClipRect(
            child: SizedBox(
              width: constraints.maxWidth,
              child: stack,
            ),
          ),
        );
      },
    );
  }
}
