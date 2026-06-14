import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_app/core/limits/resource_limits.dart';
import 'package:todo_app/core/models/task.dart';

/// Supabase Storage 附件上传与签名 URL 解析。
///
/// [TaskAttachment.remoteUrl] 持久化存储 object 路径 `{user_id}/{task_id}/{filename}`，
/// 展示时再通过 [resolveSignedUrl] 生成临时下载链接。
class AttachmentUploadService {
  static const bucket = 'attachments';
  static const signedUrlExpirySeconds = 3600;

  bool attachmentNeedsUpload(TaskAttachment attachment) {
    if (attachment.remoteUrl != null && attachment.remoteUrl!.isNotEmpty) {
      return false;
    }
    if (attachment.localPath.isEmpty || kIsWeb) return false;
    return File(attachment.localPath).existsSync();
  }

  String storagePathFor({
    required String userId,
    required String taskId,
    required String localPath,
  }) {
    final filename = p.basename(localPath);
    return '$userId/$taskId/$filename';
  }

  int maxBytesFor(AttachmentType type) {
    return type == AttachmentType.audio
        ? ResourceLimits.maxAudioFileBytes
        : ResourceLimits.maxImageFileBytes;
  }

  String tooLargeMessageFor(AttachmentType type) {
    return type == AttachmentType.audio
        ? ResourceLimits.audioTooLargeMessage
        : ResourceLimits.imageTooLargeMessage;
  }

  Future<int> fileSizeBytes(String localPath) async {
    if (kIsWeb || localPath.isEmpty) return 0;
    final file = File(localPath);
    if (!await file.exists()) return 0;
    return file.length();
  }

  Future<void> validateAttachmentSize(TaskAttachment attachment) async {
    final size = await fileSizeBytes(attachment.localPath);
    final maxBytes = maxBytesFor(attachment.type);
    if (size > maxBytes) {
      throw AttachmentLimitException(tooLargeMessageFor(attachment.type));
    }
  }

  Future<int> estimateUserStorageBytes({
    required SupabaseClient client,
    required String userId,
  }) async {
    try {
      final taskFolders = await client.storage.from(bucket).list(path: userId);
      var total = 0;
      for (final folder in taskFolders) {
        if (folder.id == null) continue;
        final files = await client.storage
            .from(bucket)
            .list(path: '$userId/${folder.name}');
        for (final file in files) {
          final meta = file.metadata;
          if (meta != null && meta['size'] != null) {
            total += (meta['size'] as num).toInt();
          }
        }
      }
      return total;
    } catch (e, st) {
      debugPrint('Storage quota estimate failed: $e\n$st');
      return 0;
    }
  }

  Future<void> validateStorageQuota({
    required SupabaseClient client,
    required String userId,
    required TaskAttachment attachment,
  }) async {
    final fileSize = await fileSizeBytes(attachment.localPath);
    if (fileSize <= 0) return;

    final used = await estimateUserStorageBytes(client: client, userId: userId);
    if (used + fileSize > ResourceLimits.maxStoragePerUserBytes) {
      throw AttachmentLimitException(ResourceLimits.storageQuotaExceededMessage);
    }
  }

  Future<TaskAttachment> uploadAttachment({
    required SupabaseClient client,
    required String userId,
    required String taskId,
    required TaskAttachment attachment,
  }) async {
    if (kIsWeb) return attachment;

    final file = File(attachment.localPath);
    if (!await file.exists()) return attachment;

    await validateAttachmentSize(attachment);
    await validateStorageQuota(
      client: client,
      userId: userId,
      attachment: attachment,
    );

    final objectPath = storagePathFor(
      userId: userId,
      taskId: taskId,
      localPath: attachment.localPath,
    );

    await client.storage.from(bucket).upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            upsert: true,
            contentType: attachment.type == AttachmentType.audio
                ? 'audio/mp4'
                : null,
          ),
        );

    return TaskAttachment(
      type: attachment.type,
      localPath: attachment.localPath,
      remoteUrl: objectPath,
      duration: attachment.duration,
    );
  }

  Future<List<TaskAttachment>> uploadPending({
    required SupabaseClient client,
    required String userId,
    required String taskId,
    required List<TaskAttachment> attachments,
  }) async {
    final results = <TaskAttachment>[];
    for (final attachment in attachments) {
      if (attachmentNeedsUpload(attachment)) {
        try {
          results.add(
            await uploadAttachment(
              client: client,
              userId: userId,
              taskId: taskId,
              attachment: attachment,
            ),
          );
        } on AttachmentLimitException catch (e) {
          debugPrint('Attachment upload skipped ($taskId): $e');
          results.add(attachment);
        } catch (e, st) {
          debugPrint('Attachment upload failed ($taskId): $e\n$st');
          results.add(attachment);
        }
      } else {
        results.add(attachment);
      }
    }
    return results;
  }

  static bool isHttpUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static bool isStoragePath(String? value) {
    if (value == null || value.isEmpty) return false;
    return !isHttpUrl(value);
  }

  Future<String?> resolveSignedUrl(
    SupabaseClient client,
    String storagePath,
  ) async {
    try {
      return await client.storage
          .from(bucket)
          .createSignedUrl(storagePath, signedUrlExpirySeconds);
    } catch (e, st) {
      debugPrint('Signed URL failed ($storagePath): $e\n$st');
      return null;
    }
  }

  Future<bool> localFileExists(String path) async {
    if (path.isEmpty || kIsWeb) return false;
    return File(path).exists();
  }

  /// 优先本地文件，否则解析 Storage 签名 URL。
  Future<String?> resolveDisplaySource({
    required TaskAttachment attachment,
    SupabaseClient? client,
  }) async {
    if (await localFileExists(attachment.localPath)) {
      return attachment.localPath;
    }

    final remote = attachment.remoteUrl;
    if (remote == null || remote.isEmpty) return null;
    if (isHttpUrl(remote)) return remote;
    if (client == null) return null;

    return resolveSignedUrl(client, remote);
  }
}
