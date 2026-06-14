import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/ai/recommend_service.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/limits/resource_limits.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/navigation/shell_navigation.dart';
import 'package:todo_app/core/repositories/playlist_repository.dart';
import 'package:todo_app/core/repositories/task_repository.dart';
import 'package:todo_app/core/settings/process_queue_source_settings.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/layout/app_layout.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';
import 'package:todo_app/shared/widgets/save_playlist_dialog.dart';
import 'package:todo_app/shared/widgets/tab_page_header.dart';
import 'package:todo_app/shared/widgets/task_multi_select_sheet.dart';

class AskAiScreen extends ConsumerStatefulWidget {
  const AskAiScreen({super.key});

  @override
  ConsumerState<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends ConsumerState<AskAiScreen> {
  final _queryController = TextEditingController();
  bool _loading = false;
  bool _cooldown = false;
  RecommendResult? _result;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || _cooldown) return;
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
        _cooldown = true;
      });
      Future<void>.delayed(
        const Duration(milliseconds: ResourceLimits.aiSubmitCooldownMs),
        () {
          if (mounted) setState(() => _cooldown = false);
        },
      );
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
  }

  Future<void> _savePlaylistFromResult() async {
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
    showAppSnackBar(
      context,
      message: '已保存任务清单',
      icon: Icons.playlist_add_check_outlined,
      type: AppSnackType.success,
    );
  }

  Future<void> _createPlaylistManually() async {
    final inbox = ref.read(inboxTasksProvider).value ?? [];
    final someday = ref.read(somedayTasksProvider).value ?? [];
    final selectable = [
      ...inbox.where((t) => t.parentId == null),
      ...someday.where((t) => t.parentId == null),
    ];
    if (selectable.isEmpty) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '收集箱和将来也许中暂无任务',
        icon: Icons.info_outline,
        type: AppSnackType.info,
      );
      return;
    }

    final selected = await showTaskMultiSelectSheet(
      context,
      tasks: selectable,
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    final name = await showSavePlaylistDialog(context, defaultTitle: '我的清单');
    if (name == null || !mounted) return;

    final repo = await ref.read(playlistRepositoryProvider.future);
    final playlist = await repo.createFromTaskIds(
      title: name,
      taskIds: selected.map((t) => t.id).toList(),
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
    showAppSnackBar(
      context,
      message: '已创建任务清单',
      icon: Icons.playlist_add_check_outlined,
      type: AppSnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = AuthService.instance.isSignedIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabPageHeader(title: '问 AI'),
        Expanded(
          child: ListView(
            padding: AppLayout.cardPadding.copyWith(top: 20, bottom: 24),
            children: [
              Text(
                '描述你的想法和需求，AI 将从收集箱和将来也许中推荐合适的任务。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _createPlaylistManually,
                icon: const Icon(Icons.playlist_add),
                label: const Text('手动创建任务清单'),
              ),
              const SizedBox(height: 24),
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
                maxLength: ResourceLimits.aiQueryMaxLength,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: '例如：今天想整理一下家里，有什么适合做的？',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: signedIn && !_loading && !_cooldown ? _submit : null,
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
                    onPressed: _savePlaylistFromResult,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('生成任务清单'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
