import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum VolumeKeyDirection { up, down }

class VolumeKeyPlatform {
  VolumeKeyPlatform._();

  static const _methodChannel = MethodChannel('com.todo.app/volume_key');
  static const _eventChannel = EventChannel('com.todo.app/volume_key_events');

  static Stream<VolumeKeyDirection>? _events;

  static Future<bool> get isSupported async {
    if (kIsWeb) return false;
    try {
      final supported = await _methodChannel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Stream<VolumeKeyDirection> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map((event) {
      switch (event) {
        case 'up':
          return VolumeKeyDirection.up;
        case 'down':
          return VolumeKeyDirection.down;
        default:
          throw ArgumentError('Unknown volume key event: $event');
      }
    });
    return _events!;
  }

  static Future<void> setInterceptEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'setInterceptEnabled',
        {'enabled': enabled},
      );
    } on MissingPluginException {
      // No-op on unsupported platforms.
    }
  }
}
