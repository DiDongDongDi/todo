import 'package:flutter/services.dart';

class AppHaptics {
  static Future<void> light() => HapticFeedback.lightImpact();

  static Future<void> medium() => HapticFeedback.mediumImpact();

  static Future<void> heavy() => HapticFeedback.heavyImpact();

  static Future<void> selection() => HapticFeedback.selectionClick();

  /// 占位回调，用于跳过 flyout 默认震动而保留业务侧反馈。
  static Future<void> none() async {}
}
