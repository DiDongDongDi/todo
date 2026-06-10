import 'dart:async';

import 'package:flutter/material.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';
import 'package:todo_app/shared/widgets/haptic_tap_scope.dart';

enum AppSnackType { info, success, warning, error }

const double _kAppSnackBarHeight = 52;

OverlayEntry? _activeBanner;
Timer? _activeBannerTimer;

void _hideActiveBanner() {
  _activeBannerTimer?.cancel();
  _activeBannerTimer = null;
  _activeBanner?.remove();
  _activeBanner = null;
}

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
    AppSnackType.success =>
      (semantic.successContainer, semantic.onSuccessContainer),
    AppSnackType.error =>
      (colorScheme.errorContainer, colorScheme.onErrorContainer),
    AppSnackType.warning =>
      (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
    AppSnackType.info =>
      (colorScheme.inverseSurface, colorScheme.onInverseSurface),
  };

  _hideActiveBanner();

  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final topInset = MediaQuery.of(ctx).padding.top;
      return Positioned(
        top: topInset + 8,
        left: 16,
        right: 16,
        child: Material(
          elevation: 4,
          color: bg,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: _kAppSnackBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _hideActiveBanner,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(icon, color: fg, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              message,
                              overflow: TextOverflow.clip,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: fg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (action != null)
                    SuppressTapHaptic(
                      child: TextButton(
                        onPressed: () {
                          _hideActiveBanner();
                          action.onPressed();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          visualDensity: VisualDensity.compact,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          fixedSize: const Size(48, _kAppSnackBarHeight),
                        ),
                        child: Text(action.label),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  _activeBanner = entry;
  overlay.insert(entry);
  _activeBannerTimer = Timer(duration, _hideActiveBanner);
}
