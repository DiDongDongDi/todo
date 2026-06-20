import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/reminders/plan_reminder_constants.dart';

final planReminderEnabledProvider =
    AsyncNotifierProvider<PlanReminderEnabledNotifier, bool>(
  PlanReminderEnabledNotifier.new,
);

class PlanReminderEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(planReminderEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(planReminderEnabledKey, enabled);
    state = AsyncValue.data(enabled);
  }
}
