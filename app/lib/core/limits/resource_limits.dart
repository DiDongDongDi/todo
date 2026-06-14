/// Client-side resource limit constants (mirrors [docs/RESOURCE-LIMITS.md]).
abstract final class ResourceLimits {
  static const aiQueryMaxLength = 500;
  static const aiSubmitCooldownMs = 3000;

  static const maxTasksPerUser = 5000;
  static const maxAttachmentsPerTask = 5;
  static const maxAudioFileBytes = 10 * 1024 * 1024;
  static const maxImageFileBytes = 5 * 1024 * 1024;
  static const maxStoragePerUserBytes = 500 * 1024 * 1024;
  static const maxPendingTranscriptions = 20;

  static const taskLimitExceededMessage =
      '任务数量已达上限（5000 条），请归档或删除后再添加';
  static const audioTooLargeMessage = '文件过大，录音请控制在 10MB 以内';
  static const imageTooLargeMessage = '文件过大，图片请控制在 5MB 以内';
  static const storageQuotaExceededMessage =
      '云存储空间已达上限（500MB），请删除部分附件后再试';
  static const attachmentsPerTaskExceededMessage = '每个任务最多 5 个附件';
  static const aiRateLimitedMessage = '操作太频繁，请稍后再试';
  static const aiDailyLimitMessage = '今日 AI 推荐次数已用完，明天再试';
  static const transcribeDailyLimitMessage = '今日语音转写次数已用完，明天再试';

  static bool isTaskLimitError(Object error) {
    return error.toString().contains('task_limit_exceeded');
  }

  static String? aiErrorMessageFromResponse({
    required int status,
    Object? data,
  }) {
    if (status == 429) {
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      return aiRateLimitedMessage;
    }
    if (data is Map && data['error'] != null) {
      final msg = data['error'].toString();
      if (msg.contains('暂无任务可推荐')) return msg;
    }
    return null;
  }
}

class TaskLimitExceededException implements Exception {
  TaskLimitExceededException([this.message = ResourceLimits.taskLimitExceededMessage]);

  final String message;

  @override
  String toString() => message;
}

class AttachmentLimitException implements Exception {
  AttachmentLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}
