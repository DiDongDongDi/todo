import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'process_today_only_v1';

final processTodayOnlyProvider =
    AsyncNotifierProvider<ProcessTodayOnlyNotifier, bool>(
  ProcessTodayOnlyNotifier.new,
);

class ProcessTodayOnlyNotifier extends AsyncNotifier<bool> {
  SharedPreferences? _prefs;

  @override
  Future<bool> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _prefs!.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    state = AsyncData(enabled);
  }
}
