import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/settings/notification_sound_preference.dart';
import 'package:todo_app/core/settings/notification_sound_store.dart';

final collectSoundProvider =
    AsyncNotifierProvider<CollectSoundNotifier, NotificationSoundPreference>(
  CollectSoundNotifier.new,
);

class CollectSoundNotifier extends AsyncNotifier<NotificationSoundPreference> {
  static const _store = NotificationSoundStore(
    enabledKey: 'collect_sound_enabled_v2',
    uriKey: 'collect_sound_uri_v2',
    titleKey: 'collect_sound_title_v2',
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
