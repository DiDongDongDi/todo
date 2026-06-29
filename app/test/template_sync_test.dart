import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/database/template_store.dart';
import 'package:todo_app/core/models/task_template.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/sync/template_sync_merge.dart';
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

class _StubTaskRepository implements TaskRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _MemoryTemplateStore store;
  late TemplateRepository repo;

  setUp(() {
    store = _MemoryTemplateStore();
    repo = TemplateRepository(store, _StubTaskRepository(), const Uuid());
  });

  test('soft delete hides template from getAll but keeps tombstone for sync', () async {
    final template = await repo.create(title: 'Morning routine');
    await repo.delete(template.id);

    expect(await repo.getAll(), isEmpty);
    expect(await repo.getById(template.id), isNull);

    final forSync = await repo.getAllForSync();
    expect(forSync.length, 1);
    expect(forSync.first.id, template.id);
    expect(forSync.first.deletedAt, isNotNull);
    expect(forSync.first.syncVersion, template.syncVersion + 1);
  });

  test('deletedAt round-trips through JSON', () {
    final now = DateTime.utc(2026, 6, 29, 12);
    final template = TaskTemplate(
      id: 't1',
      title: 'Test',
      createdAt: now,
      updatedAt: now,
      deletedAt: now,
      syncVersion: 2,
    );

    final json = template.toJson();
    expect(json['deleted_at'], now.toIso8601String());

    final parsed = TaskTemplate.fromJson(json);
    expect(parsed.deletedAt, now);
  });

  test('merge does not restore locally deleted template from stale remote', () async {
    final template = await repo.create(title: 'Weekly review');
    final staleRemote = template;

    await repo.delete(template.id);

    await mergeRemoteTaskTemplates(repo, [staleRemote]);

    expect(await repo.getAll(), isEmpty);
    final tombstone = (await repo.getAllForSync()).single;
    expect(tombstone.deletedAt, isNotNull);
  });

  test('merge applies remote deletion to local active template', () async {
    final template = await repo.create(title: 'Daily standup');
    final deletedRemote = template.copyWith(
      deletedAt: DateTime.utc(2026, 6, 29, 13),
      updatedAt: DateTime.utc(2026, 6, 29, 13),
      syncVersion: template.syncVersion + 1,
    );

    await mergeRemoteTaskTemplates(repo, [deletedRemote]);

    expect(await repo.getAll(), isEmpty);
    final tombstone = (await repo.getAllForSync()).single;
    expect(tombstone.deletedAt, isNotNull);
  });
}
