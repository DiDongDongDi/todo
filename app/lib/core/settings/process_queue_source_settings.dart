import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProcessQueueKind { inbox, daily, someday, playlist }

class ProcessQueueSource {
  const ProcessQueueSource({
    required this.kind,
    this.playlistId,
  }) : assert(
          kind != ProcessQueueKind.playlist || playlistId != null,
          'playlistId required for playlist kind',
        );

  const ProcessQueueSource.inbox() : this(kind: ProcessQueueKind.inbox);

  final ProcessQueueKind kind;
  final String? playlistId;

  String displayLabel({String? playlistTitle}) => switch (kind) {
        ProcessQueueKind.inbox => '收集箱',
        ProcessQueueKind.daily => '每日任务',
        ProcessQueueKind.someday => '将来也许',
        ProcessQueueKind.playlist => playlistTitle ?? '任务清单',
      };

  String get persistenceKey => switch (kind) {
        ProcessQueueKind.inbox => 'inbox',
        ProcessQueueKind.daily => 'daily',
        ProcessQueueKind.someday => 'someday',
        ProcessQueueKind.playlist => 'playlist:$playlistId',
      };

  static ProcessQueueSource fromPersistence(String raw) {
    if (raw == 'daily') {
      return const ProcessQueueSource(kind: ProcessQueueKind.daily);
    }
    if (raw == 'someday') {
      return const ProcessQueueSource(kind: ProcessQueueKind.someday);
    }
    if (raw.startsWith('playlist:')) {
      final id = raw.substring('playlist:'.length);
      return ProcessQueueSource(kind: ProcessQueueKind.playlist, playlistId: id);
    }
    return const ProcessQueueSource.inbox();
  }

  @override
  bool operator ==(Object other) =>
      other is ProcessQueueSource &&
      kind == other.kind &&
      playlistId == other.playlistId;

  @override
  int get hashCode => Object.hash(kind, playlistId);
}

const _key = 'process_queue_source_v1';

final processQueueSourceProvider =
    AsyncNotifierProvider<ProcessQueueSourceNotifier, ProcessQueueSource>(
  ProcessQueueSourceNotifier.new,
);

class ProcessQueueSourceNotifier extends AsyncNotifier<ProcessQueueSource> {
  SharedPreferences? _prefs;

  @override
  Future<ProcessQueueSource> build() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) return const ProcessQueueSource.inbox();
    return ProcessQueueSource.fromPersistence(raw);
  }

  Future<void> setSource(ProcessQueueSource source) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_key, source.persistenceKey);
    state = AsyncData(source);
  }
}
