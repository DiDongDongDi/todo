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
    return Padding(
      padding: AppLayout.cardPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: SwipeableCard(
              key: swipeKey,
              enabled: enabled,
              onSwipeLeft: onSwipeLeft,
              onSwipeRight: onSwipeRight,
              onSwipeUp: onSwipeUp,
              onSwipeDown: onSwipeDown,
              leftLabel: leftLabel,
              rightLabel: rightLabel,
              child: child,
            ),
          );
        },
      ),
    );
  }
}
