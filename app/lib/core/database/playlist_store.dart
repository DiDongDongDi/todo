import 'dart:async';
import 'dart:convert';

import 'package:todo_app/core/models/task_playlist.dart';

abstract class PlaylistStore {
  Future<void> init();
  Future<List<TaskPlaylist>> getAll();
  Stream<List<TaskPlaylist>> watchAll();
  Future<TaskPlaylist?> getById(String id);
  Future<void> upsert(TaskPlaylist playlist);
  Future<void> delete(String id);
}

class JsonPlaylistStore implements PlaylistStore {
  JsonPlaylistStore({
    required Future<void> Function(String json) persist,
    required Future<String?> Function() load,
  })  : _persist = persist,
        _load = load;

  final Future<void> Function(String json) _persist;
  final Future<String?> Function() _load;

  final List<TaskPlaylist> _playlists = [];
  final _changeController = StreamController<void>.broadcast();
  Future<void>? _saveInFlight;

  @override
  Future<void> init() async {
    final raw = await _load();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      _playlists
        ..clear()
        ..addAll(
          list.map(
            (e) => TaskPlaylist.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    }
  }

  @override
  Future<List<TaskPlaylist>> getAll() async {
    final list = List<TaskPlaylist>.from(_playlists)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Stream<List<TaskPlaylist>> watchAll() async* {
    yield await getAll();
    await for (final _ in _changeController.stream) {
      yield await getAll();
    }
  }

  @override
  Future<TaskPlaylist?> getById(String id) async {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(TaskPlaylist playlist) async {
    final index = _playlists.indexWhere((p) => p.id == playlist.id);
    if (index >= 0) {
      _playlists[index] = playlist;
    } else {
      _playlists.add(playlist);
    }
    _notifyChanged();
  }

  @override
  Future<void> delete(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    _notifyChanged();
  }

  void _notifyChanged() {
    _changeController.add(null);
    unawaited(_persistQueued());
  }

  Future<void> _persistQueued() {
    _saveInFlight ??= _save().whenComplete(() => _saveInFlight = null);
    return _saveInFlight!;
  }

  Future<void> _save() async {
    final json = jsonEncode(_playlists.map((p) => p.toJson()).toList());
    await _persist(json);
  }

  void dispose() => _changeController.close();
}
