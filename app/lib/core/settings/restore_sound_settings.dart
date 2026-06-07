import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/settings/notification_sound_preference.dart';
import 'package:todo_app/core/settings/notification_sound_store.dart';

final restoreSoundProvider =
    AsyncNotifierProvider<RestoreSoundNotifier, NotificationSoundPreference>(
  RestoreSoundNotifier.new,
);

class RestoreSoundNotifier extends AsyncNotifier<NotificationSoundPreference> {
  static const _store = NotificationSoundStore(
    enabledKey: 'restore_sound_enabled_v1',
    uriKey: 'restore_sound_uri_v1',
    titleKey: 'restore_sound_title_v1',
  );

  SharedPreferences? _prefs;

  @override
  Future<NotificationSoundPreference> build() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_prefs!.containsKey(_store.enabledKey)) {
      return _store.createDefault(_prefs!);
    }
    return _store.load(_prefs!);
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final next = await _store.setEnabled(
      prefs,
      state.value ?? NotificationSoundPreference.none,
      enabled,
    );
    state = AsyncData(next);
  }

  Future<bool> pickFromSystem() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final next = await _store.pickFromSystem(
      prefs,
      state.value ?? NotificationSoundPreference.none,
    );
    if (next == null) return false;
    state = AsyncData(next);
    return true;
  }
}
