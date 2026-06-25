import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Platform helpers for keeping plan reminders alive in the background.
class PlanReminderPermissions {
  PlanReminderPermissions._();

  static bool get canOpenBatterySettings =>
      !kIsWeb && Platform.isAndroid;

  static bool get canShowAutostartHint =>
      !kIsWeb && Platform.isAndroid;

  /// Opens the system screen to disable battery optimization for this app.
  static Future<void> openBatteryOptimizationSettings() async {
    if (!canOpenBatterySettings) return;
    await openAppSettings();
  }

  /// Whether battery optimization is ignored (best-effort; may be unknown).
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!canOpenBatterySettings) return true;
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// Request exemption from battery optimization (Android).
  static Future<bool> requestBatteryOptimizationExemption() async {
    if (!canOpenBatterySettings) return true;
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;
    final result = await Permission.ignoreBatteryOptimizations.request();
    return result.isGranted;
  }
}
