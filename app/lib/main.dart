import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/app.dart';
import 'package:todo_app/core/reminders/plan_reminder_workmanager.dart';
import 'package:todo_app/core/sync/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SyncBootstrap.initialize();
  await initializePlanReminderWorkmanager();
  runApp(const ProviderScope(child: TodoApp()));
}
