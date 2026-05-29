import 'package:flutter/material.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';

class AppTheme {
  static ThemeData light() {
    const seed = Color(0xFF1565C0);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return _base(colorScheme, AppSemanticColors.light);
  }

  static ThemeData dark() {
    const seed = Color(0xFF42A5F5);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF1A1A1E),
    );
    return _base(colorScheme, AppSemanticColors.dark);
  }

  static ThemeData _base(ColorScheme colorScheme, AppSemanticColors semantic) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [semantic],
      scaffoldBackgroundColor: colorScheme.surface,
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: colorScheme.primaryContainer,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: colorScheme.surfaceContainerHighest,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.35),
          fontSize: 28,
          fontWeight: FontWeight.w300,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 18, height: 1.5),
      ),
    );
  }
}
