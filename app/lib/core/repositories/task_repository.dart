import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_check_in.dart';
import 'package:todo_app/core/models/task_hierarchy.dart';
import 'package:todo_app/core/models/task_schedule.dart';
import 'package:todo_app/core/settings/process_today_only_settings.dart';
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

class TaskRepository {
  TaskRepository(this._store, this._uuid);

  final TaskStore _store;
  final Uuid _uuid;

  Stream<List<Task>> watchInbox() => _store.watchByStatus(TaskStatus.inbox);

  Stream<List<Task>> watchArchived() => _store.watchByStatus(TaskStatus.archived);

  Stream<List<Task>> watchTrashed() => _store.watchByStatus(TaskStatus.trashed);

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
              t.status != TaskStatus.trashed,
        )
        .toList()
      ..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
  }

  Future<Task> update(Task task) async {
    final clampedCount = clampCheckInCount(task.checkInCount, task.checkInTarget);
    final normalized = clampedCount != task.checkInCount
        ? task.copyWith(checkInCount: clampedCount)
        : task;
    final updated = normalized.copyWith(
      updatedAt: DateTime.now().toUtc(),
      syncVersion: normalized.syncVersion + 1,
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
    );
    await _store.upsert(updated);
    return updated;
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
}

final taskRepositoryProvider = FutureProvider<TaskRepository>((ref) async {
  final store = await ref.watch(taskStoreInitProvider.future);
  return TaskRepository(store, const Uuid());
});
