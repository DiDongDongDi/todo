import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_app/core/models/legacy_note_migration.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_template.dart';

class SyncRepository {
  SyncRepository(this._client);

  final SupabaseClient _client;

  static const _tasksTable = 'tasks';
  static const _templatesTable = 'task_templates';

  Future<void> pushTasks(List<Task> tasks) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    if (tasks.isEmpty) return;

    final rows = tasks.map((t) {
      final json = t.toJson();
      json['user_id'] = userId;
      return json;
    }).toList();

    await _client.from(_tasksTable).upsert(rows);
  }

  Future<List<Task>> pullTasks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from(_tasksTable)
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (response as List<dynamic>)
        .map((e) => Task.fromJson(_normalizeTaskRemote(Map<String, dynamic>.from(e as Map))))
        .toList();
  }

  Future<void> pushTemplates(List<TaskTemplate> templates) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    if (templates.isEmpty) return;

    final rows = templates.map((t) {
      final json = t.toJson();
      json['user_id'] = userId;
      return json;
    }).toList();

    await _client.from(_templatesTable).upsert(rows);
  }

  Future<List<TaskTemplate>> pullTemplates() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from(_templatesTable)
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (response as List<dynamic>)
        .map(
          (e) => TaskTemplate.fromJson(
            _normalizeTemplateRemote(Map<String, dynamic>.from(e as Map)),
          ),
        )
        .toList();
  }

  Map<String, dynamic> _normalizeTaskRemote(Map<String, dynamic> row) {
    final migrated = migrateLegacyNoteInMap(Map<String, dynamic>.from(row));
    return {
      'id': migrated['id'],
      'user_id': migrated['user_id'],
      'title': migrated['title'] ?? '',
      'status': migrated['status'] ?? 'inbox',
      'sort_order': migrated['sort_order'] ?? 0,
      'attachments': migrated['attachments'] is List ? migrated['attachments'] : [],
      'transcription_status': migrated['transcription_status'] ?? 'none',
      'archived_at': migrated['archived_at'],
      'trashed_at': migrated['trashed_at'],
      'created_at': migrated['created_at'],
      'updated_at': migrated['updated_at'],
      'deleted_at': migrated['deleted_at'],
      'sync_version': migrated['sync_version'] ?? 0,
      'is_daily': migrated['is_daily'] ?? false,
      'recurrence_type': migrated['recurrence_type'] ?? 'none',
      'daily_until': migrated['daily_until'],
      'last_daily_completed_at': migrated['last_daily_completed_at'],
      'due_date': migrated['due_date'],
      'parent_id': migrated['parent_id'],
    };
  }

  Map<String, dynamic> _normalizeTemplateRemote(Map<String, dynamic> row) {
    final migrated = migrateLegacyNoteInMap(Map<String, dynamic>.from(row));
    return {
      'id': migrated['id'],
      'user_id': migrated['user_id'],
      'title': migrated['title'] ?? '',
      'attachments': migrated['attachments'] is List ? migrated['attachments'] : [],
      'is_daily': migrated['is_daily'] ?? false,
      'recurrence_type': migrated['recurrence_type'] ?? 'none',
      'daily_until': migrated['daily_until'],
      'due_date': migrated['due_date'],
      'subtask_titles': migrated['subtask_titles'] is List ? migrated['subtask_titles'] : [],
      'created_at': migrated['created_at'],
      'updated_at': migrated['updated_at'],
      'sync_version': migrated['sync_version'] ?? 0,
    };
  }

  Future<void> logOperation({
    required String entityId,
    required String opType,
    required Map<String, dynamic> payload,
    required String deviceId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('operations').insert({
      'user_id': userId,
      'entity_type': 'task',
      'entity_id': entityId,
      'op_type': opType,
      'payload': payload,
      'device_id': deviceId,
    });
  }
}
