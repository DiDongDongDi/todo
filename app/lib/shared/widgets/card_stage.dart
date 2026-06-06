import 'package:flutter/material.dart';
import 'package:todo_app/shared/layout/app_layout.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';

/// Fills available space with a [SwipeableCard], keeping [AppLayout.cardPadding].
///
/// Must be placed inside an [Expanded] or other bounded-height parent.
class CardStage extends StatelessWidget {
  const CardStage({
    super.key,
    required this.swipeKey,
    required this.child,
    this.enabled = true,
    this.resetAfterAction = true,
    this.verticalEnterAnimation = false,
    this.shouldAnimateFlyout,
    this.onFlyoutFeedback,
    this.overlay,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onDragStart,
    this.onDragEnd,
    this.leftLabel = '放弃',
    this.rightLabel = '完成',
  });

  final GlobalKey<SwipeableCardState> swipeKey;
  final Widget child;
  final bool enabled;
  final bool resetAfterAction;
  final bool verticalEnterAnimation;
  final FlyoutGate? shouldAnimateFlyout;
  final FlyoutFeedback? onFlyoutFeedback;
  final Widget? overlay;
  final SwipeCallback? onSwipeLeft;
  final SwipeCallback? onSwipeRight;
  final SwipeCallback? onSwipeUp;
  final SwipeCallback? onSwipeDown;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppLayout.cardPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (overlay != null) overlay!,
                SwipeableCard(
                  key: swipeKey,
                  enabled: enabled,
                  resetAfterAction: resetAfterAction,
                  verticalEnterAnimation: verticalEnterAnimation,
                  shouldAnimateFlyout: shouldAnimateFlyout,
                  onFlyoutFeedback: onFlyoutFeedback,
                  onSwipeLeft: onSwipeLeft,
                  onSwipeRight: onSwipeRight,
                  onSwipeUp: onSwipeUp,
                  onSwipeDown: onSwipeDown,
                  onDragStart: onDragStart,
                  onDragEnd: onDragEnd,
                  leftLabel: leftLabel,
                  rightLabel: rightLabel,
                  child: child,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
