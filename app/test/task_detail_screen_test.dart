import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/task/$taskId'),
              child: const Text('Open task'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/task/:id',
        builder: (context, state) => TaskDetailScreen(
          taskId: state.pathParameters['id']!,
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWith((ref) async => repo),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open task'));
  await tester.pumpAndSettle();
}

Future<void> _tapComplete(WidgetTester tester) async {
  await tester.tap(
    find.widgetWithIcon(IconButton, Icons.check_circle_outline),
  );
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
}

Future<void> _flushSnackBarTimer(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  late TaskRepository repo;
  late String parentId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );

    repo = TaskRepository(_MemoryTaskStore(), const Uuid());
    final result = await repo.createInboxWithSubtasks(
      title: 'Parent task',
      subtaskTitles: ['Sub A', 'Sub B'],
    );
    parentId = result.parent.id;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      null,
    );
  });

  testWidgets('shows read-only subtask list with edit entry', (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    expect(find.text('父任务'), findsOneWidget);
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

    expect(find.text('任务详情'), findsOneWidget);
    expect(find.text('暂无子任务'), findsOneWidget);
    expect(find.text('添加子任务'), findsOneWidget);

    await tester.tap(find.text('添加子任务'));
    await tester.pumpAndSettle();

    expect(find.byType(SubtaskTitleEditor), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('edit task button enters parent task edit mode', (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    expect(find.text('编辑任务'), findsOneWidget);
    expect(find.text('Parent task'), findsOneWidget);

    await tester.tap(find.text('编辑任务'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('编辑子任务'), findsNothing);
  });

  testWidgets('save task edit persists title change', (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    await tester.tap(find.text('编辑任务'));
    await tester.pumpAndSettle();

    final titleField = find.byType(TextField);
    await tester.enterText(titleField, 'Updated parent');
    await tester.pump();
    expect(tester.widget<TextField>(titleField).controller!.text, 'Updated parent');

    await tester.runAsync(() async {
      await tester.tap(find.text('保存'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    final updated = await repo.getById(parentId);
    expect(updated?.title, 'Updated parent');
    expect(find.text('Updated parent'), findsOneWidget);
  });

  testWidgets('task edit and subtask edit are mutually exclusive', (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    await tester.tap(find.text('编辑子任务'));
    await tester.pumpAndSettle();

    expect(find.byType(SubtaskTitleEditor), findsOneWidget);

    await tester.tap(find.text('编辑任务'));
    await tester.pumpAndSettle();

    expect(find.byType(SubtaskTitleEditor), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('编辑子任务'), findsNothing);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('编辑子任务'), findsOneWidget);
    expect(find.byType(SubtaskListSection), findsOneWidget);
  });

  testWidgets('subtask detail shows subtask title and parent link', (tester) async {
    final subtasks = await repo.getSubtasks(parentId);
    expect(subtasks, isNotEmpty);

    await _pumpTaskDetail(tester, repo: repo, taskId: subtasks.first.id);

    expect(find.text('子任务'), findsOneWidget);
    expect(find.text('Parent task'), findsOneWidget);
    expect(find.text('Sub A'), findsOneWidget);
    expect(find.text('添加子任务'), findsNothing);
    expect(find.text('编辑子任务'), findsNothing);
    expect(find.byType(SubtaskListSection), findsNothing);
  });

  testWidgets('parent with someday-only subtasks shows parent title and list',
      (tester) async {
    final result = await repo.createInboxWithSubtasks(
      title: 'Proposal prep',
      subtaskTitles: ['Sub 1', 'Sub 2', 'Sub 3'],
    );
    for (final sub in result.subtasks) {
      await repo.moveToSomeday(sub.id);
    }

    await _pumpTaskDetail(tester, repo: repo, taskId: result.parent.id);

    expect(find.text('父任务'), findsOneWidget);
    expect(find.text('Sub 1'), findsOneWidget);
    expect(find.text('Sub 2'), findsOneWidget);
    expect(find.text('Sub 3'), findsOneWidget);
    expect(find.text('暂无子任务'), findsNothing);
    expect(find.byType(SubtaskListSection), findsOneWidget);
  });

  testWidgets('standalone task shows complete button and archives on tap',
      (tester) async {
    final task = await repo.createInbox(title: 'Standalone');

    await _pumpTaskDetail(tester, repo: repo, taskId: task.id);

    expect(find.byTooltip('完成'), findsOneWidget);

    await _tapComplete(tester);

    final updated = await repo.getById(task.id);
    expect(updated?.status, TaskStatus.archived);
    await _flushSnackBarTimer(tester);
  });

  testWidgets('parent task complete archives only parent', (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    expect(find.byTooltip('完成'), findsOneWidget);

    await _tapComplete(tester);

    final parent = await repo.getById(parentId);
    expect(parent?.status, TaskStatus.archived);
    final subtasks = await repo.getSubtasks(parentId);
    expect(subtasks.every((s) => s.status == TaskStatus.inbox), isTrue);
    await _flushSnackBarTimer(tester);
  });

  testWidgets('subtask complete archives only subtask', (tester) async {
    final subtasks = await repo.getSubtasks(parentId);
    expect(subtasks, isNotEmpty);

    await _pumpTaskDetail(tester, repo: repo, taskId: subtasks.first.id);

    expect(find.byTooltip('完成'), findsOneWidget);

    await _tapComplete(tester);

    final sub = await repo.getById(subtasks.first.id);
    expect(sub?.status, TaskStatus.archived);
    final parent = await repo.getById(parentId);
    expect(parent?.status, TaskStatus.inbox);
    await _flushSnackBarTimer(tester);
  });

  testWidgets('partial check-in stays on page and updates count', (tester) async {
    final task = await repo.createInbox(title: 'Workout', checkInTarget: 3);

    await _pumpTaskDetail(tester, repo: repo, taskId: task.id);

    expect(find.byTooltip('打卡'), findsOneWidget);

    await _tapComplete(tester);
    await tester.pumpAndSettle();

    final updated = await repo.getById(task.id);
    expect(updated?.status, TaskStatus.inbox);
    expect(updated?.checkInCount, 1);
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    expect(find.byTooltip('打卡'), findsOneWidget);
    await _flushSnackBarTimer(tester);
  });

  testWidgets('daily task completed today hides complete button', (tester) async {
    final task = await repo.createInbox(
      title: 'Daily',
      recurrence: TaskRecurrence.daily,
    );
    await repo.completeDailyToday(task.id);

    await _pumpTaskDetail(tester, repo: repo, taskId: task.id);

    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  testWidgets('edit mode hides complete button', (tester) async {
    await _pumpTaskDetail(tester, repo: repo, taskId: parentId);

    expect(find.byTooltip('完成'), findsOneWidget);

    await tester.tap(find.text('编辑任务'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('完成'), findsNothing);
    expect(find.byTooltip('删除'), findsNothing);
  });
}
