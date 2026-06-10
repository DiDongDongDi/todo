import 'package:todo_app/core/models/task.dart';

class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.attachments = const [],
    this.recurrence = TaskRecurrence.none,
    this.dailyUntil,
    this.dueDate,
    this.subtaskTitles = const [],
    this.syncVersion = 0,
  });

  final String id;
  final String? userId;
  final String title;
  final List<TaskAttachment> attachments;
  final TaskRecurrence recurrence;
  final DateTime? dailyUntil;
  final DateTime? dueDate;
  final List<String> subtaskTitles;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncVersion;

  bool get isDaily => recurrence == TaskRecurrence.daily;

  bool get hasContent =>
      title.trim().isNotEmpty ||
      attachments.isNotEmpty ||
      subtaskTitles.any((t) => t.trim().isNotEmpty);

  TaskTemplate copyWith({
    String? id,
    String? userId,
    String? title,
    List<TaskAttachment>? attachments,
    TaskRecurrence? recurrence,
    DateTime? dailyUntil,
    DateTime? dueDate,
    List<String>? subtaskTitles,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncVersion,
    bool clearDailyUntil = false,
    bool clearDueDate = false,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      attachments: attachments ?? this.attachments,
      recurrence: recurrence ?? this.recurrence,
      dailyUntil: clearDailyUntil ? null : (dailyUntil ?? this.dailyUntil),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      subtaskTitles: subtaskTitles ?? this.subtaskTitles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'attachments': attachments.map((e) => e.toJson()).toList(),
        'is_daily': isDaily,
        'recurrence_type': recurrence.name,
        if (dailyUntil != null) 'daily_until': _dateOnlyString(dailyUntil!),
        if (dueDate != null) 'due_date': _dateOnlyString(dueDate!),
        'subtask_titles': subtaskTitles,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_version': syncVersion,
      };

  static String _dateOnlyString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'];
    List<TaskAttachment> attachments = [];
    if (attachmentsRaw is List) {
      attachments = attachmentsRaw
          .map((e) => TaskAttachment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    final subtasksRaw = json['subtask_titles'];
    List<String> subtaskTitles = [];
    if (subtasksRaw is List) {
      subtaskTitles = subtasksRaw.map((e) => e.toString()).toList();
    }

    return TaskTemplate(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      title: json['title'] as String? ?? '',
      attachments: attachments,
      recurrence: Task.parseRecurrence(json),
      dailyUntil: _parseDateOnly(json['daily_until']),
      dueDate: _parseDateOnly(json['due_date']),
      subtaskTitles: subtaskTitles,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncVersion: json['sync_version'] as int? ?? 0,
    );
  }

  static DateTime? _parseDateOnly(dynamic value) {
    if (value == null) return null;
    if (value is String) {
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
