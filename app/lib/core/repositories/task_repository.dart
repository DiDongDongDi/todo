import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_hierarchy.dart';
import 'package:todo_app/core/settings/process_today_only_settings.dart';
import 'package:uuid/uuid.dart';

const _storageKey = 'todo_tasks_v1';

final taskStoreInitProvider = FutureProvider<TaskStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final store = JsonTaskStore(
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

final processTasksProvider = StreamProvider<List<Task>>((ref) async* {
  final store = await ref.watch(taskStoreInitProvider.future);
  final todayOnlyAsync = ref.watch(processTodayOnlyProvider);
  final todayOnly = todayOnlyAsync.value ?? false;

  yield* store.watchByStatus(TaskStatus.inbox).map((tasks) {
    final now = DateTime.now();
    return filterProcessTasks(tasks, todayOnly: todayOnly, now: now);
  });
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
    bool isDaily = false,
    DateTime? dailyUntil,
    DateTime? dueDate,
    String? parentId,
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
      isDaily: isDaily,
      dailyUntil: dailyUntil,
      dueDate: isDaily ? null : dueDate,
      parentId: parentId,
    );
    await _store.upsert(task);
    return task;
  }

  Future<Task> createSubtask({
    required String parentId,
    required String title,
    String? note,
    List<TaskAttachment> attachments = const [],
    TranscriptionStatus transcriptionStatus = TranscriptionStatus.none,
    bool isDaily = false,
    DateTime? dailyUntil,
    DateTime? dueDate,
  }) async {
    final parent = await _require(parentId);
    if (parent.isSubtask) {
      throw StateError('Cannot add subtask to a subtask');
    }
    return createInbox(
      title: title,
      note: note,
      attachments: attachments,
      transcriptionStatus: transcriptionStatus,
      isDaily: isDaily,
      dailyUntil: dailyUntil,
      dueDate: dueDate,
      parentId: parentId,
    );
  }

  Future<List<Task>> getSubtasks(String parentId) async {
    final all = await _store.getAll();
    return all
        .where((t) => t.parentId == parentId && t.deletedAt == null)
        .toList()
      ..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
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

  Future<Task> completeDailyToday(String id) async {
    final task = await _require(id);
    final now = DateTime.now().toUtc();
    final updated = task.copyWith(
      lastDailyCompletedAt: now,
      updatedAt: now,
      syncVersion: task.syncVersion + 1,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> undoDailyCompletion(String id) async {
    final task = await _require(id);
    final now = DateTime.now().toUtc();
    final updated = task.copyWith(
      updatedAt: now,
      syncVersion: task.syncVersion + 1,
      clearLastDailyCompletedAt: true,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> trash(String id) async {
    final task = await _require(id);
    final now = DateTime.now().toUtc();

    if (task.isSubtask) {
      return _trashSingle(task, now);
    }

    final subtasks = await getSubtasks(id);
    for (final sub in subtasks) {
      if (sub.status != TaskStatus.trashed) {
        await _trashSingle(sub, now);
      }
    }
    return _trashSingle(task, now);
  }

  Future<Task> _trashSingle(Task task, DateTime now) async {
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

  Future<Task?> getById(String id) => _store.getById(id);
}

final taskRepositoryProvider = FutureProvider<TaskRepository>((ref) async {
  final store = await ref.watch(taskStoreInitProvider.future);
  return TaskRepository(store, const Uuid());
});
