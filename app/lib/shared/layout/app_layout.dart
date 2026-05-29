import 'package:flutter/material.dart';

/// Shared layout constraints for a compact, centered card UI.
abstract final class AppLayout {
  static const double cardMaxWidth = 480;
  static const double contentMaxWidth = 520;
  static const double navBarMaxWidth = 320;

  static double cardMaxHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return (screenHeight * 0.48).clamp(280.0, 400.0);
  }
}
