import 'package:todo_app/core/settings/collect_sound_settings.dart';
import 'package:todo_app/core/settings/notification_sound_platform.dart';

class AppSounds {
  AppSounds._();

  static Future<void> playCollectSuccess(CollectSoundPreference preference) async {
    if (!preference.canPlay) return;
    await NotificationSoundPlatform.play(preference.uri!);
  }
}
