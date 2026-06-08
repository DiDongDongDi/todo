import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/database/template_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_template.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:uuid/uuid.dart';

const _storageKey = 'todo_templates_v1';

final templateStoreInitProvider = FutureProvider<TemplateStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final store = JsonTemplateStore(
    persist: (json) async => prefs.setString(_storageKey, json),
    load: () async => prefs.getString(_storageKey),
  );
  await store.init();
  return store;
});

final templatesProvider = StreamProvider<List<TaskTemplate>>((ref) async* {
  final store = await ref.watch(templateStoreInitProvider.future);
  yield* store.watchAll();
});

class TemplateRepository {
  TemplateRepository(this._store, this._taskRepo, this._uuid);

  final TemplateStore _store;
  final TaskRepository _taskRepo;
  final Uuid _uuid;

  Stream<List<TaskTemplate>> watchAll() => _store.watchAll();

  Future<List<TaskTemplate>> getAll() => _store.getAll();

  Future<TaskTemplate?> getById(String id) => _store.getById(id);

  Future<TaskTemplate> create({
    required String title,
    String? note,
    List<TaskAttachment> attachments = const [],
    TaskRecurrence recurrence = TaskRecurrence.none,
    DateTime? dailyUntil,
    DateTime? dueDate,
    List<String> subtaskTitles = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final template = TaskTemplate(
      id: _uuid.v4(),
      title: title.trim(),
      note: note?.trim(),
      attachments: attachments,
      recurrence: recurrence,
      dailyUntil: recurrence == TaskRecurrence.daily ? dailyUntil : null,
      dueDate: recurrence == TaskRecurrence.daily ? null : dueDate,
      subtaskTitles: subtaskTitles.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      createdAt: now,
      updatedAt: now,
      syncVersion: 1,
    );
    await _store.upsert(template);
    return template;
  }

  Future<TaskTemplate> update(TaskTemplate template) async {
    final updated = template.copyWith(
      updatedAt: DateTime.now().toUtc(),
      syncVersion: template.syncVersion + 1,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<void> upsertRemote(TaskTemplate template) async {
    await _store.upsert(template);
  }

  Future<void> delete(String id) => _store.delete(id);

  Future<TaskTemplate> saveFromTask(String taskId, {String? titleOverride}) async {
    final task = await _taskRepo.getById(taskId);
    if (task == null) throw StateError('Task not found: $taskId');

    final all = await _taskRepo.getAll();
    final subtaskTitles = all
        .where((t) => t.parentId == taskId && t.status != TaskStatus.trashed)
        .map((t) => t.title)
        .where((t) => t.trim().isNotEmpty)
        .toList();

    return create(
      title: titleOverride ?? task.title,
      note: task.note,
      attachments: task.attachments,
      recurrence: task.recurrence,
      dailyUntil: task.dailyUntil,
      dueDate: task.dueDate,
      subtaskTitles: subtaskTitles,
    );
  }

  Future<TaskTemplate> saveFromDraft({
    required String title,
    String? note,
    List<TaskAttachment> attachments = const [],
    TaskRecurrence recurrence = TaskRecurrence.none,
    DateTime? dailyUntil,
    DateTime? dueDate,
    List<String> subtaskTitles = const [],
    String? titleOverride,
  }) async {
    return create(
      title: titleOverride ?? title,
      note: note,
      attachments: attachments,
      recurrence: recurrence,
      dailyUntil: dailyUntil,
      dueDate: dueDate,
      subtaskTitles: subtaskTitles,
    );
  }

  Future<List<Task>> createTasksFromTemplate(String templateId) async {
    final template = await _store.getById(templateId);
    if (template == null) throw StateError('Template not found: $templateId');

    final parent = await _taskRepo.createInbox(
      title: template.title,
      note: template.note,
      attachments: List<TaskAttachment>.from(template.attachments),
      recurrence: template.recurrence,
      dailyUntil: template.dailyUntil,
      dueDate: template.dueDate,
    );

    final created = <Task>[parent];
    for (final subTitle in template.subtaskTitles) {
      if (subTitle.trim().isEmpty) continue;
      final sub = await _taskRepo.createSubtask(
        parentId: parent.id,
        title: subTitle,
      );
      created.add(sub);
    }
    return created;
  }
}

final templateRepositoryProvider = FutureProvider<TemplateRepository>((ref) async {
  final store = await ref.watch(templateStoreInitProvider.future);
  final taskRepo = await ref.watch(taskRepositoryProvider.future);
  return TemplateRepository(store, taskRepo, const Uuid());
});
