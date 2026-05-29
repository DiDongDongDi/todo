import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/stats/stats_provider.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';
import 'package:todo_app/shared/widgets/progress_widgets.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';

class ProcessScreen extends ConsumerStatefulWidget {
  const ProcessScreen({super.key});

  @override
  ConsumerState<ProcessScreen> createState() => _ProcessScreenState();
}

class _ProcessScreenState extends ConsumerState<ProcessScreen> {
  int _index = 0;
  bool _editing = false;
  final _editController = TextEditingController();
  Task? _lastUndoTask;
  TaskStatus? _lastUndoFrom;

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _undo() async {
    final task = _lastUndoTask;
    final from = _lastUndoFrom;
    if (task == null || from == null) return;
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.restoreToInbox(task.id);
    _lastUndoTask = null;
    _lastUndoFrom = null;
  }

  void _showUndoSnackbar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '撤销',
          onPressed: _undo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(inboxTasksProvider);
    final statsAsync = ref.watch(statsProvider);

    return inboxAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '收集箱是空的，去收集页记一条吧',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          );
        }

        if (_index >= tasks.length) _index = tasks.length - 1;
        if (_index < 0) _index = 0;
        final task = tasks[_index];
        final archivedToday = statsAsync.value?.archivedToday ?? 0;
        final streak = statsAsync.value?.streak ?? 0;
        final progress = inboxProgress(archivedToday, tasks.length);

        if (_editing && _editController.text != task.title) {
          _editController.text = task.title;
        }

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _trash(task),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _archive(task),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _move(-1, tasks.length),
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _move(1, tasks.length),
          },
          child: Focus(
            autofocus: true,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        ProcessProgressRing(
                          completed: archivedToday,
                          total: archivedToday + tasks.length,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${tasks.length} 待处理',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        StreakBadge(streak: streak),
                        IconButton(
                          icon: const Icon(Icons.inventory_2_outlined),
                          tooltip: '归档',
                          onPressed: () => context.push('/archive'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: '回收站',
                          onPressed: () => context.push('/trash'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.sync_outlined),
                          tooltip: '同步',
                          onPressed: () => context.push('/auth'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SwipeableCard(
                      onSwipeLeft: () => _trash(task),
                      onSwipeRight: () => _archive(task),
                      onSwipeUp: () async => _move(1, tasks.length),
                      onSwipeDown: () async => _move(-1, tasks.length),
                      child: GestureDetector(
                        onTap: () => _startEdit(task),
                        child: BigTaskCard(
                          mode: _editing
                              ? BigTaskCardMode.process
                              : BigTaskCardMode.readOnly,
                          task: task,
                          controller:
                              _editing ? _editController : null,
                          onChanged: _editing ? (_) => setState(() {}) : null,
                        ),
                      ),
                    ),
                  ),
                  if (_editing)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _editing = false),
                            child: const Text('取消'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => _saveEdit(task),
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '← 放弃   → 完成   ↑↓ 切换',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                      ),
                    ),
                  if (progress >= 1 && tasks.isNotEmpty)
                    const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _move(int delta, int length) {
    setState(() {
      _index = (_index + delta).clamp(0, length - 1);
      _editing = false;
    });
    AppHaptics.selection();
  }

  void _startEdit(Task task) {
    _editController.text = task.title;
    setState(() => _editing = true);
  }

  Future<void> _saveEdit(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.update(task.copyWith(title: _editController.text.trim()));
    setState(() => _editing = false);
  }

  Future<void> _archive(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.archive(task.id);
    await triggerSyncIfSignedIn(ref);
    await ref.read(statsProvider.notifier).recordArchive();
    _lastUndoTask = task;
    _lastUndoFrom = TaskStatus.archived;
    _showUndoSnackbar('已归档');
    if (mounted) {
      final remaining = (ref.read(inboxTasksProvider).value?.length ?? 1) - 1;
      if (remaining <= 0) showCelebrateOverlay(context);
    }
  }

  Future<void> _trash(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.trash(task.id);
    await triggerSyncIfSignedIn(ref);
    _lastUndoTask = task;
    _lastUndoFrom = TaskStatus.trashed;
    _showUndoSnackbar('已移至回收站');
  }
}
