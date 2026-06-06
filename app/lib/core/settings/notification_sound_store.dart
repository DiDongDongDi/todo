import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/settings/notification_sound_platform.dart';
import 'package:todo_app/core/settings/notification_sound_preference.dart';

class NotificationSoundStore {
  const NotificationSoundStore({
    required this.enabledKey,
    required this.uriKey,
    required this.titleKey,
  });

  final String enabledKey;
  final String uriKey;
  final String titleKey;

  NotificationSoundPreference load(SharedPreferences prefs) {
    final enabled = prefs.getBool(enabledKey) ?? false;
    return NotificationSoundPreference(
      enabled: enabled,
      uri: prefs.getString(uriKey),
      title: prefs.getString(titleKey),
    );
  }

  Future<void> save(
    SharedPreferences prefs,
    NotificationSoundPreference pref,
  ) async {
    await prefs.setBool(enabledKey, pref.enabled);
    if (pref.uri != null) {
      await prefs.setString(uriKey, pref.uri!);
    } else {
      await prefs.remove(uriKey);
    }
    if (pref.title != null) {
      await prefs.setString(titleKey, pref.title!);
    } else {
      await prefs.remove(titleKey);
    }
  }

  Future<NotificationSoundPreference> createDefault(
    SharedPreferences prefs,
  ) async {
    if (!await NotificationSoundPlatform.isSupported) {
      return NotificationSoundPreference.none;
    }

    final uri = await NotificationSoundPlatform.getDefaultUri();
    if (uri == null) {
      return NotificationSoundPreference.none;
    }

    final title =
        await NotificationSoundPlatform.getTitle(uri) ?? '系统默认通知音';
    final pref = NotificationSoundPreference(
      enabled: true,
      uri: uri,
      title: title,
    );
    await save(prefs, pref);
    return pref;
  }

  Future<NotificationSoundPreference> setEnabled(
    SharedPreferences prefs,
    NotificationSoundPreference current,
    bool enabled,
  ) async {
    var next = current.copyWith(enabled: enabled);

    if (enabled && (next.uri == null || next.uri!.isEmpty)) {
      final uri = await NotificationSoundPlatform.getDefaultUri();
      if (uri != null) {
        final title =
            await NotificationSoundPlatform.getTitle(uri) ?? '系统默认通知音';
        next = next.copyWith(uri: uri, title: title);
      } else {
        next = NotificationSoundPreference.none;
      }
    }

    await save(prefs, next);
    return next;
  }

  Future<NotificationSoundPreference?> pickFromSystem(
    SharedPreferences prefs,
    NotificationSoundPreference current,
  ) async {
    final picked = await NotificationSoundPlatform.pick(
      existingUri: current.uri,
    );
    if (picked == null) return null;

    final next = NotificationSoundPreference(
      enabled: picked.enabled,
      uri: picked.uri,
      title: picked.title,
    );
    await save(prefs, next);
    return next;
  }
}
