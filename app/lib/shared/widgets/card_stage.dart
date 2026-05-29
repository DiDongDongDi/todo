import 'package:flutter/material.dart';
import 'package:todo_app/shared/layout/app_layout.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';

/// Centers a [SwipeableCard] with shared max width/height constraints.
class CardStage extends StatelessWidget {
  const CardStage({
    super.key,
    required this.swipeKey,
    required this.child,
    this.enabled = true,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.leftLabel = '放弃',
    this.rightLabel = '完成',
  });

  final GlobalKey<SwipeableCardState> swipeKey;
  final Widget child;
  final bool enabled;
  final SwipeCallback? onSwipeLeft;
  final SwipeCallback? onSwipeRight;
  final SwipeCallback? onSwipeUp;
  final SwipeCallback? onSwipeDown;
  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    final cardHeight = AppLayout.cardMaxHeight(context);

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SizedBox(
            width: AppLayout.cardMaxWidth,
            height: cardHeight,
            child: SwipeableCard(
              key: swipeKey,
              enabled: enabled,
              onSwipeLeft: onSwipeLeft,
              onSwipeRight: onSwipeRight,
              onSwipeUp: onSwipeUp,
              onSwipeDown: onSwipeDown,
              leftLabel: leftLabel,
              rightLabel: rightLabel,
              child: SizedBox.expand(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
