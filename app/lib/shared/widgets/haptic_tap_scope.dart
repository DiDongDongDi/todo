import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:todo_app/shared/utils/haptics.dart';

/// 在应用根部包裹，为所有短按（点击）触发轻量震动反馈。
class HapticTapScope extends StatefulWidget {
  const HapticTapScope({super.key, required this.child});

  final Widget child;

  @override
  State<HapticTapScope> createState() => _HapticTapScopeState();
}

class _HapticTapScopeState extends State<HapticTapScope> {
  final Map<int, Offset> _downPositions = {};

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.buttons != kPrimaryButton) return;
        _downPositions[event.pointer] = event.position;
      },
      onPointerUp: (event) {
        final down = _downPositions.remove(event.pointer);
        if (down == null) return;
        if ((event.position - down).distance <= kTouchSlop) {
          AppHaptics.light();
        }
      },
      onPointerCancel: (event) {
        _downPositions.remove(event.pointer);
      },
      child: widget.child,
    );
  }
}
