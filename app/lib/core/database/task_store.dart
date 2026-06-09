import 'dart:async';
import 'dart:convert';

import 'package:todo_app/core/models/task.dart';

abstract class TaskStore {
  Future<void> init();
  Future<List<Task>> getByStatus(TaskStatus status);
  Stream<List<Task>> watchByStatus(TaskStatus status);
  Future<Task?> getById(String id);
  Future<void> upsert(Task task);
  Future<void> delete(String id);
  Future<List<Task>> getAll();
}

class JsonTaskStore implements TaskStore {
  JsonTaskStore({
    required Future<void> Function(String json) persist,
    required Future<String?> Function() load,
  })  : _persist = persist,
        _load = load;

  final Future<void> Function(String json) _persist;
  final Future<String?> Function() _load;

  final List<Task> _tasks = [];
  final _changeController = StreamController<void>.broadcast();
  Future<void>? _saveInFlight;

  @override
  Future<void> init() async {
    final raw = await _load();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      _tasks
        ..clear()
        ..addAll(
          list.map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))),
        );
    }
  }

  @override
  Future<List<Task>> getByStatus(TaskStatus status) async {
    final filtered = _tasks.where((t) => t.status == status && t.deletedAt == null);
    return _sortedByStatus(filtered, status);
  }

  @override
  Stream<List<Task>> watchByStatus(TaskStatus status) async* {
    yield await getByStatus(status);
    await for (final _ in _changeController.stream) {
      yield await getByStatus(status);
    }
  }

  List<Task> _sortedByStatus(Iterable<Task> items, TaskStatus status) {
    final list = items.toList();
    switch (status) {
      case TaskStatus.inbox:
        list.sort(_compareInbox);
      case TaskStatus.archived:
        list.sort(_compareArchived);
      case TaskStatus.trashed:
        list.sort(_compareTrashed);
    }
    return list;
  }

  int _compareInbox(Task a, Task b) {
    final order = b.sortOrder.compareTo(a.sortOrder);
    if (order != 0) return order;
    return b.createdAt.compareTo(a.createdAt);
  }

  int _compareArchived(Task a, Task b) {
    final aTime = a.archivedAt ?? a.updatedAt;
    final bTime = b.archivedAt ?? b.updatedAt;
    final cmp = bTime.compareTo(aTime);
    if (cmp != 0) return cmp;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  int _compareTrashed(Task a, Task b) {
    final aTime = a.trashedAt ?? a.updatedAt;
    final bTime = b.trashedAt ?? b.updatedAt;
    final cmp = bTime.compareTo(aTime);
    if (cmp != 0) return cmp;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  @override
  Future<Task?> getById(String id) async {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _tasks[index] = task;
    } else {
      _tasks.add(task);
    }
    _notifyChanged();
  }

  @override
  Future<void> delete(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    _notifyChanged();
  }

  void _notifyChanged() {
    _changeController.add(null);
    unawaited(_persistQueued());
  }

  Future<void> _persistQueued() {
    _saveInFlight ??= _save().whenComplete(() => _saveInFlight = null);
    return _saveInFlight!;
  }

  @override
  Future<List<Task>> getAll() async => List.unmodifiable(_tasks);

  Future<void> _save() async {
    final json = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await _persist(json);
  }

  void dispose() => _changeController.close();
}
