import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/features/archive/archive_screen.dart';
import 'package:todo_app/features/auth/auth_screen.dart';
import 'package:todo_app/features/shell/shell_screen.dart';
import 'package:todo_app/features/task_detail/task_detail_screen.dart';
import 'package:todo_app/features/settings/sound_settings_screen.dart';
import 'package:todo_app/features/someday/someday_screen.dart';
import 'package:todo_app/features/templates/template_edit_screen.dart';
import 'package:todo_app/features/templates/template_list_screen.dart';
import 'package:todo_app/features/trash/trash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const ShellScreen(),
        ),
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
        path: '/someday',
        builder: (context, state) => const SomedayScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/task/:id',
        builder: (context, state) => TaskDetailScreen(
          taskId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/sounds',
        builder: (context, state) => const SoundSettingsScreen(),
      ),
      GoRoute(
        path: '/templates',
        builder: (context, state) => const TemplateListScreen(),
      ),
      GoRoute(
        path: '/templates/:id',
        builder: (context, state) => TemplateEditScreen(
          templateId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
