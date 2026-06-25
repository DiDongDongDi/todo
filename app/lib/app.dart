import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/reminders/plan_reminder_provider.dart';
import 'package:todo_app/core/reminders/plan_reminder_service.dart';
import 'package:todo_app/core/reminders/plan_reminder_settings.dart';
import 'package:todo_app/core/reminders/plan_reminder_workmanager.dart';
import 'package:todo_app/core/reminders/reminder_guardian_service.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/router/app_router.dart';
import 'package:todo_app/shared/theme/app_theme.dart';
import 'package:todo_app/shared/widgets/haptic_tap_scope.dart';

class TodoApp extends ConsumerStatefulWidget {
  const TodoApp({super.key});

  @override
  ConsumerState<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends ConsumerState<TodoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onAppResumed());
    }
  }

  Future<void> _onAppResumed() async {
    await _syncPlanReminders();
    await _ensureGuardianRunning();
  }

  Future<void> _bootstrap() async {
    await ReminderGuardianService.instance.initialize();
    await PlanReminderService.instance.initialize(
      onTap: (taskId) {
        if (!mounted) return;
        handlePlanReminderTap(taskId, ref);
      },
    );
    await PlanReminderService.instance.handleLaunchNotification();
    await ref.read(planReminderEnabledProvider.future);
    final enabled = ref.read(planReminderEnabledProvider).value ?? true;
    if (enabled) {
      await PlanReminderService.instance.requestPermissions();
    }
    await _syncPlanReminders();
    await _syncGuardianAndBackgroundTasks(enabled: enabled);
    await _onAuthReady();
  }

  Future<void> _syncPlanReminders() async {
    await syncPlanRemindersFromRef(ref);
  }

  Future<void> _syncGuardianAndBackgroundTasks({required bool enabled}) async {
    if (enabled) {
      await registerPlanReminderBackgroundTasks(enabled: true);
      await ReminderGuardianService.instance.start();
    } else {
      await registerPlanReminderBackgroundTasks(enabled: false);
      await ReminderGuardianService.instance.stop();
    }
  }

  Future<void> _ensureGuardianRunning() async {
    final enabled = ref.read(planReminderEnabledProvider).value ?? true;
    if (!enabled || !ReminderGuardianService.isSupported) return;
    if (!await ReminderGuardianService.instance.isRunning()) {
      await ReminderGuardianService.instance.start();
    }
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
    ref.watch(planReminderCoordinatorProvider);

    ref.listen(authStateProvider, (prev, next) {
      final signedIn = next.value?.session != null;
      if (signedIn) {
        ref.read(syncEngineProvider).startPeriodicSync();
        ref.read(syncEngineProvider).sync();
      } else {
        ref.read(syncEngineProvider).stop();
      }
    });

    ref.listen(planReminderEnabledProvider, (prev, next) {
      next.whenData((enabled) {
        unawaited(_syncGuardianAndBackgroundTasks(enabled: enabled));
      });
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
