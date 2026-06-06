import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/settings/notification_sound_platform.dart';

const _enabledKey = 'collect_sound_enabled_v2';
const _uriKey = 'collect_sound_uri_v2';
const _titleKey = 'collect_sound_title_v2';

class CollectSoundPreference {
  const CollectSoundPreference({
    required this.enabled,
    this.uri,
    this.title,
  });

  final bool enabled;
  final String? uri;
  final String? title;

  static const none = CollectSoundPreference(enabled: false);

  bool get canPlay => enabled && uri != null && uri!.isNotEmpty;

  String get displayTitle {
    if (!enabled) return '无声';
    if (title != null && title!.isNotEmpty) return title!;
    return '系统通知音';
  }

  CollectSoundPreference copyWith({
    bool? enabled,
    String? uri,
    String? title,
  }) {
    return CollectSoundPreference(
      enabled: enabled ?? this.enabled,
      uri: uri ?? this.uri,
      title: title ?? this.title,
    );
  }
}

final collectSoundProvider =
    AsyncNotifierProvider<CollectSoundNotifier, CollectSoundPreference>(
  CollectSoundNotifier.new,
);

class CollectSoundNotifier extends AsyncNotifier<CollectSoundPreference> {
  SharedPreferences? _prefs;

  @override
  Future<CollectSoundPreference> build() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_prefs!.containsKey(_enabledKey)) {
      return _createDefaultPreference();
    }
    return _load();
  }

  Future<CollectSoundPreference> _createDefaultPreference() async {
    if (!await NotificationSoundPlatform.isSupported) {
      return CollectSoundPreference.none;
    }

    final uri = await NotificationSoundPlatform.getDefaultUri();
    if (uri == null) {
      return CollectSoundPreference.none;
    }

    final title =
        await NotificationSoundPlatform.getTitle(uri) ?? '系统默认通知音';
    final pref = CollectSoundPreference(
      enabled: true,
      uri: uri,
      title: title,
    );
    await _save(pref);
    return pref;
  }

  CollectSoundPreference _load() {
    final prefs = _prefs!;
    final enabled = prefs.getBool(_enabledKey) ?? false;
    if (!enabled) {
      return CollectSoundPreference(
        enabled: false,
        uri: prefs.getString(_uriKey),
        title: prefs.getString(_titleKey),
      );
    }
    return CollectSoundPreference(
      enabled: true,
      uri: prefs.getString(_uriKey),
      title: prefs.getString(_titleKey),
    );
  }

  Future<void> _save(CollectSoundPreference pref) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, pref.enabled);
    if (pref.uri != null) {
      await prefs.setString(_uriKey, pref.uri!);
    } else {
      await prefs.remove(_uriKey);
    }
    if (pref.title != null) {
      await prefs.setString(_titleKey, pref.title!);
    } else {
      await prefs.remove(_titleKey);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final current = state.value ?? CollectSoundPreference.none;
    var next = current.copyWith(enabled: enabled);

    if (enabled && (next.uri == null || next.uri!.isEmpty)) {
      final uri = await NotificationSoundPlatform.getDefaultUri();
      if (uri != null) {
        final title =
            await NotificationSoundPlatform.getTitle(uri) ?? '系统默认通知音';
        next = next.copyWith(uri: uri, title: title);
      } else {
        next = CollectSoundPreference.none;
      }
    }

    await _save(next);
    state = AsyncData(next);
  }

  /// Opens the system notification sound picker.
  /// Returns `false` when cancelled or unsupported.
  Future<bool> pickFromSystem() async {
    final current = state.value ?? CollectSoundPreference.none;
    final picked = await NotificationSoundPlatform.pick(
      existingUri: current.uri,
    );
    if (picked == null) return false;

    final next = CollectSoundPreference(
      enabled: picked.enabled,
      uri: picked.uri,
      title: picked.title,
    );
    await _save(next);
    state = AsyncData(next);
    return true;
  }
}
