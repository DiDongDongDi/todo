import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/router/app_router.dart';
import 'package:todo_app/shared/theme/app_theme.dart';
import 'package:todo_app/shared/widgets/haptic_tap_scope.dart';

class TodoApp extends ConsumerStatefulWidget {
  const TodoApp({super.key});

  @override
  ConsumerState<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends ConsumerState<TodoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAuthReady());
  }

  Future<void> _onAuthReady() async {
    await ref.read(authInitProvider.future);
    if (AuthService.instance.isSignedIn) {
      ref.read(syncEngineProvider).startPeriodicSync();
      await ref.read(syncEngineProvider).sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (prev, next) {
      final signedIn = next.value?.session != null;
      if (signedIn) {
        ref.read(syncEngineProvider).startPeriodicSync();
        ref.read(syncEngineProvider).sync();
      } else {
        ref.read(syncEngineProvider).stop();
      }
    });

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Todo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        // Web 上 go_router 页面有时拿不到满屏约束，强制撑满视口。
        return HapticTapScope(
          child: SizedBox.expand(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
