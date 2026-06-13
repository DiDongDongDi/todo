import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/core/database/playlist_store.dart';
import 'package:todo_app/core/models/task_playlist.dart';
import 'package:uuid/uuid.dart';

const _storageKey = 'todo_playlists_v1';

final playlistStoreInitProvider = FutureProvider<PlaylistStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final store = JsonPlaylistStore(
    persist: (json) async => prefs.setString(_storageKey, json),
    load: () async => prefs.getString(_storageKey),
  );
  await store.init();
  return store;
});

final playlistsProvider = StreamProvider<List<TaskPlaylist>>((ref) async* {
  final store = await ref.watch(playlistStoreInitProvider.future);
  yield* store.watchAll();
});

class PlaylistRepository {
  PlaylistRepository(this._store, this._uuid);

  final PlaylistStore _store;
  final Uuid _uuid;

  Stream<List<TaskPlaylist>> watchAll() => _store.watchAll();

  Future<List<TaskPlaylist>> getAll() => _store.getAll();

  Future<TaskPlaylist?> getById(String id) => _store.getById(id);

  Future<TaskPlaylist> createFromTaskIds({
    required String title,
    required List<String> taskIds,
    String? sourceQuery,
  }) async {
    final now = DateTime.now().toUtc();
    final uniqueIds = <String>[];
    for (final id in taskIds) {
      if (!uniqueIds.contains(id)) uniqueIds.add(id);
    }
    final playlist = TaskPlaylist(
      id: _uuid.v4(),
      title: title.trim(),
      taskIds: uniqueIds,
      sourceQuery: sourceQuery,
      createdAt: now,
      updatedAt: now,
      syncVersion: 1,
    );
    await _store.upsert(playlist);
    return playlist;
  }

  Future<TaskPlaylist> rename(String id, String title) async {
    final existing = await _require(id);
    final updated = existing.copyWith(
      title: title.trim(),
      updatedAt: DateTime.now().toUtc(),
      syncVersion: existing.syncVersion + 1,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<TaskPlaylist> updateTaskIds(String id, List<String> taskIds) async {
    final existing = await _require(id);
    final uniqueIds = <String>[];
    for (final taskId in taskIds) {
      if (!uniqueIds.contains(taskId)) uniqueIds.add(taskId);
    }
    final updated = existing.copyWith(
      taskIds: uniqueIds,
      updatedAt: DateTime.now().toUtc(),
      syncVersion: existing.syncVersion + 1,
    );
    await _store.upsert(updated);
    return updated;
  }

  Future<void> delete(String id) => _store.delete(id);

  Future<void> upsertRemote(TaskPlaylist playlist) => _store.upsert(playlist);

  Future<TaskPlaylist> _require(String id) async {
    final playlist = await _store.getById(id);
    if (playlist == null) throw StateError('Playlist not found: $id');
    return playlist;
  }
}

final playlistRepositoryProvider = FutureProvider<PlaylistRepository>((ref) async {
  final store = await ref.watch(playlistStoreInitProvider.future);
  return PlaylistRepository(store, const Uuid());
});
