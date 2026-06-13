class TaskPlaylist {
  const TaskPlaylist({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.taskIds = const [],
    this.sourceQuery,
    this.syncVersion = 0,
  });

  final String id;
  final String? userId;
  final String title;
  final List<String> taskIds;
  final String? sourceQuery;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncVersion;

  TaskPlaylist copyWith({
    String? id,
    String? userId,
    String? title,
    List<String>? taskIds,
    String? sourceQuery,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncVersion,
    bool clearSourceQuery = false,
  }) {
    return TaskPlaylist(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      taskIds: taskIds ?? this.taskIds,
      sourceQuery: clearSourceQuery ? null : (sourceQuery ?? this.sourceQuery),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'task_ids': taskIds,
        if (sourceQuery != null) 'source_query': sourceQuery,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_version': syncVersion,
      };

  factory TaskPlaylist.fromJson(Map<String, dynamic> json) {
    final idsRaw = json['task_ids'];
    List<String> taskIds = [];
    if (idsRaw is List) {
      taskIds = idsRaw.map((e) => e.toString()).toList();
    }

    return TaskPlaylist(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      title: json['title'] as String? ?? '',
      taskIds: taskIds,
      sourceQuery: json['source_query'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncVersion: json['sync_version'] as int? ?? 0,
    );
  }
}
