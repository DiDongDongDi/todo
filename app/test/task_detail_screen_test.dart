import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/features/task_detail/task_detail_screen.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';
import 'package:uuid/uuid.dart';

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
}

Future<void> _pumpTaskDetail(
  WidgetTester tester, {
  required TaskRepository repo,
  required String taskId,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWith((ref) async => repo),
      ],
      child: MaterialApp(
        home: TaskDetailScreen(taskId: taskId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late TaskRepository repo;
  late String parentId;

  setUp(() async {
    repo = TaskRepository(_MemoryTaskStore(), const Uuid());
    final result = await repo.createInboxWithSubtasks(
      title: 'Parent task',
      subtaskTitles: ['Sub A', 'Sub B'],
    );
    parentId = result.parent.id;
  });

  testWidgets('shows read-only subtask list with edit entry', (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    expect(find.byType(SubtaskListSection), findsOneWidget);
    expect(find.text('Sub A'), findsOneWidget);
    expect(find.text('Sub B'), findsOneWidget);
    expect(find.text('编辑子任务'), findsOneWidget);
    expect(find.byType(SubtaskTitleEditor), findsNothing);
  });

  testWidgets('entering edit mode renders SubtaskTitleEditor with existing titles',
      (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    await tester.tap(find.text('编辑子任务'));
    await tester.pumpAndSettle();

    expect(find.byType(SubtaskTitleEditor), findsOneWidget);
    expect(find.byType(SubtaskListSection), findsNothing);
    expect(find.text('Sub A'), findsOneWidget);
    expect(find.text('Sub B'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('remove button drops draft row without persisting trash',
      (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    await tester.tap(find.text('编辑子任务'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    final subtasks = await repo.getSubtasks(parentId);
    expect(subtasks.length, 2);
  });

  testWidgets('cancel restores read-only subtask list', (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    await tester.tap(find.text('编辑子任务'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byType(SubtaskListSection), findsOneWidget);
    expect(find.text('Sub A'), findsOneWidget);
    expect(find.text('Sub B'), findsOneWidget);
    expect(find.byType(SubtaskTitleEditor), findsNothing);
  });

  testWidgets('save applies create update and trash diff', (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    await tester.tap(find.text('编辑子任务'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sub B updated');

    await tester.tap(find.byTooltip('添加子任务'));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.length, 2);

    await tester.enterText(find.byType(TextField).last, 'Sub C');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    final subtasks = await repo.getSubtasks(parentId);
    expect(subtasks.map((t) => t.title), containsAll(['Sub B updated', 'Sub C']));
    expect(subtasks.map((t) => t.title), isNot(contains('Sub A')));

    expect(find.byType(SubtaskListSection), findsOneWidget);
    expect(find.text('Sub B updated'), findsOneWidget);
    expect(find.text('Sub C'), findsOneWidget);
    expect(find.text('Sub A'), findsNothing);
  });

  testWidgets('empty parent shows add subtask entry that opens editor',
      (tester) async {
    final emptyParent = await repo.createInbox(title: 'Empty parent');

    await _pumpTaskDetail(tester, repo: repo, taskId: emptyParent.id);

    expect(find.text('暂无子任务'), findsOneWidget);
    expect(find.text('添加子任务'), findsOneWidget);

    await tester.tap(find.text('添加子任务'));
    await tester.pumpAndSettle();

    expect(find.byType(SubtaskTitleEditor), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
