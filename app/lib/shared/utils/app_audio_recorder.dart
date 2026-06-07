import 'dart:io';

import 'package:record/record.dart';
import 'package:todo_app/shared/utils/audio_storage.dart';

/// 跨平台麦克风录音（m4a/aac）。
class AppAudioRecorder {
  AppAudioRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _startedAt;

  bool get isRecording => _startedAt != null;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (_startedAt != null) return;

    final path = await newRecordingTempPath();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    _startedAt = DateTime.now();
  }

  /// 停止录音；返回持久化后的路径与时长（秒），失败时返回 null。
  Future<({String path, int durationSeconds})?> stop() async {
    if (_startedAt == null) return null;

    final started = _startedAt!;
    _startedAt = null;

    final tempPath = await _recorder.stop();
    if (tempPath == null || tempPath.isEmpty) return null;

    final elapsed = DateTime.now().difference(started).inSeconds;
    final localPath = await persistAudioAttachment(tempPath);
    if (localPath == null) return null;

    try {
      await File(tempPath).delete();
    } catch (_) {}

    return (path: localPath, durationSeconds: elapsed.clamp(1, 3600));
  }

  Future<void> cancel() async {
    if (_startedAt == null) return;
    _startedAt = null;
    final tempPath = await _recorder.stop();
    if (tempPath != null && tempPath.isNotEmpty) {
      try {
        await File(tempPath).delete();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
