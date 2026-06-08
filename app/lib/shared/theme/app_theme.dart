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
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelPadding: const EdgeInsets.only(top: 4, bottom: 6),
        indicatorColor: colorScheme.primaryContainer,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: colorScheme.surfaceContainerHighest,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.35),
          fontSize: 24,
          fontWeight: FontWeight.w300,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 17, height: 1.5),
      ),
    );
  }
}
