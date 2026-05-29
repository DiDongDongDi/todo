import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:uuid/uuid.dart';

const _storageKey = 'todo_tasks_v1';

final taskStoreInitProvider = FutureProvider<TaskStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final store = JsonTaskStore.withLoader(
    persist: (json) async => prefs.setString(_storageKey, json),
    load: () async => prefs.getString(_storageKey),
  );
  await store.init();
  return store;
});

final inboxTasksProvider = StreamProvider<List<Task>>((ref) async* {
  final store = await ref.watch(taskStoreInitProvider.future);
  yield* store.watchByStatus(TaskStatus.inbox);
});

final archivedTasksProvider = StreamProvider<List<Task>>((ref) async* {
  final store = await ref.watch(taskStoreInitProvider.future);
  yield* store.watchByStatus(TaskStatus.archived);
});

final trashedTasksProvider = StreamProvider<List<Task>>((ref) async* {
  final store = await ref.watch(taskStoreInitProvider.future);
  yield* store.watchByStatus(TaskStatus.trashed);
});

class TaskRepository {
  TaskRepository(this._store, this._uuid);

  final TaskStore _store;
  final Uuid _uuid;

  Stream<List<Task>> watchInbox() => _store.watchByStatus(TaskStatus.inbox);

  Stream<List<Task>> watchArchived() => _store.watchByStatus(TaskStatus.archived);

  Stream<List<Task>> watchTrashed() => _store.watchByStatus(TaskStatus.trashed);

  Future<Task> createInbox({
    required String title,
    String? note,
    List<TaskAttachment> attachments = const [],
    TranscriptionStatus transcriptionStatus = TranscriptionStatus.none,
  }) async {
    final now = DateTime.now().toUtc();
    final task = Task(
      id: _uuid.v4(),
      title: title.trim(),
      note: note?.trim(),
      status: TaskStatus.inbox,
      sortOrder: now.millisecondsSinceEpoch.toDouble(),
      attachments: attachments,
      transcriptionStatus: transcriptionStatus,
      createdAt: now,
      updatedAt: now,
      syncVersion: 1,
    );
    await _store.upsert(task);
    return task;
  }

  Future<Task> update(Task task) async {
    final updated = task.copyWith(
      updatedAt: DateTime.now().toUtc(),
      syncVersion: task.syncVersion + 1,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> archive(String id) async {
    final task = await _require(id);
    final now = DateTime.now().toUtc();
    final updated = task.copyWith(
      status: TaskStatus.archived,
      archivedAt: now,
      updatedAt: now,
      syncVersion: task.syncVersion + 1,
      clearTrashedAt: true,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> trash(String id) async {
    final task = await _require(id);
    final now = DateTime.now().toUtc();
    final updated = task.copyWith(
      status: TaskStatus.trashed,
      trashedAt: now,
      updatedAt: now,
      syncVersion: task.syncVersion + 1,
      clearArchivedAt: true,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> restoreToInbox(String id) async {
    final task = await _require(id);
    final now = DateTime.now().toUtc();
    final updated = task.copyWith(
      status: TaskStatus.inbox,
      updatedAt: now,
      syncVersion: task.syncVersion + 1,
      clearArchivedAt: true,
      clearTrashedAt: true,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> _require(String id) async {
    final task = await _store.getById(id);
    if (task == null) throw StateError('Task not found: $id');
    return task;
  }

  Future<List<Task>> getAll() => _store.getAll();
}

final taskRepositoryProvider = FutureProvider<TaskRepository>((ref) async {
  final store = await ref.watch(taskStoreInitProvider.future);
  return TaskRepository(store, const Uuid());
});
