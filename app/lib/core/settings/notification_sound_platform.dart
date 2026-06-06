import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationSoundSelection {
  const NotificationSoundSelection({
    required this.enabled,
    this.uri,
    this.title,
  });

  final bool enabled;
  final String? uri;
  final String? title;

  factory NotificationSoundSelection.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      throw ArgumentError('map is null');
    }
    return NotificationSoundSelection(
      enabled: map['enabled'] as bool? ?? false,
      uri: map['uri'] as String?,
      title: map['title'] as String?,
    );
  }
}

class NotificationSoundPlatform {
  NotificationSoundPlatform._();

  static const _channel = MethodChannel('com.todo.app/notification_sound');

  static Future<bool> get isSupported async {
    if (kIsWeb) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> getDefaultUri() async {
    try {
      return await _channel.invokeMethod<String>('getDefaultUri');
    } on MissingPluginException {
      return null;
    }
  }

  static Future<String?> getTitle(String uri) async {
    try {
      return await _channel.invokeMethod<String>('getTitle', {'uri': uri});
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> play(String uri) async {
    try {
      await _channel.invokeMethod<void>('play', {'uri': uri});
    } on MissingPluginException {
      // No-op on unsupported platforms.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // No-op on unsupported platforms.
    }
  }

  /// Opens the system notification sound picker.
  /// Returns `null` when the user cancels.
  static Future<NotificationSoundSelection?> pick({String? existingUri}) async {
    try {
      final result = await _channel.invokeMethod<dynamic>(
        'pick',
        {'existingUri': existingUri},
      );
      if (result == null) return null;
      return NotificationSoundSelection.fromMap(
        Map<dynamic, dynamic>.from(result as Map),
      );
    } on MissingPluginException {
      return null;
    }
  }
}
