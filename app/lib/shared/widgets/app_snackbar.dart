import 'package:flutter/material.dart';
import 'package:todo_app/shared/layout/app_layout.dart';
import 'package:todo_app/shared/theme/app_semantic_colors.dart';

enum AppSnackType { info, success, warning, error }

enum AppSnackPosition { top, bottom }

OverlayEntry? _activeTopSnackEntry;

void showAppSnackBar(
  BuildContext context, {
  required String message,
  required IconData icon,
  AppSnackType type = AppSnackType.info,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
  AppSnackPosition position = AppSnackPosition.bottom,
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

  if (position == AppSnackPosition.top) {
    _showFloatingPillNotice(
      context,
      message: message,
      icon: icon,
      type: type,
      duration: duration,
    );
    return;
  }

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
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

double _pillBottomInset(BuildContext context) {
  final viewPadding = MediaQuery.viewPaddingOf(context);
  final navHeight =
      NavigationBarTheme.of(context).height ?? kBottomNavigationBarHeight;
  return viewPadding.bottom + navHeight + AppLayout.cardPadding.bottom + 8;
}

void _showFloatingPillNotice(
  BuildContext context, {
  required String message,
  required IconData icon,
  required AppSnackType type,
  required Duration duration,
}) {
  _activeTopSnackEntry?.remove();
  _activeTopSnackEntry = null;

  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      return Positioned(
        bottom: _pillBottomInset(overlayContext),
        left: AppLayout.cardPadding.left,
        right: AppLayout.cardPadding.right,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _AppPillNotice(
            message: message,
            icon: icon,
            type: type,
            duration: duration,
            onDismiss: () {
              entry.remove();
              if (_activeTopSnackEntry == entry) {
                _activeTopSnackEntry = null;
              }
            },
          ),
        ),
      );
    },
  );

  _activeTopSnackEntry = entry;
  overlay.insert(entry);
}

class _AppPillNotice extends StatefulWidget {
  const _AppPillNotice({
    required this.message,
    required this.icon,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final IconData icon;
  final AppSnackType type;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_AppPillNotice> createState() => _AppPillNoticeState();
}

class _AppPillNoticeState extends State<_AppPillNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(curve);

    _controller.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semanticColors;

    final (Color badgeBg, Color badgeFg) = switch (widget.type) {
      AppSnackType.success => (semantic.success, semantic.onSuccess),
      AppSnackType.error => (colorScheme.error, colorScheme.onError),
      AppSnackType.warning => (colorScheme.tertiary, colorScheme.onTertiary),
      AppSnackType.info => (colorScheme.primary, colorScheme.onPrimary),
    };

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          elevation: 2,
          color: colorScheme.surfaceContainerHigh,
          shape: StadiumBorder(
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 16, color: badgeFg),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
