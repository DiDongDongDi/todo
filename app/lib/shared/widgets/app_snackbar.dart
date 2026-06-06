import 'package:flutter/material.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';

enum AppSnackType { info, success, warning, error }

void showAppSnackBar(
  BuildContext context, {
  required String message,
  required IconData icon,
  AppSnackType type = AppSnackType.info,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final semantic = context.semanticColors;

  final (Color bg, Color fg) = switch (type) {
    AppSnackType.success => (semantic.successContainer, semantic.onSuccessContainer),
    AppSnackType.error => (colorScheme.errorContainer, colorScheme.onErrorContainer),
    AppSnackType.warning => (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
    AppSnackType.info => (colorScheme.inverseSurface, colorScheme.onInverseSurface),
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: messenger.hideCurrentSnackBar,
        child: Row(
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: bg,
      duration: duration,
      action: action != null
          ? SnackBarAction(
              label: action.label,
              onPressed: action.onPressed,
              textColor: fg,
            )
          : null,
    ),
  );
}
