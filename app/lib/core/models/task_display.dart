import 'package:todo_app/core/models/task.dart';

extension TaskDisplayExtension on Task {
  /// 处理 Tab / 列表展示用标题（含转写状态占位）。
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    return switch (transcriptionStatus) {
      TranscriptionStatus.pending => '转写中…',
      TranscriptionStatus.failed => '转写失败',
      TranscriptionStatus.none || TranscriptionStatus.done => '（无标题）',
    };
  }

  bool get canRetryTranscription =>
      transcriptionStatus == TranscriptionStatus.failed &&
      attachments.any((a) => a.type == AttachmentType.audio);

  bool get needsTranscription =>
      transcriptionStatus == TranscriptionStatus.pending &&
      attachments.any((a) => a.type == AttachmentType.audio);
}
