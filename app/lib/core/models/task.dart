enum TaskStatus { inbox, archived, trashed }

enum TranscriptionStatus { none, pending, done, failed }

enum AttachmentType { image, audio }

enum TaskRecurrence { none, daily, monthly, yearly }

class TaskAttachment {
  const TaskAttachment({
    required this.type,
    required this.localPath,
    this.remoteUrl,
    this.duration,
  });

  final AttachmentType type;
  final String localPath;
  final String? remoteUrl;
  final int? duration;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'localPath': localPath,
        if (remoteUrl != null) 'remoteUrl': remoteUrl,
        if (duration != null) 'duration': duration,
      };

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    return TaskAttachment(
      type: AttachmentType.values.byName(json['type'] as String),
      localPath: json['localPath'] as String,
      remoteUrl: json['remoteUrl'] as String?,
      duration: json['duration'] as int?,
    );
  }
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.sortOrder = 0,
    this.attachments = const [],
    this.transcriptionStatus = TranscriptionStatus.none,
    this.archivedAt,
    this.trashedAt,
    this.deletedAt,
    this.syncVersion = 0,
    this.recurrence = TaskRecurrence.none,
    this.dailyUntil,
    this.lastDailyCompletedAt,
    this.dueDate,
    this.parentId,
    this.checkInTarget = 1,
    this.checkInCount = 0,
    this.lastCheckInAt,
  });

  final String id;
  final String? userId;
  final String title;
  final TaskStatus status;
  final double sortOrder;
  final List<TaskAttachment> attachments;
  final TranscriptionStatus transcriptionStatus;
  final DateTime? archivedAt;
  final DateTime? trashedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;
  final TaskRecurrence recurrence;
  final DateTime? dailyUntil;
  final DateTime? lastDailyCompletedAt;
  final DateTime? dueDate;
  final String? parentId;
  final int checkInTarget;
  final int checkInCount;
  final DateTime? lastCheckInAt;

  bool get isSubtask => parentId != null;

  bool get isDaily => recurrence == TaskRecurrence.daily;

  bool get hasContent =>
      title.trim().isNotEmpty || attachments.isNotEmpty;

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    TaskStatus? status,
    double? sortOrder,
    List<TaskAttachment>? attachments,
    TranscriptionStatus? transcriptionStatus,
    DateTime? archivedAt,
    DateTime? trashedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncVersion,
    TaskRecurrence? recurrence,
    DateTime? dailyUntil,
    DateTime? lastDailyCompletedAt,
    DateTime? dueDate,
    String? parentId,
    int? checkInTarget,
    int? checkInCount,
    DateTime? lastCheckInAt,
    bool clearParentId = false,
    bool clearArchivedAt = false,
    bool clearTrashedAt = false,
    bool clearDailyUntil = false,
    bool clearLastDailyCompletedAt = false,
    bool clearDueDate = false,
    bool clearLastCheckInAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      attachments: attachments ?? this.attachments,
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      trashedAt: clearTrashedAt ? null : (trashedAt ?? this.trashedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      recurrence: recurrence ?? this.recurrence,
      dailyUntil: clearDailyUntil ? null : (dailyUntil ?? this.dailyUntil),
      lastDailyCompletedAt: clearLastDailyCompletedAt
          ? null
          : (lastDailyCompletedAt ?? this.lastDailyCompletedAt),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      checkInTarget: checkInTarget ?? this.checkInTarget,
      checkInCount: checkInCount ?? this.checkInCount,
      lastCheckInAt: clearLastCheckInAt
          ? null
          : (lastCheckInAt ?? this.lastCheckInAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'status': status.name,
        'sort_order': sortOrder,
        'attachments': attachments.map((e) => e.toJson()).toList(),
        'transcription_status': transcriptionStatus.name,
        'archived_at': archivedAt?.toIso8601String(),
        'trashed_at': trashedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'sync_version': syncVersion,
        'is_daily': isDaily,
        'recurrence_type': recurrence.name,
        if (dailyUntil != null) 'daily_until': _dateOnlyString(dailyUntil!),
        if (lastDailyCompletedAt != null)
          'last_daily_completed_at': _dateOnlyString(lastDailyCompletedAt!),
        if (dueDate != null) 'due_date': _dateOnlyString(dueDate!),
        if (parentId != null) 'parent_id': parentId,
        'check_in_target': checkInTarget,
        'check_in_count': checkInCount,
        if (lastCheckInAt != null)
          'last_check_in_at': _dateOnlyString(lastCheckInAt!),
      };

  static String _dateOnlyString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory Task.fromJson(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'];
    List<TaskAttachment> attachments = [];
    if (attachmentsRaw is List) {
      attachments = attachmentsRaw
          .map((e) => TaskAttachment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return Task(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      title: json['title'] as String? ?? '',
      status: TaskStatus.values.byName(json['status'] as String? ?? 'inbox'),
      sortOrder: (json['sort_order'] as num?)?.toDouble() ?? 0,
      attachments: attachments,
      transcriptionStatus: TranscriptionStatus.values
          .byName(json['transcription_status'] as String? ?? 'none'),
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      trashedAt: json['trashed_at'] != null
          ? DateTime.parse(json['trashed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      syncVersion: json['sync_version'] as int? ?? 0,
      recurrence: parseRecurrence(json),
      dailyUntil: _parseDateOnly(json['daily_until']),
      lastDailyCompletedAt: _parseDateOnly(json['last_daily_completed_at']),
      dueDate: _parseDateOnly(json['due_date']),
      parentId: json['parent_id'] as String?,
      checkInTarget: (json['check_in_target'] as num?)?.toInt() ?? 1,
      checkInCount: (json['check_in_count'] as num?)?.toInt() ?? 0,
      lastCheckInAt: _parseDateOnly(json['last_check_in_at']),
    );
  }

  static TaskRecurrence parseRecurrence(Map<String, dynamic> json) {
    final type = json['recurrence_type'] as String?;
    if (type != null) {
      return TaskRecurrence.values.byName(type);
    }
    if (json['is_daily'] as bool? ?? false) {
      return TaskRecurrence.daily;
    }
    return TaskRecurrence.none;
  }

  static DateTime? _parseDateOnly(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      if (value.contains('T')) {
        final parsed = DateTime.parse(value);
        final local = parsed.toLocal();
        return DateTime(local.year, local.month, local.day);
      }
      final parts = value.split('-');
      if (parts.length >= 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
      return DateTime.parse(value);
    }
    return null;
  }
}
