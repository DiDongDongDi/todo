import 'package:flutter/material.dart';
import 'package:todo_app/shared/layout/app_layout.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';

/// Centers a [SwipeableCard] with shared max width/height constraints.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : AppLayout.cardMaxWidth;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : AppLayout.cardMaxHeight(context);

        final cardWidth = AppLayout.cardMaxWidth.clamp(280.0, maxW).toDouble();
        final cardHeight = maxH.clamp(240.0, AppLayout.cardMaxHeight(context)).toDouble();

        return Center(
          child: SizedBox(
            width: cardWidth,
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
              child: child,
            ),
          ),
        );
      },
    );
  }
}
