import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_template.dart';
import 'package:todo_app/core/models/task_playlist.dart';
import 'package:todo_app/core/repositories/playlist_repository.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/sync/attachment_upload_service.dart';
import 'package:todo_app/core/sync/sync_repository.dart';
import 'package:todo_app/core/transcription/transcription_service.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(ref);
});

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

final lastSyncAtProvider = StateProvider<DateTime?>((ref) => null);

enum SyncStatus { idle, syncing, error, offline }

extension SyncStatusDisplay on SyncStatus {
  String get label => switch (this) {
        SyncStatus.idle => '已同步',
        SyncStatus.syncing => '正在同步…',
        SyncStatus.error => '同步失败',
        SyncStatus.offline => '离线',
      };

  IconData get icon => switch (this) {
        SyncStatus.idle => Icons.cloud_done_outlined,
        SyncStatus.syncing => Icons.cloud_sync_outlined,
        SyncStatus.error => Icons.cloud_off_outlined,
        SyncStatus.offline => Icons.cloud_off_outlined,
      };
}

Future<void> triggerSyncIfSignedIn(WidgetRef ref) async {
  if (AuthService.instance.isSignedIn) {
    await ref.read(syncEngineProvider).sync();
  }
}

class SyncBootstrap {
  static Future<void> initialize() async {
    await AuthService.instance.initialize();
  }
}

class SyncEngine {
  SyncEngine(this._ref);

  final Ref _ref;
  Timer? _timer;
  SyncRepository? _repo;

  Future<SyncRepository?> _repository() async {
    if (!AuthService.instance.isConfigured || !AuthService.instance.isSignedIn) {
      return null;
    }
    _repo ??= SyncRepository(AuthService.instance.client!);
    return _repo;
  }

  void startPeriodicSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
  }

  void stop() => _timer?.cancel();

  Future<void> sync() async {
    final repo = await _repository();
    if (repo == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.offline;
      return;
    }

    _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    try {
      final taskRepo = await _ref.read(taskRepositoryProvider.future);
      var local = await taskRepo.getAll();
      local = await _uploadPendingAttachments(taskRepo, local);
      await repo.pushTasks(local);
      final remote = await repo.pullTasks();
      await _mergeRemoteTasks(taskRepo, remote);

      final templateRepo = await _ref.read(templateRepositoryProvider.future);
      final localTemplates = await templateRepo.getAll();
      await repo.pushTemplates(localTemplates);
      final remoteTemplates = await repo.pullTemplates();
      await _mergeRemoteTemplates(templateRepo, remoteTemplates);

      final playlistRepo = await _ref.read(playlistRepositoryProvider.future);
      final localPlaylists = await playlistRepo.getAll();
      await repo.pushPlaylists(localPlaylists);
      final remotePlaylists = await repo.pullPlaylists();
      await _mergeRemotePlaylists(playlistRepo, remotePlaylists);

      await _ref.read(transcriptionServiceProvider).processPendingTasks();
      _ref.read(lastSyncAtProvider.notifier).state = DateTime.now();
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    } catch (e, st) {
      debugPrint('Sync error: $e\n$st');
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    }
  }

  Future<List<Task>> _uploadPendingAttachments(
    TaskRepository taskRepo,
    List<Task> tasks,
  ) async {
    final client = AuthService.instance.client;
    final userId = AuthService.instance.currentUser?.id;
    if (client == null || userId == null) return tasks;

    final uploadService = AttachmentUploadService();
    var changed = false;

    for (final task in tasks) {
      if (!task.attachments.any(uploadService.attachmentNeedsUpload)) {
        continue;
      }

      final uploaded = await uploadService.uploadPending(
        client: client,
        userId: userId,
        taskId: task.id,
        attachments: task.attachments,
      );

      if (!_attachmentsChanged(task.attachments, uploaded)) continue;

      await taskRepo.update(task.copyWith(attachments: uploaded));
      changed = true;
    }

    return changed ? await taskRepo.getAll() : tasks;
  }

  bool _attachmentsChanged(
    List<TaskAttachment> before,
    List<TaskAttachment> after,
  ) {
    if (before.length != after.length) return true;
    for (var i = 0; i < before.length; i++) {
      if (before[i].remoteUrl != after[i].remoteUrl) return true;
    }
    return false;
  }

  Future<void> _mergeRemoteTasks(TaskRepository taskRepo, List<Task> remote) async {
    final local = await taskRepo.getAll();
    final localMap = {for (final t in local) t.id: t};

    for (final r in remote) {
      final l = localMap[r.id];
      if (l == null) {
        await taskRepo.update(r);
      } else if (r.updatedAt.isAfter(l.updatedAt)) {
        await taskRepo.update(r);
      } else if (l.updatedAt.isAfter(r.updatedAt)) {
        // local wins — will push on next sync
      }
    }
  }

  Future<void> _mergeRemoteTemplates(
    TemplateRepository templateRepo,
    List<TaskTemplate> remote,
  ) async {
    final local = await templateRepo.getAll();
    final localMap = {for (final t in local) t.id: t};

    for (final r in remote) {
      final l = localMap[r.id];
      if (l == null) {
        await templateRepo.upsertRemote(r);
      } else if (r.updatedAt.isAfter(l.updatedAt)) {
        await templateRepo.upsertRemote(r);
      }
    }
  }

  Future<void> _mergeRemotePlaylists(
    PlaylistRepository playlistRepo,
    List<TaskPlaylist> remote,
  ) async {
    final local = await playlistRepo.getAll();
    final localMap = {for (final p in local) p.id: p};

    for (final r in remote) {
      final l = localMap[r.id];
      if (l == null) {
        await playlistRepo.upsertRemote(r);
      } else if (r.updatedAt.isAfter(l.updatedAt)) {
        await playlistRepo.upsertRemote(r);
      }
    }
  }
}
