import 'package:flutter/material.dart';

/// Shared layout constraints for the card-first shell UI.
abstract final class AppLayout {
  static const double contentMaxWidth = 520;

  /// Insets around the big task card: edges of the screen and gap above the tab bar.
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(20, 16, 20, 12);
}
