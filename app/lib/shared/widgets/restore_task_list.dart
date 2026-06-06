import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/swipeable_restore_tile.dart';

class RestoreTaskListView extends ConsumerStatefulWidget {
  const RestoreTaskListView({
    super.key,
    required this.tasksProvider,
    required this.emptyMessage,
    this.restoreIcon = Icons.undo,
    this.restoreTooltip = '恢复到收集箱',
  });

  final StreamProvider<List<Task>> tasksProvider;
  final String emptyMessage;
  final IconData restoreIcon;
  final String restoreTooltip;

  @override
  ConsumerState<RestoreTaskListView> createState() => _RestoreTaskListViewState();
}

class _RestoreTaskListViewState extends ConsumerState<RestoreTaskListView>
    with SingleTickerProviderStateMixin {
  static const _separatorHeight = 8.0;
  static const _defaultRowHeight = 72.0;
  static const _staggerDelay = Duration(milliseconds: 45);
  static const _slideDuration = Duration(milliseconds: 200);

  final _rowKeys = <String, GlobalKey>{};
  late final AnimationController _removalController;

  List<Task> _tasks = [];
  int? _removingIndex;
  double _removedRowHeight = _defaultRowHeight;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _removalController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _removalController.dispose();
    super.dispose();
  }

  void _syncTasks(List<Task> tasks) {
    if (_removing) return;
    setState(() => _tasks = List.from(tasks));
  }

  double _measureRowHeight(int index) {
    final task = _tasks[index];
    final key = _rowKeys[task.id];
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.size.height;
    }
    return _defaultRowHeight;
  }

  double _collapseHeightFactor(double t) {
    const collapsePortion = 0.35;
    final local = (t / collapsePortion).clamp(0.0, 1.0);
    return 1 - Curves.easeInCubic.transform(local);
  }

  double _upwardOffset(int index, double t) {
    if (_removingIndex == null || index <= _removingIndex!) return 0;

    final rank = index - _removingIndex! - 1;
    final belowCount = _tasks.length - _removingIndex! - 1;
    if (belowCount <= 0) return 0;

    final stride = _removedRowHeight + _separatorHeight;
    final totalMs = _slideDuration.inMilliseconds +
        _staggerDelay.inMilliseconds * belowCount;
    final startMs =
        _slideDuration.inMilliseconds * 0.2 + rank * _staggerDelay.inMilliseconds;
    final currentMs = t * totalMs;
    final local =
        ((currentMs - startMs) / _slideDuration.inMilliseconds).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local) * stride;
  }

  Future<void> _handleRestore(int index) async {
    if (_removing || index < 0 || index >= _tasks.length) return;

    final task = _tasks[index];
    final belowCount = _tasks.length - index - 1;
    _removedRowHeight = _measureRowHeight(index);

    setState(() {
      _removing = true;
      _removingIndex = index;
    });

    _removalController.duration = Duration(
      milliseconds:
          _slideDuration.inMilliseconds + _staggerDelay.inMilliseconds * belowCount,
    );
    await _removalController.forward(from: 0);

    if (!mounted) return;

    setState(() {
      _tasks.removeAt(index);
      _removingIndex = null;
      _removing = false;
    });
    _removalController.reset();
    _rowKeys.remove(task.id);

    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.restoreToInbox(task.id);
    await triggerSyncIfSignedIn(ref);

    if (!mounted) return;
    showAppSnackBar(
      context,
      message: '已恢复',
      icon: Icons.check_circle_outline,
      type: AppSnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(widget.tasksProvider);

    ref.listen(widget.tasksProvider, (previous, next) {
      next.whenData(_syncTasks);
    });

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (tasks) {
        if (_tasks.isEmpty && tasks.isNotEmpty && !_removing) {
          _tasks = List.from(tasks);
        }

        if (_tasks.isEmpty) {
          return Center(child: Text(widget.emptyMessage));
        }

        return AnimatedBuilder(
          animation: _removalController,
          builder: (context, _) {
            final t = _removalController.value;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                _rowKeys.putIfAbsent(task.id, GlobalKey.new);

                final isRemoving = _removingIndex == index;
                final upwardOffset = _upwardOffset(index, t);

                Widget row = SwipeableRestoreTile(
                  key: _rowKeys[task.id],
                  task: task,
                  restoreIcon: widget.restoreIcon,
                  restoreTooltip: widget.restoreTooltip,
                  onRestore: () => _handleRestore(
                    _tasks.indexWhere((t) => t.id == task.id),
                  ),
                );

                if (isRemoving) {
                  row = ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: _collapseHeightFactor(t),
                      child: row,
                    ),
                  );
                } else if (upwardOffset > 0) {
                  row = Transform.translate(
                    offset: Offset(0, -upwardOffset),
                    child: row,
                  );
                }

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _tasks.length - 1 ? _separatorHeight : 0,
                  ),
                  child: row,
                );
              },
            );
          },
        );
      },
    );
  }
}
