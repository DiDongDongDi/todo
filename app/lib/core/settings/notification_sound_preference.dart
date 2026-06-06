class NotificationSoundPreference {
  const NotificationSoundPreference({
    required this.enabled,
    this.uri,
    this.title,
  });

  final bool enabled;
  final String? uri;
  final String? title;

  static const none = NotificationSoundPreference(enabled: false);

  bool get canPlay => enabled && uri != null && uri!.isNotEmpty;

  String get displayTitle {
    if (!enabled) return '无声';
    if (title != null && title!.isNotEmpty) return title!;
    return '系统通知音';
  }

  NotificationSoundPreference copyWith({
    bool? enabled,
    String? uri,
    String? title,
  }) {
    return NotificationSoundPreference(
      enabled: enabled ?? this.enabled,
      uri: uri ?? this.uri,
      title: title ?? this.title,
    );
  }
}
