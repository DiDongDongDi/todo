import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/stats/stats_provider.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/utils/haptics.dart';
import 'package:todo_app/shared/utils/platform_capabilities.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';
import 'package:todo_app/shared/widgets/progress_widgets.dart';
import 'package:todo_app/shared/widgets/swipeable_card.dart';
import 'package:todo_app/shared/widgets/task_action_bar.dart';

class ProcessScreen extends ConsumerStatefulWidget {
  const ProcessScreen({super.key});

  @override
  ConsumerState<ProcessScreen> createState() => _ProcessScreenState();
}

class _ProcessScreenState extends ConsumerState<ProcessScreen> {
  int _index = 0;
  bool _editing = false;
  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();
  final _swipeKey = GlobalKey<SwipeableCardState>();
  Task? _lastUndoTask;
  TaskStatus? _lastUndoFrom;

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
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

  void _showUndoSnackbar({
    required String message,
    required IconData icon,
    required AppSnackType type,
  }) {
    showAppSnackBar(
      context,
      message: message,
      icon: icon,
      type: type,
      action: SnackBarAction(
        label: '撤销',
        onPressed: _undo,
      ),
    );
  }

  Widget _buildHint(BuildContext context, String text) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(inboxTasksProvider);
    final statsAsync = ref.watch(statsProvider);
    final touchFirst = isTouchFirstPlatform;

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

        final clampedIndex = _index.clamp(0, tasks.length - 1);
        if (clampedIndex != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index = clampedIndex);
          });
        }
        final task = tasks[clampedIndex];
        final archivedToday = statsAsync.value?.archivedToday ?? 0;
        final streak = statsAsync.value?.streak ?? 0;
        final progress = inboxProgress(archivedToday, tasks.length);

        final shortcuts = _editing
            ? {
                const SingleActivator(LogicalKeyboardKey.enter): () =>
                    _saveEdit(task),
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    setState(() => _editing = false),
              }
            : {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _trash(task),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _archive(task),
                const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                    _move(-1, tasks.length),
                const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                    _move(1, tasks.length),
              };

        return CallbackShortcuts(
          bindings: shortcuts,
          child: Focus(
            autofocus: !_editing,
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
                          icon: const Icon(Icons.task_alt_outlined),
                          tooltip: '已完成',
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
                      key: _swipeKey,
                      enabled: touchFirst && !_editing,
                      onSwipeLeft: () => _trash(task),
                      onSwipeRight: () => _archive(task),
                      onSwipeUp: () async =>
                          _move(1, tasks.length, animated: false),
                      onSwipeDown: () async =>
                          _move(-1, tasks.length, animated: false),
                      child: GestureDetector(
                        onTap: _editing ? null : () => _startEdit(task),
                        child: BigTaskCard(
                          mode: _editing
                              ? BigTaskCardMode.process
                              : BigTaskCardMode.readOnly,
                          task: task,
                          controller: _editing ? _editController : null,
                          focusNode: _editing ? _editFocusNode : null,
                          onChanged: _editing ? (_) => setState(() {}) : null,
                        ),
                      ),
                    ),
                  ),
                  if (!_editing)
                    touchFirst
                        ? _buildHint(context, '← 放弃   → 完成   ↑↓ 切换')
                        : _buildHint(context, '方向键或下方按钮操作'),
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
                  else if (!touchFirst)
                    TaskActionBar(
                      onTrash: () => _trash(task),
                      onComplete: () => _archive(task),
                      onPrevious: () => _move(-1, tasks.length),
                      onNext: () => _move(1, tasks.length),
                      canGoPrevious: clampedIndex > 0,
                      canGoNext: clampedIndex < tasks.length - 1,
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

  Future<void> _move(int delta, int length, {bool animated = true}) async {
    final newIndex = (_index + delta).clamp(0, length - 1);
    if (newIndex == _index) return;

    Future<void> applyMove() async {
      setState(() {
        _index = newIndex;
        _editing = false;
      });
    }

    if (animated && (delta == 1 || delta == -1)) {
      final flyout =
          delta > 0 ? const Offset(0, -1.5) : const Offset(0, 1.5);
      await _swipeKey.currentState?.animateFlyout(flyout, applyMove);
    } else {
      await applyMove();
    }
    AppHaptics.selection();
  }

  void _startEdit(Task task) {
    _editController.text = task.title;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
    });
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
    _showUndoSnackbar(
      message: '已完成',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
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
    _showUndoSnackbar(
      message: '已移至回收站',
      icon: Icons.delete_outline,
      type: AppSnackType.error,
    );
  }
}
