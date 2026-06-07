import 'dart:async';
import 'dart:convert';

import 'package:todo_app/core/models/task_template.dart';

abstract class TemplateStore {
  Future<void> init();
  Future<List<TaskTemplate>> getAll();
  Stream<List<TaskTemplate>> watchAll();
  Future<TaskTemplate?> getById(String id);
  Future<void> upsert(TaskTemplate template);
  Future<void> delete(String id);
}

class JsonTemplateStore implements TemplateStore {
  JsonTemplateStore({
    required Future<void> Function(String json) persist,
    required Future<String?> Function() load,
  })  : _persist = persist,
        _load = load;

  final Future<void> Function(String json) _persist;
  final Future<String?> Function() _load;

  final List<TaskTemplate> _templates = [];
  final _changeController = StreamController<void>.broadcast();
  Future<void>? _saveInFlight;

  @override
  Future<void> init() async {
    final raw = await _load();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      _templates
        ..clear()
        ..addAll(
          list.map(
            (e) => TaskTemplate.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    }
  }

  @override
  Future<List<TaskTemplate>> getAll() async {
    final list = List<TaskTemplate>.from(_templates)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Stream<List<TaskTemplate>> watchAll() async* {
    yield await getAll();
    await for (final _ in _changeController.stream) {
      yield await getAll();
    }
  }

  @override
  Future<TaskTemplate?> getById(String id) async {
    try {
      return _templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(TaskTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      _templates[index] = template;
    } else {
      _templates.add(template);
    }
    _notifyChanged();
  }

  @override
  Future<void> delete(String id) async {
    _templates.removeWhere((t) => t.id == id);
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

  Future<void> _save() async {
    final json = jsonEncode(_templates.map((t) => t.toJson()).toList());
    await _persist(json);
  }

  void dispose() => _changeController.close();
}
