import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'volume_key_shortcuts_enabled_v1';

final volumeKeyShortcutsProvider =
    AsyncNotifierProvider<VolumeKeyShortcutsNotifier, bool>(
  VolumeKeyShortcutsNotifier.new,
);

class VolumeKeyShortcutsNotifier extends AsyncNotifier<bool> {
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
