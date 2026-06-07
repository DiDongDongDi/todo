import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SpeechIntentResult {
  const SpeechIntentResult({
    this.text,
    this.permissionDenied = false,
    this.engineFailed = false,
    this.cancelled = false,
  });

  final String? text;
  final bool permissionDenied;
  final bool engineFailed;
  final bool cancelled;

  factory SpeechIntentResult.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const SpeechIntentResult();
    return SpeechIntentResult(
      text: map['text'] as String?,
      permissionDenied: map['permissionDenied'] as bool? ?? false,
      engineFailed: map['engineFailed'] as bool? ?? false,
      cancelled: map['cancelled'] as bool? ?? false,
    );
  }
}

/// Android 系统语音识别（RecognizerIntent），会弹出系统/Google/厂商语音面板。
class SpeechIntentPlatform {
  SpeechIntentPlatform._();

  static const _channel = MethodChannel('com.todo.app/speech_intent');

  static Future<bool> get isSupported async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 打开系统语音识别界面；用户取消或失败时 [text] 为 null。
  static Future<SpeechIntentResult> recognize({
    String prompt = '请说话…',
  }) async {
    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'recognize',
        {'prompt': prompt},
      );
      if (raw is Map) {
        return SpeechIntentResult.fromMap(raw);
      }
      if (raw is String) {
        return SpeechIntentResult(text: raw);
      }
      return const SpeechIntentResult();
    } on PlatformException catch (e) {
      if (e.code == 'permission_denied') {
        return const SpeechIntentResult(permissionDenied: true);
      }
      if (e.code == 'unavailable' || e.code == 'busy') {
        return const SpeechIntentResult(engineFailed: true);
      }
      rethrow;
    }
  }
}
