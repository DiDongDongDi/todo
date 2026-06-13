import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/ai/recommend_service.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/navigation/shell_navigation.dart';
import 'package:todo_app/core/repositories/playlist_repository.dart';
import 'package:todo_app/core/settings/process_queue_source_settings.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/save_playlist_dialog.dart';

Future<void> showAskAiSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => const _AskAiSheet(),
  );
}

class _AskAiSheet extends ConsumerStatefulWidget {
  const _AskAiSheet();

  @override
  ConsumerState<_AskAiSheet> createState() => _AskAiSheetState();
}

class _AskAiSheetState extends ConsumerState<_AskAiSheet> {
  final _queryController = TextEditingController();
  bool _loading = false;
  RecommendResult? _result;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result =
          await ref.read(recommendServiceProvider).recommend(_queryController.text);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on RecommendException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '推荐失败，请稍后重试';
        _loading = false;
      });
    }
  }

  void _jumpToTask(Task task) {
    final queueSource = task.status == TaskStatus.someday
        ? const ProcessQueueSource(kind: ProcessQueueKind.someday)
        : const ProcessQueueSource.inbox();

    ref.read(shellTabIndexProvider.notifier).state = 1;
    ref.read(processNavigationIntentProvider.notifier).state =
        ProcessNavigationIntent(queueSource: queueSource, taskId: task.id);

    Navigator.pop(context);
  }

  Future<void> _savePlaylist() async {
    final result = _result;
    if (result == null || result.recommendedTasks.isEmpty) return;

    final name = await showSavePlaylistDialog(
      context,
      defaultTitle: result.suggestedPlaylistName,
    );
    if (name == null || !mounted) return;

    final repo = await ref.read(playlistRepositoryProvider.future);
    final playlist = await repo.createFromTaskIds(
      title: name,
      taskIds: result.recommendedTasks.map((t) => t.id).toList(),
      sourceQuery: _queryController.text.trim(),
    );
    unawaited(triggerSyncIfSignedIn(ref));

    await ref.read(processQueueSourceProvider.notifier).setSource(
          ProcessQueueSource(
            kind: ProcessQueueKind.playlist,
            playlistId: playlist.id,
          ),
        );

    ref.read(shellTabIndexProvider.notifier).state = 1;

    if (!mounted) return;
    Navigator.pop(context);
    showAppSnackBar(
      context,
      message: '已保存任务清单',
      icon: Icons.playlist_add_check_outlined,
      type: AppSnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final signedIn = AuthService.instance.isSignedIn;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text('问 AI', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '描述你的想法和需求，AI 将从收集箱和将来也许中推荐合适的任务。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (!signedIn)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '请先登录以使用 AI 推荐功能。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              TextField(
                controller: _queryController,
                enabled: signedIn && !_loading,
                maxLines: 4,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: '例如：今天想整理一下家里，有什么适合做的？',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: signedIn && !_loading ? _submit : null,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading ? '正在推荐…' : '获取推荐'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 20),
                Text('AI 推荐', style: theme.textTheme.titleMedium),
                if (_result!.summary != null) ...[
                  const SizedBox(height: 4),
                  Text(_result!.summary!, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 8),
                if (_result!.recommendedTasks.isEmpty)
                  Text(
                    '没有找到匹配的任务，试试换个描述？',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  ..._result!.recommendedTasks.map(
                    (task) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.task_alt_outlined),
                      title: Text(task.title),
                      subtitle: Text(
                        task.status == TaskStatus.someday ? '将来也许' : '收集箱',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _jumpToTask(task),
                    ),
                  ),
                if (_result!.recommendedTasks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _savePlaylist,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('生成任务清单'),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
