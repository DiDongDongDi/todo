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

class _RestoreTaskListViewState extends ConsumerState<RestoreTaskListView> {
  static const _separatorHeight = 8.0;
  static const _defaultRowHeight = 72.0;
  static const _collapseDuration = Duration(milliseconds: 260);

  final _listKey = GlobalKey<AnimatedListState>();
  final _rowKeys = <String, GlobalKey>{};

  List<Task> _tasks = [];
  bool _removing = false;

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

  Future<void> _handleRestore(int index) async {
    if (_removing || index < 0 || index >= _tasks.length) return;

    final task = _tasks[index];
    final rowHeight = _measureRowHeight(index);
    final slotHeight = rowHeight +
        (index < _tasks.length - 1 ? _separatorHeight : 0);

    setState(() {
      _removing = true;
      _tasks.removeAt(index);
    });

    _listKey.currentState!.removeItem(
      index,
      (context, animation) => _buildCollapseSlot(slotHeight, animation),
      duration: _collapseDuration,
    );

    await Future<void>.delayed(_collapseDuration);

    if (!mounted) return;

    setState(() => _removing = false);
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

  Widget _buildCollapseSlot(double height, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: -1,
      child: SizedBox(height: height),
    );
  }

  Widget _buildRow(Task task, int index) {
    _rowKeys.putIfAbsent(task.id, GlobalKey.new);

    return Padding(
      padding: EdgeInsets.only(
        bottom: index < _tasks.length - 1 ? _separatorHeight : 0,
      ),
      child: SwipeableRestoreTile(
        key: _rowKeys[task.id],
        task: task,
        restoreIcon: widget.restoreIcon,
        restoreTooltip: widget.restoreTooltip,
        onRestore: () => _handleRestore(
          _tasks.indexWhere((t) => t.id == task.id),
        ),
      ),
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

        return AnimatedList(
          key: _listKey,
          padding: const EdgeInsets.all(16),
          initialItemCount: _tasks.length,
          itemBuilder: (context, index, animation) {
            if (index >= _tasks.length) {
              return const SizedBox.shrink();
            }
            return _buildRow(_tasks[index], index);
          },
        );
      },
    );
  }
}
