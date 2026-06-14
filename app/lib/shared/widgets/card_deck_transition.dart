import 'dart:async';

import 'package:flutter/material.dart';
import 'package:todo_app/shared/layout/app_layout.dart';

enum CardDeckTransitionMode { delete, undoRestore }

/// Dual-card transition for delete (top shrink out + bottom slide up) and undo
/// (top slide down + bottom scale in).
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

  static const duration = Duration(milliseconds: 280);

  @override
  State<CardDeckTransition> createState() => _CardDeckTransitionState();
}

class _CardDeckTransitionState extends State<CardDeckTransition>
    with SingleTickerProviderStateMixin {
  static const _cardBorderRadius = 20.0;

  late final AnimationController _controller;
  late final Animation<double> _topScale;
  late final Animation<double> _topFade;
  late final Animation<Offset> _topSlide;
  late final Animation<double> _bottomScale;
  late final Animation<double> _bottomFade;
  late final Animation<Offset> _bottomSlide;
  late final Animation<double> _topOverlayScrim;
  late final Animation<double> _topOverlayLabel;
  late final Animation<double> _emptyPlaceholderFade;

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
            curve: const Interval(0, 0.7, curve: Curves.easeIn),
          ),
        );
        _topFade = Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.7, curve: Curves.easeIn),
          ),
        );
        _topSlide = const AlwaysStoppedAnimation(Offset.zero);
        _bottomScale = const AlwaysStoppedAnimation(1);
        _bottomFade = const AlwaysStoppedAnimation(1);
        _bottomSlide = Tween<Offset>(
          begin: const Offset(0, 1.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.12, 1, curve: Curves.easeOut),
          ),
        );
        _topOverlayScrim = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.15, end: 0.35),
            weight: 40,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.35, end: 0),
            weight: 60,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.7, curve: Curves.easeIn),
          ),
        );
        _topOverlayLabel = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: 1),
            weight: 35,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1, end: 0),
            weight: 35,
          ),
          TweenSequenceItem(
            tween: ConstantTween<double>(0),
            weight: 30,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.7, curve: Curves.easeOut),
          ),
        );
        _emptyPlaceholderFade = Tween<double>(begin: 0, end: 0.45).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.45, 1, curve: Curves.easeOut),
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
        _topOverlayScrim = AlwaysStoppedAnimation(0);
        _topOverlayLabel = AlwaysStoppedAnimation(0);
        _emptyPlaceholderFade = AlwaysStoppedAnimation(0);
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

  Widget _buildDeleteOverlay(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scrimAlpha = _topOverlayScrim.value;
        final labelAlpha = _topOverlayLabel.value;
        if (scrimAlpha <= 0 && labelAlpha <= 0) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (scrimAlpha > 0)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: errorColor.withValues(alpha: scrimAlpha),
                    borderRadius: BorderRadius.circular(_cardBorderRadius),
                  ),
                ),
              if (labelAlpha > 0)
                Opacity(
                  opacity: labelAlpha,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 40,
                          color: errorColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '删除',
                          style: TextStyle(
                            color: errorColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlaceholder(BuildContext context) {
    return FadeTransition(
      opacity: _emptyPlaceholderFade,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(_cardBorderRadius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDelete = widget.mode == CardDeckTransitionMode.delete;

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
                  if (isDelete && widget.bottomChild == null)
                    _buildEmptyPlaceholder(context),
                  if (widget.bottomChild != null)
                    _wrapChild(
                      sizedChild(widget.bottomChild),
                      scale: _bottomScale,
                      fade: _bottomFade,
                      slide: _bottomSlide,
                    ),
                  if (widget.topChild != null)
                    _wrapChild(
                      sizedChild(
                        Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.topChild!,
                            if (isDelete) _buildDeleteOverlay(context),
                          ],
                        ),
                      ),
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
