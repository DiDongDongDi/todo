import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/database/task_store.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/features/process/process_screen.dart';
import 'package:uuid/uuid.dart';

/// 任务变化时 watchByStatus 会重新发射的内存版 TaskStore。
class _ReactiveTaskStore implements TaskStore {
  final List<Task> _tasks = [];
  final _changes = StreamController<void>.broadcast();

  @override
  Future<void> init() async {}

  List<Task> _byStatus(TaskStatus status) {
    final list = _tasks
        .where((t) => t.status == status && t.deletedAt == null)
        .toList();
    if (status == TaskStatus.inbox) {
      list.sort((a, b) {
        final order = b.sortOrder.compareTo(a.sortOrder);
        if (order != 0) return order;
        return b.createdAt.compareTo(a.createdAt);
      });
    }
    return list;
  }

  @override
  Future<List<Task>> getByStatus(TaskStatus status) async => _byStatus(status);

  @override
  Stream<List<Task>> watchByStatus(TaskStatus status) async* {
    yield await getByStatus(status);
    await for (final _ in _changes.stream) {
      yield await getByStatus(status);
    }
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
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    _changes.add(null);
  }

  @override
  Future<List<Task>> getAll() async => List.from(_tasks);

  @override
  Future<void> awaitPersisted() async {}
}

Task _inboxTask(String id, String title, double sortOrder) {
  final now = DateTime(2026, 11, 1);
  return Task(
    id: id,
    title: title,
    status: TaskStatus.inbox,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpProcessScreen(WidgetTester tester, TaskStore store) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [taskStoreInitProvider.overrideWith((ref) async => store)],
      child: const MaterialApp(home: Scaffold(body: ProcessScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      null,
    );
  });

  testWidgets('新任务入队后处理页卡片停留在当前任务', (tester) async {
    final store = _ReactiveTaskStore();
    // sortOrder 大者在前：队列顺序为 任务C、任务B、任务A。
    await store.upsert(_inboxTask('a', '任务A', 10));
    await store.upsert(_inboxTask('b', '任务B', 20));
    await store.upsert(_inboxTask('c', '任务C', 30));

    await _pumpProcessScreen(tester, store);
    expect(find.text('任务C'), findsOneWidget);

    // 切到下一条（index 1 → 任务B）。
    await tester.tap(find.byTooltip('下一条'));
    await tester.pumpAndSettle();
    expect(find.text('任务B'), findsOneWidget);

    // 新任务从收集页入队：sortOrder 最大，插到队首并使队列整体后移。
    final repo = TaskRepository(store, const Uuid());
    await repo.createInbox(title: '任务X');

    await tester.pumpAndSettle();

    // 卡片仍停留在任务B，而不是被顶到上一张（任务C）。
    expect(find.text('任务B'), findsOneWidget);
    expect(find.text('任务C'), findsNothing);
  });

  testWidgets('完成当前任务后仍展示下一条任务', (tester) async {
    final store = _ReactiveTaskStore();
    await store.upsert(_inboxTask('a', '任务A', 10));
    await store.upsert(_inboxTask('b', '任务B', 20));
    await store.upsert(_inboxTask('c', '任务C', 30));

    await _pumpProcessScreen(tester, store);

    await tester.tap(find.byTooltip('下一条'));
    await tester.pumpAndSettle();
    expect(find.text('任务B'), findsOneWidget);

    // 完成任务B后队列变为 任务C、任务A，应展示下一条任务A。
    // 注：FilledButton.icon 的运行时类型是 _FilledButtonWithIcon，
    // byType 精确匹配找不到，改用图标定位（该图标在树中唯一）。
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('任务A'), findsOneWidget);
    expect(find.text('任务B'), findsNothing);

    // 等撤销 SnackBar 的 3 秒计时器走完，避免测试结束时存在 pending timer。
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
