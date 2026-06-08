import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:todo_app/shared/utils/haptics.dart';

/// 供 [SuppressTapHaptic] 调用的点击震动抑制接口。
abstract class HapticTapScopeController {
  void suppressPointer(int pointer);
  void unsuppressPointer(int pointer);
}

/// 在应用根部包裹，为所有短按（点击）触发轻量震动反馈。
class HapticTapScope extends StatefulWidget {
  const HapticTapScope({super.key, required this.child});

  final Widget child;

  static HapticTapScopeController? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_HapticTapScopeState>();
  }

  @override
  State<HapticTapScope> createState() => _HapticTapScopeState();
}

class _HapticTapScopeState extends State<HapticTapScope>
    implements HapticTapScopeController {
  final Map<int, Offset> _downPositions = {};
  final Set<int> _suppressedPointers = {};

  @override
  void suppressPointer(int pointer) => _suppressedPointers.add(pointer);

  @override
  void unsuppressPointer(int pointer) => _suppressedPointers.remove(pointer);

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
        final suppressed = _suppressedPointers.remove(event.pointer);
        if (down == null) return;
        if (suppressed) return;
        if ((event.position - down).distance <= kTouchSlop) {
          AppHaptics.light();
        }
      },
      onPointerCancel: (event) {
        _downPositions.remove(event.pointer);
        _suppressedPointers.remove(event.pointer);
      },
      child: widget.child,
    );
  }
}

/// 包裹在有自有震动反馈的可点击区域，跳过 [HapticTapScope] 的全局点击震动。
class SuppressTapHaptic extends StatelessWidget {
  const SuppressTapHaptic({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        HapticTapScope.maybeOf(context)?.suppressPointer(event.pointer);
      },
      child: child,
    );
  }
}
