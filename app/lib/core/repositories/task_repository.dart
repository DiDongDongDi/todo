import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/limits/resource_limits.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_check_in.dart';
import 'package:todo_app/core/models/task_hierarchy.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/models/playlist_tasks.dart';
import 'package:todo_app/core/models/task_playlist.dart';
import 'package:todo_app/core/repositories/playlist_repository.dart';
import 'package:todo_app/core/settings/process_queue_source_settings.dart';
import 'package:uuid/uuid.dart';

const _storageKey = 'todo_tasks_v1';

class CompletedTaskEntry {
  const CompletedTaskEntry({
    required this.task,
    required this.isPeriodCompletion,
  });

  final Task task;
  final bool isPeriodCompletion;
}

DateTime completedAt(CompletedTaskEntry entry) {
  if (entry.isPeriodCompletion) {
    return entry.task.lastDailyCompletedAt ?? entry.task.updatedAt;
  }
  return entry.task.archivedAt ?? entry.task.updatedAt;
}

List<CompletedTaskEntry> mergeCompletedTasks({
  required List<Task> archived,
  required List<Task> inbox,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final entries = <CompletedTaskEntry>[
    ...archived.map(
      (task) => CompletedTaskEntry(task: task, isPeriodCompletion: false),
    ),
    ...inbox
        .where((task) => isRecurring(task) && isPeriodCompleted(task, today))
        .map(
          (task) => CompletedTaskEntry(task: task, isPeriodCompletion: true),
        ),
  ];
  entries.sort((a, b) => completedAt(b).compareTo(completedAt(a)));
  return entries;
}

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

List<Task> resolveProcessQueueTasks({
  required ProcessQueueSource source,
  required List<Task> inbox,
  required List<Task> someday,
  required List<TaskPlaylist> playlists,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  switch (source.kind) {
    case ProcessQueueKind.inbox:
      return filterProcessTasks(inbox, todayOnly: false, now: today);
    case ProcessQueueKind.daily:
      return filterProcessTasks(inbox, todayOnly: true, now: today);
    case ProcessQueueKind.someday:
      return filterSomedayTasks(someday, now: today);
    case ProcessQueueKind.playlist:
      final playlistId = source.playlistId;
      if (playlistId == null) return const [];
      TaskPlaylist? playlist;
      for (final p in playlists) {
        if (p.id == playlistId) {
          playlist = p;
          break;
        }
      }
      if (playlist == null) return const [];
      return resolvePlaylistTasks(
        playlist: playlist,
        inbox: inbox,
        someday: someday,
      );
  }
}

final processTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final sourceAsync = ref.watch(processQueueSourceProvider);
  final inboxAsync = ref.watch(inboxTasksProvider);
  final somedayAsync = ref.watch(somedayTasksProvider);
  final playlistsAsync = ref.watch(playlistsProvider);

  if (sourceAsync.isLoading ||
      inboxAsync.isLoading ||
      somedayAsync.isLoading ||
      playlistsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (sourceAsync.hasError) {
    return AsyncValue.error(sourceAsync.error!, sourceAsync.stackTrace!);
  }
  if (inboxAsync.hasError) {
    return AsyncValue.error(inboxAsync.error!, inboxAsync.stackTrace!);
  }
  if (somedayAsync.hasError) {
    return AsyncValue.error(somedayAsync.error!, somedayAsync.stackTrace!);
  }
  if (playlistsAsync.hasError) {
    return AsyncValue.error(playlistsAsync.error!, playlistsAsync.stackTrace!);
  }

  final source = sourceAsync.value ?? const ProcessQueueSource.inbox();
  return AsyncValue.data(
    resolveProcessQueueTasks(
      source: source,
      inbox: inboxAsync.value ?? [],
      someday: somedayAsync.value ?? [],
      playlists: playlistsAsync.value ?? [],
    ),
  );
});

final archivedTasksProvider = StreamProvider<List<Task>>((ref) async* {
  final store = await ref.watch(taskStoreInitProvider.future);
  yield* store.watchByStatus(TaskStatus.archived);
});

final completedTasksProvider = Provider<AsyncValue<List<CompletedTaskEntry>>>((ref) {
  final inboxAsync = ref.watch(inboxTasksProvider);
  final archivedAsync = ref.watch(archivedTasksProvider);

  if (inboxAsync.isLoading || archivedAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (inboxAsync.hasError) {
    return AsyncValue.error(inboxAsync.error!, inboxAsync.stackTrace!);
  }
  if (archivedAsync.hasError) {
    return AsyncValue.error(archivedAsync.error!, archivedAsync.stackTrace!);
  }

  return AsyncValue.data(
    mergeCompletedTasks(
      archived: archivedAsync.value ?? [],
      inbox: inboxAsync.value ?? [],
    ),
  );
});

final trashedTasksProvider = StreamProvider<List<Task>>((ref) async* {
  final store = await ref.watch(taskStoreInitProvider.future);
  yield* store.watchByStatus(TaskStatus.trashed);
});

final somedayTasksProvider = StreamProvider<List<Task>>((ref) async* {
  final store = await ref.watch(taskStoreInitProvider.future);
  yield* store.watchByStatus(TaskStatus.someday);
});

final allActiveTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final inboxAsync = ref.watch(inboxTasksProvider);
  final archivedAsync = ref.watch(archivedTasksProvider);
  final trashedAsync = ref.watch(trashedTasksProvider);
  final somedayAsync = ref.watch(somedayTasksProvider);

  if (inboxAsync.isLoading ||
      archivedAsync.isLoading ||
      trashedAsync.isLoading ||
      somedayAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (inboxAsync.hasError) {
    return AsyncValue.error(inboxAsync.error!, inboxAsync.stackTrace!);
  }
  if (archivedAsync.hasError) {
    return AsyncValue.error(archivedAsync.error!, archivedAsync.stackTrace!);
  }
  if (trashedAsync.hasError) {
    return AsyncValue.error(trashedAsync.error!, trashedAsync.stackTrace!);
  }
  if (somedayAsync.hasError) {
    return AsyncValue.error(somedayAsync.error!, somedayAsync.stackTrace!);
  }

  return AsyncValue.data([
    ...inboxAsync.value ?? [],
    ...archivedAsync.value ?? [],
    ...trashedAsync.value ?? [],
    ...somedayAsync.value ?? [],
  ]);
});

final parentTaskIdsProvider = Provider<AsyncValue<Set<String>>>((ref) {
  return ref.watch(allActiveTasksProvider).whenData(parentIdsWithSubtasks);
});

class TaskRepository {
  TaskRepository(this._store, this._uuid);

  final TaskStore _store;
  final Uuid _uuid;

  Stream<List<Task>> watchInbox() => _store.watchByStatus(TaskStatus.inbox);

  Stream<List<Task>> watchArchived() => _store.watchByStatus(TaskStatus.archived);

  Stream<List<Task>> watchTrashed() => _store.watchByStatus(TaskStatus.trashed);

  Stream<List<Task>> watchSomeday() => _store.watchByStatus(TaskStatus.someday);

  Future<Task> createInbox({
    required String title,
    List<TaskAttachment> attachments = const [],
    TranscriptionStatus transcriptionStatus = TranscriptionStatus.none,
    TaskRecurrence recurrence = TaskRecurrence.none,
    DateTime? dailyUntil,
    DateTime? dueDate,
    String? parentId,
    int checkInTarget = 1,
  }) async {
    await _ensureTaskCapacity();
    final now = DateTime.now().toUtc();
    final normalizedDue = recurrence == TaskRecurrence.daily
        ? null
        : normalizeRecurringDueDate(
            recurrence: recurrence,
            dueDate: dueDate,
          );
    final task = Task(
      id: _uuid.v4(),
      title: title.trim(),
      status: TaskStatus.inbox,
      sortOrder: now.millisecondsSinceEpoch.toDouble(),
      attachments: attachments,
      transcriptionStatus: transcriptionStatus,
      createdAt: now,
      updatedAt: now,
      syncVersion: 1,
      recurrence: recurrence,
      dailyUntil: recurrence != TaskRecurrence.none ? dailyUntil : null,
      dueDate: normalizedDue,
      parentId: parentId,
      checkInTarget: checkInTarget.clamp(1, 99),
    );
    await _store.upsert(task);
    return task;
  }

  Future<void> _ensureTaskCapacity() async {
    final all = await _store.getAll();
    final active = all.where((t) => t.deletedAt == null).length;
    if (active >= ResourceLimits.maxTasksPerUser) {
      throw TaskLimitExceededException();
    }
  }

  Future<Task> createSubtask({
    required String parentId,
    required String title,
    List<TaskAttachment> attachments = const [],
    TranscriptionStatus transcriptionStatus = TranscriptionStatus.none,
    TaskRecurrence recurrence = TaskRecurrence.none,
    DateTime? dailyUntil,
    DateTime? dueDate,
    int checkInTarget = 1,
  }) async {
    final parent = await _require(parentId);
    if (parent.isSubtask) {
      throw StateError('Cannot add subtask to a subtask');
    }
    return createInbox(
      title: title,
      attachments: attachments,
      transcriptionStatus: transcriptionStatus,
      recurrence: recurrence,
      dailyUntil: dailyUntil,
      dueDate: dueDate,
      parentId: parentId,
      checkInTarget: checkInTarget,
    );
  }

  Future<({Task parent, List<Task> subtasks})> createInboxWithSubtasks({
    required String title,
    List<TaskAttachment> attachments = const [],
    TranscriptionStatus transcriptionStatus = TranscriptionStatus.none,
    TaskRecurrence recurrence = TaskRecurrence.none,
    DateTime? dailyUntil,
    DateTime? dueDate,
    List<String> subtaskTitles = const [],
    int checkInTarget = 1,
  }) async {
    final parent = await createInbox(
      title: title,
      attachments: attachments,
      transcriptionStatus: transcriptionStatus,
      recurrence: recurrence,
      dailyUntil: dailyUntil,
      dueDate: dueDate,
      checkInTarget: checkInTarget,
    );

    final subtasks = <Task>[];
    for (final subTitle in subtaskTitles) {
      if (subTitle.trim().isEmpty) continue;
      subtasks.add(
        await createSubtask(parentId: parent.id, title: subTitle),
      );
    }
    return (parent: parent, subtasks: subtasks);
  }

  Future<List<Task>> getSubtasks(String parentId) async {
    final all = await _store.getAll();
    return all
        .where(
          (t) =>
              t.parentId == parentId &&
              t.deletedAt == null &&
              t.status != TaskStatus.trashed &&
              t.status != TaskStatus.someday,
        )
        .toList()
      ..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
  }

  Future<Task> update(Task task) async {
    final previous = await _store.getById(task.id);
    final clampedCount = clampCheckInCount(task.checkInCount, task.checkInTarget);
    final normalized = clampedCount != task.checkInCount
        ? task.copyWith(checkInCount: clampedCount)
        : task;
    final updated = normalized.copyWith(
      updatedAt: DateTime.now().toUtc(),
      syncVersion: normalized.syncVersion + 1,
    );
    await _store.upsert(updated);

    if (previous != null &&
        !updated.isSubtask &&
        _scheduleChanged(previous, updated)) {
      await _propagateScheduleToSubtasks(previous, updated);
    }

    return updated;
  }

  bool _scheduleChanged(Task before, Task after) {
    return before.recurrence != after.recurrence ||
        !_datesEqual(before.dueDate, after.dueDate) ||
        !_datesEqual(before.dailyUntil, after.dailyUntil);
  }

  bool _datesEqual(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return localDate(a) == localDate(b);
  }

  Future<void> _propagateScheduleToSubtasks(
    Task parentBefore,
    Task parentAfter,
  ) async {
    if (!isScheduled(parentAfter)) return;

    final subtasks = await _allSubtasks(parentAfter.id);
    for (final sub in subtasks) {
      if (sub.status == TaskStatus.trashed) continue;
      if (!subtaskShouldInheritParentSchedule(sub, parentBefore)) continue;
      await update(applyParentSchedule(sub, parentAfter));
    }
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
      clearSomedayAt: true,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> completeRecurringPeriod(String id) async {
    final task = await _require(id);
    final nowLocal = DateTime.now();
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final nowUtc = DateTime.now().toUtc();
    final updated = task.copyWith(
      lastDailyCompletedAt: todayLocal,
      updatedAt: nowUtc,
      syncVersion: task.syncVersion + 1,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> completeDailyToday(String id) => completeRecurringPeriod(id);

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

  Future<Task> undoDailyCompletionWithHierarchy(String id) async {
    final task = await _require(id);
    final now = DateTime.now();

    if (task.isSubtask) {
      final restored = await undoDailyCompletion(id);
      final parentId = task.parentId!;
      final parent = await _store.getById(parentId);
      if (parent != null && isPeriodCompleted(parent, now)) {
        await undoDailyCompletion(parentId);
      }
      return restored;
    }

    final restored = await undoDailyCompletion(id);
    final subtasks = await _allSubtasks(id);
    for (final sub in subtasks) {
      if (isPeriodCompleted(sub, now)) {
        await undoDailyCompletion(sub.id);
      }
    }
    return restored;
  }

  Future<({Task task, CheckInResult result})> checkIn(String id) async {
    final task = await _require(id);
    final nowLocal = DateTime.now();
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final nowUtc = DateTime.now().toUtc();
    final target = task.checkInTarget.clamp(1, 99);

    if (target <= 1) {
      if (isRecurring(task)) {
        final updated = await completeRecurringPeriod(id);
        return (task: updated, result: CheckInResult.finalCompletion);
      }
      final updated = await archive(id);
      return (task: updated, result: CheckInResult.finalCompletion);
    }

    final effective = effectiveCheckInCount(task, now: nowLocal);
    final newCount = effective + 1;

    if (newCount < target) {
      final updated = task.copyWith(
        checkInCount: newCount,
        lastCheckInAt: todayLocal,
        updatedAt: nowUtc,
        syncVersion: task.syncVersion + 1,
      );
      await _store.upsert(updated);
      return (task: updated, result: CheckInResult.partial);
    }

    if (isRecurring(task)) {
      final updated = task.copyWith(
        lastDailyCompletedAt: todayLocal,
        checkInCount: 0,
        lastCheckInAt: todayLocal,
        updatedAt: nowUtc,
        syncVersion: task.syncVersion + 1,
      );
      await _store.upsert(updated);
      return (task: updated, result: CheckInResult.finalCompletion);
    }

    final updated = task.copyWith(
      status: TaskStatus.archived,
      archivedAt: nowUtc,
      checkInCount: target,
      lastCheckInAt: todayLocal,
      updatedAt: nowUtc,
      syncVersion: task.syncVersion + 1,
      clearTrashedAt: true,
      clearSomedayAt: true,
    );
    await _store.upsert(updated);
    return (task: updated, result: CheckInResult.finalCompletion);
  }

  Future<Task> undoCheckIn(String id, {required bool wasFinalCompletion}) async {
    final task = await _require(id);
    final nowLocal = DateTime.now();
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final nowUtc = DateTime.now().toUtc();
    final target = task.checkInTarget.clamp(1, 99);

    if (!wasFinalCompletion) {
      final effective = effectiveCheckInCount(task, now: nowLocal);
      final newCount = (effective - 1).clamp(0, target);
      final updated = task.copyWith(
        checkInCount: newCount,
        lastCheckInAt: newCount == 0 ? null : todayLocal,
        updatedAt: nowUtc,
        syncVersion: task.syncVersion + 1,
        clearLastCheckInAt: newCount == 0,
      );
      await _store.upsert(updated);
      return updated;
    }

    Task refreshed;
    if (isRecurring(task)) {
      refreshed = await undoDailyCompletion(id);
    } else {
      refreshed = await restoreToInbox(id);
    }

    final updated = refreshed.copyWith(
      checkInCount: target - 1,
      lastCheckInAt: todayLocal,
      updatedAt: nowUtc,
      syncVersion: refreshed.syncVersion + 1,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> resetCheckInProgress(String id) async {
    final task = await _require(id);
    if (!hasResettableCheckInProgress(task)) return task;

    final nowUtc = DateTime.now().toUtc();
    final updated = task.copyWith(
      checkInCount: 0,
      updatedAt: nowUtc,
      syncVersion: task.syncVersion + 1,
      clearLastCheckInAt: true,
      clearLastDailyCompletedAt: isRecurring(task),
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
      clearSomedayAt: true,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<Task> moveToSomeday(String id) async {
    final task = await _require(id);
    final now = DateTime.now().toUtc();

    if (task.isSubtask) {
      return _moveToSomedaySingle(task, now);
    }

    final subtasks = await getSubtasks(id);
    for (final sub in subtasks) {
      if (sub.status != TaskStatus.someday) {
        await _moveToSomedaySingle(sub, now);
      }
    }
    return _moveToSomedaySingle(task, now);
  }

  Future<Task> _moveToSomedaySingle(Task task, DateTime now) async {
    final updated = task.copyWith(
      status: TaskStatus.someday,
      somedayAt: now,
      updatedAt: now,
      syncVersion: task.syncVersion + 1,
      clearArchivedAt: true,
      clearTrashedAt: true,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<List<Task>> _allSubtasks(String parentId) async {
    final all = await _store.getAll();
    return all
        .where((t) => t.parentId == parentId && t.deletedAt == null)
        .toList();
  }

  Future<Task> _restoreSingle(Task task) async {
    final now = DateTime.now().toUtc();
    final updated = task.copyWith(
      status: TaskStatus.inbox,
      updatedAt: now,
      syncVersion: task.syncVersion + 1,
      clearArchivedAt: true,
      clearTrashedAt: true,
      clearSomedayAt: true,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<int> restoreAllSomedayToInbox() async {
    final tasks = await _store.getByStatus(TaskStatus.someday);
    if (tasks.isEmpty) return 0;

    var count = 0;
    for (final task in tasks) {
      if (task.isSubtask) continue;
      await restoreToInbox(task.id);
      count++;
    }
    return count;
  }

  Future<Task> restoreToInbox(String id) async {
    final task = await _require(id);

    if (task.isSubtask) {
      final restored = await _restoreSingle(task);
      final parentId = task.parentId!;
      final parent = await _store.getById(parentId);
      if (parent != null && parent.status != TaskStatus.inbox) {
        await _restoreSingle(parent);
      }
      return restored;
    }

    final restored = await _restoreSingle(task);
    final subtasks = await _allSubtasks(id);
    for (final sub in subtasks) {
      if (sub.status != TaskStatus.inbox) {
        await _restoreSingle(sub);
      }
    }
    return restored;
  }

  Future<Task> _require(String id) async {
    final task = await _store.getById(id);
    if (task == null) throw StateError('Task not found: $id');
    return task;
  }

  Future<List<Task>> getAll() => _store.getAll();

  Future<Task?> getById(String id) => _store.getById(id);

  /// Persists [orderedTasks] as inbox queue order (index 0 = front).
  Future<void> reorderInboxTasks(List<Task> orderedTasks) async {
    if (orderedTasks.isEmpty) return;

    final base = DateTime.now().toUtc().millisecondsSinceEpoch.toDouble();
    for (var i = 0; i < orderedTasks.length; i++) {
      final task = orderedTasks[i];
      final newOrder = base - i;
      if ((task.sortOrder - newOrder).abs() < 0.001) continue;
      await update(task.copyWith(sortOrder: newOrder));
    }
  }
}

final taskRepositoryProvider = FutureProvider<TaskRepository>((ref) async {
  final store = await ref.watch(taskStoreInitProvider.future);
  return TaskRepository(store, const Uuid());
});
