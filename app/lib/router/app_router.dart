import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/features/archive/archive_screen.dart';
import 'package:todo_app/features/auth/auth_screen.dart';
import 'package:todo_app/features/shell/shell_screen.dart';
import 'package:todo_app/features/trash/trash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ShellScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/archive',
        builder: (context, state) => const ArchiveScreen(),
      ),
      GoRoute(
        path: '/trash',
        builder: (context, state) => const TrashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
    ],
  );
});
