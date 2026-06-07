import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 将录音临时文件复制到应用文档目录，返回持久化路径。
Future<String?> persistAudioAttachment(String tempPath) async {
  try {
    final source = File(tempPath);
    if (!await source.exists()) return null;

    final dir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(dir.path, 'attachments'));
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }

    const ext = '.m4a';
    final filename = '${const Uuid().v4()}$ext';
    final dest = File(p.join(attachmentsDir.path, filename));
    await source.copy(dest.path);
    return dest.path;
  } catch (_) {
    return null;
  }
}

/// 录音文件保存路径（临时目录，停止后由 [persistAudioAttachment] 持久化）。
Future<String> newRecordingTempPath() async {
  final dir = await getTemporaryDirectory();
  final filename = '${const Uuid().v4()}.m4a';
  return p.join(dir.path, filename);
}

String formatAudioDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m > 0) return '$m:${s.toString().padLeft(2, '0')}';
  return '${s}s';
}
