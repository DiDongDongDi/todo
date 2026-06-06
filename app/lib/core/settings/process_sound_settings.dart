import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/settings/notification_sound_preference.dart';
import 'package:todo_app/core/settings/notification_sound_store.dart';

class ProcessSoundSettings {
  const ProcessSoundSettings({
    required this.complete,
    required this.trash,
  });

  final NotificationSoundPreference complete;
  final NotificationSoundPreference trash;

  static const none = ProcessSoundSettings(
    complete: NotificationSoundPreference.none,
    trash: NotificationSoundPreference.none,
  );

  ProcessSoundSettings copyWith({
    NotificationSoundPreference? complete,
    NotificationSoundPreference? trash,
  }) {
    return ProcessSoundSettings(
      complete: complete ?? this.complete,
      trash: trash ?? this.trash,
    );
  }
}

enum ProcessSoundKind { complete, trash }

final processSoundProvider =
    AsyncNotifierProvider<ProcessSoundNotifier, ProcessSoundSettings>(
  ProcessSoundNotifier.new,
);

class ProcessSoundNotifier extends AsyncNotifier<ProcessSoundSettings> {
  static const _completeStore = NotificationSoundStore(
    enabledKey: 'process_complete_sound_enabled_v1',
    uriKey: 'process_complete_sound_uri_v1',
    titleKey: 'process_complete_sound_title_v1',
  );

  static const _trashStore = NotificationSoundStore(
    enabledKey: 'process_trash_sound_enabled_v1',
    uriKey: 'process_trash_sound_uri_v1',
    titleKey: 'process_trash_sound_title_v1',
  );

  SharedPreferences? _prefs;

  @override
  Future<ProcessSoundSettings> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _loadOrCreateDefaults();
  }

  Future<ProcessSoundSettings> _loadOrCreateDefaults() async {
    final prefs = _prefs!;
    final hasComplete = prefs.containsKey(_completeStore.enabledKey);
    final hasTrash = prefs.containsKey(_trashStore.enabledKey);

    final complete = hasComplete
        ? _completeStore.load(prefs)
        : await _completeStore.createDefault(prefs);
    final trash = hasTrash
        ? _trashStore.load(prefs)
        : await _trashStore.createDefault(prefs);

    return ProcessSoundSettings(complete: complete, trash: trash);
  }

  NotificationSoundStore _storeFor(ProcessSoundKind kind) {
    return switch (kind) {
      ProcessSoundKind.complete => _completeStore,
      ProcessSoundKind.trash => _trashStore,
    };
  }

  NotificationSoundPreference _preferenceFor(ProcessSoundKind kind) {
    final current = state.value ?? ProcessSoundSettings.none;
    return switch (kind) {
      ProcessSoundKind.complete => current.complete,
      ProcessSoundKind.trash => current.trash,
    };
  }

  Future<void> setEnabled(ProcessSoundKind kind, bool enabled) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final store = _storeFor(kind);
    final next = await store.setEnabled(
      prefs,
      _preferenceFor(kind),
      enabled,
    );
    final current = state.value ?? ProcessSoundSettings.none;
    final updated = switch (kind) {
      ProcessSoundKind.complete => current.copyWith(complete: next),
      ProcessSoundKind.trash => current.copyWith(trash: next),
    };
    state = AsyncData(updated);
  }

  Future<bool> pickFromSystem(ProcessSoundKind kind) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final store = _storeFor(kind);
    final next = await store.pickFromSystem(prefs, _preferenceFor(kind));
    if (next == null) return false;

    final current = state.value ?? ProcessSoundSettings.none;
    final updated = switch (kind) {
      ProcessSoundKind.complete => current.copyWith(complete: next),
      ProcessSoundKind.trash => current.copyWith(trash: next),
    };
    state = AsyncData(updated);
    return true;
  }
}
