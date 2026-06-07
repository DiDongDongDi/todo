import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_display.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/sync/attachment_upload_service.dart';
import 'package:todo_app/core/sync/sync_repository.dart';

final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  return TranscriptionService(ref);
});

/// 录音任务云端转写：上传 Storage → 调用 Edge Function `transcribe`。
class TranscriptionService {
  TranscriptionService(this._ref);

  final Ref _ref;
  final _uploadService = AttachmentUploadService();
  final _processing = <String>{};

  Future<bool> _isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return !connectivity.contains(ConnectivityResult.none);
  }

  Future<Task?> _ensureUploaded(Task task) async {
    final client = AuthService.instance.client;
    final userId = AuthService.instance.currentUser?.id;
    if (client == null || userId == null) return null;

    if (!task.attachments.any(_uploadService.attachmentNeedsUpload)) {
      return task;
    }

    final uploaded = await _uploadService.uploadPending(
      client: client,
      userId: userId,
      taskId: task.id,
      attachments: task.attachments,
    );

    final repo = await _ref.read(taskRepositoryProvider.future);
    final updated = task.copyWith(attachments: uploaded);
    await repo.update(updated);
    return updated;
  }

  String? _audioStoragePath(Task task) {
    for (final attachment in task.attachments) {
      if (attachment.type != AttachmentType.audio) continue;
      final remote = attachment.remoteUrl;
      if (remote != null && remote.isNotEmpty) return remote;
    }
    return null;
  }

  /// 处理单个待转写任务；成功/失败会更新本地 [Task]。
  Future<void> processTask(Task task) async {
    if (!task.needsTranscription) return;
    if (_processing.contains(task.id)) return;

    if (!AuthService.instance.isConfigured || !AuthService.instance.isSignedIn) {
      return;
    }
    if (!await _isOnline()) return;

    _processing.add(task.id);
    try {
      final uploaded = await _ensureUploaded(task);
      if (uploaded == null) return;

      final storagePath = _audioStoragePath(uploaded);
      if (storagePath == null) {
        debugPrint('Transcription skipped: no uploaded audio for ${task.id}');
        return;
      }

      final client = AuthService.instance.client!;
      final response = await client.functions.invoke(
        'transcribe',
        body: {
          'taskId': uploaded.id,
          'storagePath': storagePath,
        },
      );

      final data = response.data;
      if (data is! Map) {
        await _markFailed(uploaded.id);
        return;
      }

      final map = Map<String, dynamic>.from(data);
      final status = map['transcription_status'] as String?;
      final title = map['title'] as String?;
      final repo = await _ref.read(taskRepositoryProvider.future);
      final current = await repo.getById(uploaded.id);
      if (current == null) return;

      if (status == 'done' && title != null && title.trim().isNotEmpty) {
        await repo.update(
          current.copyWith(
            title: title.trim(),
            transcriptionStatus: TranscriptionStatus.done,
          ),
        );
      } else if (status == 'failed') {
        await _markFailed(uploaded.id);
      }
    } catch (e, st) {
      debugPrint('Transcription error (${task.id}): $e\n$st');
      await _markFailed(task.id);
    } finally {
      _processing.remove(task.id);
    }
  }

  Future<void> _markFailed(String taskId) async {
    final repo = await _ref.read(taskRepositoryProvider.future);
    final current = await repo.getById(taskId);
    if (current == null) return;
    if (current.transcriptionStatus != TranscriptionStatus.pending) return;
    await repo.update(
      current.copyWith(transcriptionStatus: TranscriptionStatus.failed),
    );
  }

  /// 扫描本地 inbox / 全部任务，处理 pending 转写。
  Future<void> processPendingTasks() async {
    if (!AuthService.instance.isSignedIn) return;
    if (!await _isOnline()) return;

    final repo = await _ref.read(taskRepositoryProvider.future);
    final tasks = await repo.getAll();
    for (final task in tasks) {
      if (task.needsTranscription) {
        await processTask(task);
      }
    }
  }

  /// 重试 failed 任务（重置为 pending 后再处理）。
  Future<void> retryTask(Task task) async {
    if (!task.canRetryTranscription) return;

    final repo = await _ref.read(taskRepositoryProvider.future);
    final current = await repo.getById(task.id);
    if (current == null) return;

    final reset = current.copyWith(
      transcriptionStatus: TranscriptionStatus.pending,
    );
    await repo.update(reset);

    if (AuthService.instance.isSignedIn) {
      final syncRepo = SyncRepository(AuthService.instance.client!);
      await syncRepo.pushTasks([reset]);
    }

    await processTask(reset);
  }
}
