import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/database/template_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_template.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:uuid/uuid.dart';

class _MemoryTemplateStore implements TemplateStore {
  final List<TaskTemplate> _templates = [];

  @override
  Future<void> init() async {}

  @override
  Future<List<TaskTemplate>> getAll() async => List.from(_templates);

  @override
  Stream<List<TaskTemplate>> watchAll() async* {
    yield await getAll();
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
  }

  @override
  Future<void> delete(String id) async {
    _templates.removeWhere((t) => t.id == id);
  }
}

class _MemoryTaskStore implements TaskStore {
  @override
  Future<void> init() async {}

  @override
  Future<List<Task>> getByStatus(TaskStatus status) async => [];

  @override
  Stream<List<Task>> watchByStatus(TaskStatus status) async* {
    yield [];
  }

  @override
  Future<Task?> getById(String id) async => null;

  @override
  Future<void> upsert(Task task) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Task>> getAll() async => [];
}

void main() {
  late _MemoryTemplateStore store;
  late TemplateRepository repo;

  setUp(() {
    store = _MemoryTemplateStore();
    repo = TemplateRepository(
      store,
      TaskRepository(_MemoryTaskStore(), const Uuid()),
      const Uuid(),
    );
  });

  test('findByTitle returns template with trimmed exact match', () async {
    await store.upsert(
      TaskTemplate(
        id: 'tpl-1',
        title: '周报模板',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    expect(await repo.findByTitle('周报模板'), isNotNull);
    expect(await repo.findByTitle('  周报模板  '), isNotNull);
    expect(await repo.findByTitle('其他'), isNull);
  });

  test('findByTitle excludes template by id', () async {
    await store.upsert(
      TaskTemplate(
        id: 'tpl-1',
        title: '周报模板',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    expect(
      await repo.findByTitle('周报模板', excludeId: 'tpl-1'),
      isNull,
    );
  });

  test('create without replaceTemplateId creates new template', () async {
    final created = await repo.create(title: '新模板');

    expect(created.title, '新模板');
    expect(created.syncVersion, 1);
    expect((await store.getAll()).length, 1);
  });

  test('create with replaceTemplateId updates existing in place', () async {
    await store.upsert(
      TaskTemplate(
        id: 'tpl-old',
        title: '旧模板',
        subtaskTitles: const ['旧子任务'],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        syncVersion: 3,
      ),
    );

    final replaced = await repo.create(
      title: '新模板',
      subtaskTitles: const ['新子任务'],
      replaceTemplateId: 'tpl-old',
    );

    expect(replaced.id, 'tpl-old');
    expect(replaced.title, '新模板');
    expect(replaced.subtaskTitles, ['新子任务']);
    expect(replaced.syncVersion, 4);
    expect(replaced.createdAt, DateTime.utc(2026, 1, 1));
    expect((await store.getAll()).length, 1);
  });

  test('create with missing replaceTemplateId falls back to new template',
      () async {
    final created = await repo.create(
      title: '新模板',
      replaceTemplateId: 'missing-id',
    );

    expect(created.title, '新模板');
    expect(created.id, isNot('missing-id'));
    expect((await store.getAll()).length, 1);
  });
}
