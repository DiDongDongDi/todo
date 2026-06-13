import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/models/task_playlist.dart';
import 'package:todo_app/core/repositories/playlist_repository.dart';
import 'package:todo_app/core/settings/process_queue_source_settings.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

class ProcessQueueSelector extends ConsumerWidget {
  const ProcessQueueSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceAsync = ref.watch(processQueueSourceProvider);
    final playlistsAsync = ref.watch(playlistsProvider);
    final source = sourceAsync.value ?? const ProcessQueueSource.inbox();
    final playlists = playlistsAsync.value ?? [];

    String? playlistTitle;
    if (source.kind == ProcessQueueKind.playlist && source.playlistId != null) {
      for (final p in playlists) {
        if (p.id == source.playlistId) {
          playlistTitle = p.title;
          break;
        }
      }
    }

    final label = source.displayLabel(playlistTitle: playlistTitle);

    return TextButton.icon(
      onPressed: sourceAsync.isLoading
          ? null
          : () => _openSelector(context, ref, source, playlists),
      icon: const Icon(Icons.filter_list, size: 18),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        maximumSize: const Size(160, 40),
      ),
    );
  }

  Future<void> _openSelector(
    BuildContext context,
    WidgetRef ref,
    ProcessQueueSource current,
    List<TaskPlaylist> playlists,
  ) async {
    final selected = await showModalBottomSheet<_QueueSelection>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _ProcessQueueSheet(
        current: current,
        playlists: playlists,
      ),
    );
    if (selected == null || !context.mounted) return;

    if (selected.deletePlaylistId != null) {
      final repo = await ref.read(playlistRepositoryProvider.future);
      await repo.delete(selected.deletePlaylistId!);
      unawaited(triggerSyncIfSignedIn(ref));
      if (current.kind == ProcessQueueKind.playlist &&
          current.playlistId == selected.deletePlaylistId) {
        await ref
            .read(processQueueSourceProvider.notifier)
            .setSource(const ProcessQueueSource.inbox());
      }
      return;
    }

    if (selected.renamePlaylist != null) {
      final entry = selected.renamePlaylist!;
      final repo = await ref.read(playlistRepositoryProvider.future);
      await repo.rename(entry.id, entry.title);
      unawaited(triggerSyncIfSignedIn(ref));
      return;
    }

    if (selected.source != null) {
      await ref.read(processQueueSourceProvider.notifier).setSource(selected.source!);
    }
  }
}

class _QueueSelection {
  const _QueueSelection({
    this.source,
    this.deletePlaylistId,
    this.renamePlaylist,
  });

  final ProcessQueueSource? source;
  final String? deletePlaylistId;
  final ({String id, String title})? renamePlaylist;
}

class _ProcessQueueSheet extends StatelessWidget {
  const _ProcessQueueSheet({
    required this.current,
    required this.playlists,
  });

  final ProcessQueueSource current;
  final List<TaskPlaylist> playlists;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('选择处理队列', style: theme.textTheme.titleMedium),
          ),
          _QueueTile(
            label: '收集箱',
            icon: Icons.inbox_outlined,
            selected: current.kind == ProcessQueueKind.inbox,
            onTap: () => Navigator.pop(
              context,
              const _QueueSelection(source: ProcessQueueSource.inbox()),
            ),
          ),
          _QueueTile(
            label: '每日任务',
            icon: Icons.today_outlined,
            selected: current.kind == ProcessQueueKind.daily,
            onTap: () => Navigator.pop(
              context,
              const _QueueSelection(
                source: ProcessQueueSource(kind: ProcessQueueKind.daily),
              ),
            ),
          ),
          _QueueTile(
            label: '将来也许',
            icon: Icons.lightbulb_outline,
            selected: current.kind == ProcessQueueKind.someday,
            onTap: () => Navigator.pop(
              context,
              const _QueueSelection(
                source: ProcessQueueSource(kind: ProcessQueueKind.someday),
              ),
            ),
          ),
          if (playlists.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('任务清单', style: theme.textTheme.labelLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final playlist in playlists)
                    _PlaylistTile(
                      playlist: playlist,
                      selected: current.kind == ProcessQueueKind.playlist &&
                          current.playlistId == playlist.id,
                      onSelect: () => Navigator.pop(
                        context,
                        _QueueSelection(
                          source: ProcessQueueSource(
                            kind: ProcessQueueKind.playlist,
                            playlistId: playlist.id,
                          ),
                        ),
                      ),
                      onRename: () async {
                        final title = await _promptRename(context, playlist.title);
                        if (title == null || !context.mounted) return;
                        Navigator.pop(
                          context,
                          _QueueSelection(
                            renamePlaylist: (id: playlist.id, title: title),
                          ),
                        );
                      },
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('删除清单'),
                            content: Text('确定删除「${playlist.title}」？任务本身不会被删除。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                        Navigator.pop(
                          context,
                          _QueueSelection(deletePlaylistId: playlist.id),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<String?> _promptRename(BuildContext context, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名清单'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '清单名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isEmpty) {
                showAppSnackBar(
                  ctx,
                  message: '请输入清单名称',
                  icon: Icons.error_outline,
                  type: AppSnackType.error,
                );
                return;
              }
              Navigator.pop(ctx, title);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.selected,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final TaskPlaylist playlist;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.playlist_play_outlined),
      title: Text(playlist.title),
      subtitle: Text('${playlist.taskIds.length} 个任务'),
      trailing: selected
          ? const Icon(Icons.check)
          : PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    onRename();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('重命名')),
                PopupMenuItem(value: 'delete', child: Text('删除清单')),
              ],
            ),
      onTap: onSelect,
      onLongPress: onRename,
    );
  }
}