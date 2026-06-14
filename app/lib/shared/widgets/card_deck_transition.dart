import 'dart:async';

import 'package:flutter/material.dart';
import 'package:todo_app/shared/layout/app_layout.dart';

enum CardDeckTransitionMode { delete, undoRestore }

/// Dual-card transition for delete (scale out + slide up) and undo (slide down + scale in).
class CardDeckTransition extends StatefulWidget {
  const CardDeckTransition({
    super.key,
    required this.mode,
    required this.topChild,
    this.bottomChild,
    required this.onComplete,
    this.autoStart = true,
  });

  final CardDeckTransitionMode mode;
  final Widget? topChild;
  final Widget? bottomChild;
  final VoidCallback onComplete;
  final bool autoStart;

  static const duration = Duration(milliseconds: 220);

  @override
  State<CardDeckTransition> createState() => _CardDeckTransitionState();
}

class _CardDeckTransitionState extends State<CardDeckTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _topScale;
  late final Animation<double> _topFade;
  late final Animation<Offset> _topSlide;
  late final Animation<double> _bottomScale;
  late final Animation<double> _bottomFade;
  late final Animation<Offset> _bottomSlide;

  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CardDeckTransition.duration,
    );

    switch (widget.mode) {
      case CardDeckTransitionMode.delete:
        _topScale = Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 1, curve: Curves.easeIn),
          ),
        );
        _topFade = Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.85, curve: Curves.easeIn),
          ),
        );
        _topSlide = AlwaysStoppedAnimation(Offset.zero);
        _bottomScale = AlwaysStoppedAnimation(1);
        _bottomFade = AlwaysStoppedAnimation(1);
        _bottomSlide = Tween<Offset>(
          begin: const Offset(0, 1.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 1, curve: Curves.easeOut),
          ),
        );
      case CardDeckTransitionMode.undoRestore:
        _topScale = AlwaysStoppedAnimation(1);
        _topFade = AlwaysStoppedAnimation(1);
        _topSlide = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, 1.2),
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 1, curve: Curves.easeIn),
          ),
        );
        _bottomScale = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 1, curve: Curves.easeOut),
          ),
        );
        _bottomFade = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.85, curve: Curves.easeOut),
          ),
        );
        _bottomSlide = AlwaysStoppedAnimation(Offset.zero);
    }

    _controller.addStatusListener(_onStatus);

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_controller.forward());
      });
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completed) return;
    _completed = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  Widget _wrapChild(
    Widget child, {
    required Animation<double> scale,
    required Animation<double> fade,
    required Animation<Offset> slide,
  }) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(
          scale: scale,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppLayout.cardPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget sizedChild(Widget? child) => child == null
              ? const SizedBox.shrink()
              : SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: child,
                );

          return ClipRect(
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  if (widget.bottomChild != null)
                    _wrapChild(
                      sizedChild(widget.bottomChild),
                      scale: _bottomScale,
                      fade: _bottomFade,
                      slide: _bottomSlide,
                    ),
                  if (widget.topChild != null)
                    _wrapChild(
                      sizedChild(widget.topChild),
                      scale: _topScale,
                      fade: _topFade,
                      slide: _topSlide,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
