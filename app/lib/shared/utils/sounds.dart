import 'package:todo_app/core/settings/notification_sound_preference.dart';
import 'package:todo_app/core/settings/notification_sound_platform.dart';

class AppSounds {
  AppSounds._();

  static Future<void> play(NotificationSoundPreference preference) async {
    if (!preference.canPlay) return;
    await NotificationSoundPlatform.play(preference.uri!);
  }

  static Future<void> playCollectSuccess(
    NotificationSoundPreference preference,
  ) =>
      play(preference);
}
