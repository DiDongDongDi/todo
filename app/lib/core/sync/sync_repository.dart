import 'package:supabase_flutter/supabase_flutter.dart';
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
    return {
      'id': row['id'],
      'user_id': row['user_id'],
      'title': row['title'] ?? '',
      'note': row['note'],
      'status': row['status'] ?? 'inbox',
      'sort_order': row['sort_order'] ?? 0,
      'attachments': row['attachments'] is List ? row['attachments'] : [],
      'transcription_status': row['transcription_status'] ?? 'none',
      'archived_at': row['archived_at'],
      'trashed_at': row['trashed_at'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'deleted_at': row['deleted_at'],
      'sync_version': row['sync_version'] ?? 0,
      'is_daily': row['is_daily'] ?? false,
      'daily_until': row['daily_until'],
      'last_daily_completed_at': row['last_daily_completed_at'],
      'due_date': row['due_date'],
      'parent_id': row['parent_id'],
    };
  }

  Map<String, dynamic> _normalizeTemplateRemote(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'user_id': row['user_id'],
      'title': row['title'] ?? '',
      'note': row['note'],
      'attachments': row['attachments'] is List ? row['attachments'] : [],
      'is_daily': row['is_daily'] ?? false,
      'daily_until': row['daily_until'],
      'due_date': row['due_date'],
      'subtask_titles': row['subtask_titles'] is List ? row['subtask_titles'] : [],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'sync_version': row['sync_version'] ?? 0,
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
