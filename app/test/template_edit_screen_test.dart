import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/database/template_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_template.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/features/templates/template_edit_screen.dart';
import 'package:todo_app/features/templates/template_list_screen.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';
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
    // Single-yield store: edits in tests do not need live stream updates.
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
  final List<Task> _tasks = [];

  @override
  Future<void> init() async {}

  @override
  Future<List<Task>> getByStatus(TaskStatus status) async {
    return _tasks
        .where((t) => t.status == status && t.deletedAt == null)
        .toList();
  }

  @override
  Stream<List<Task>> watchByStatus(TaskStatus status) async* {
    yield await getByStatus(status);
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
  }

  @override
  Future<void> delete(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<Task>> getAll() async => List.from(_tasks);

  @override
  Future<void> awaitPersisted() async {}
}

Future<void> _pumpTemplateEdit(
  WidgetTester tester, {
  required _MemoryTemplateStore templateStore,
  required String templateId,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/templates/$templateId',
    routes: [
      GoRoute(
        path: '/templates',
        builder: (context, state) => const TemplateListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => TemplateEditScreen(
              templateId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        templateStoreInitProvider.overrideWith((ref) async => templateStore),
        taskRepositoryProvider.overrideWith(
          (ref) async => TaskRepository(_MemoryTaskStore(), const Uuid()),
        ),
        templateRepositoryProvider.overrideWith((ref) async {
          final taskRepo = await ref.watch(taskRepositoryProvider.future);
          return TemplateRepository(templateStore, taskRepo, const Uuid());
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _MemoryTemplateStore templateStore;
  late TaskTemplate template;

  setUp(() async {
    templateStore = _MemoryTemplateStore();
    template = TaskTemplate(
      id: 'tpl-1',
      title: '示例模板',
      subtaskTitles: const ['子任务 A', '子任务 B'],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await templateStore.upsert(template);
  });

  testWidgets('template edit uses compact SubtaskTitleEditor styling',
      (tester) async {
    await _pumpTemplateEdit(
      tester,
      templateStore: templateStore,
      templateId: template.id,
    );

    expect(find.text('编辑模板'), findsOneWidget);
    expect(find.byType(SubtaskTitleEditor), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));

    final subtaskFields = find.descendant(
      of: find.byType(SubtaskTitleEditor),
      matching: find.byType(TextField),
    );
    expect(subtaskFields, findsNWidgets(2));

    final subtaskField = tester.widget<TextField>(subtaskFields.first);
    expect(subtaskField.decoration?.isDense, isTrue);
    expect(subtaskField.maxLines, 1);
  });

  testWidgets(
      'template edit toolbar shows schedule check-in image mic in one row',
      (tester) async {
    await _pumpTemplateEdit(
      tester,
      templateStore: templateStore,
      templateId: template.id,
    );

    expect(find.text('计划'), findsOneWidget);
    expect(find.text('打卡'), findsOneWidget);
    expect(find.byTooltip('添加图片'), findsOneWidget);
    expect(find.byTooltip('录音'), findsOneWidget);
  });

  testWidgets('save pops back to template list', (tester) async {
    await _pumpTemplateEdit(
      tester,
      templateStore: templateStore,
      templateId: template.id,
    );

    expect(find.text('编辑模板'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('编辑模板'), findsNothing);
    expect(find.text('任务模板'), findsOneWidget);
  });

  testWidgets('save with empty title stays on edit screen', (tester) async {
    await _pumpTemplateEdit(
      tester,
      templateStore: templateStore,
      templateId: template.id,
    );

    await tester.enterText(
      find.ancestor(
        of: find.text('标题'),
        matching: find.byType(TextField),
      ),
      '',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('编辑模板'), findsOneWidget);
    expect(find.text('请输入模板标题'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('rename to duplicate title without confirm keeps conflict template',
      (tester) async {
    await templateStore.upsert(
      TaskTemplate(
        id: 'tpl-2',
        title: '冲突名称',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    );

    await _pumpTemplateEdit(
      tester,
      templateStore: templateStore,
      templateId: template.id,
    );

    await tester.enterText(
      find.ancestor(
        of: find.text('标题'),
        matching: find.byType(TextField),
      ),
      '冲突名称',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('替换模板'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('编辑模板'), findsOneWidget);
    expect(await templateStore.getById('tpl-2'), isNotNull);
  });

  testWidgets('rename to duplicate title with confirm deletes conflict template',
      (tester) async {
    await templateStore.upsert(
      TaskTemplate(
        id: 'tpl-2',
        title: '冲突名称',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    );

    await _pumpTemplateEdit(
      tester,
      templateStore: templateStore,
      templateId: template.id,
    );

    await tester.enterText(
      find.ancestor(
        of: find.text('标题'),
        matching: find.byType(TextField),
      ),
      '冲突名称',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('替换模板'), findsOneWidget);

    await tester.tap(find.text('替换'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(await templateStore.getById('tpl-2'), isNull);
    final updated = await templateStore.getById('tpl-1');
    expect(updated?.title, '冲突名称');
  });
}
