import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Shell 底部导航占用的高度（含安全区），用于计算卡片内控件需额外上移多少。
double shellBottomObstruction(BuildContext context) {
  final navHeight =
      NavigationBarTheme.of(context).height ?? kBottomNavigationBarHeight;
  return navHeight + MediaQuery.paddingOf(context).bottom;
}

/// 随键盘平滑上移 [child]，不改变父级布局尺寸（避免 expands TextField 逐帧重排）。
class KeyboardLift extends StatefulWidget {
  const KeyboardLift({
    super.key,
    required this.child,
    this.bottomObstruction = 0,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;

  /// 屏幕底部已有固定 UI（如底栏）占用的键盘 inset 部分。
  final double bottomObstruction;

  final Duration duration;
  final Curve curve;

  @override
  State<KeyboardLift> createState() => _KeyboardLiftState();
}

class _KeyboardLiftState extends State<KeyboardLift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _lift = 0;
  double _fromLift = 0;
  double _toLift = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addListener(_onTick);
  }

  void _onTick() {
    final t = widget.curve.transform(_controller.value);
    setState(() {
      _lift = lerpDouble(_fromLift, _toLift, t)!;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncToInsets();
  }

  @override
  void didUpdateWidget(KeyboardLift oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    _syncToInsets();
  }

  void _syncToInsets() {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final target =
        (inset - widget.bottomObstruction).clamp(0.0, double.infinity);
    // 目标未变时不重启动画，避免父级 setState 在键盘过渡期间造成底部栏弹跳。
    if ((target - _toLift).abs() < 0.5) {
      return;
    }
    _fromLift = _lift;
    _toLift = target;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -_lift),
      child: widget.child,
    );
  }
}
