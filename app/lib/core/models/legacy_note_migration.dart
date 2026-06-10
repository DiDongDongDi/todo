/// One-time migration: merge legacy `note` into `title` before dropping the field.
Map<String, dynamic> migrateLegacyNoteInMap(Map<String, dynamic> json) {
  final note = json['note'] as String?;
  if (note != null && note.trim().isNotEmpty) {
    final title = (json['title'] as String? ?? '').trim();
    if (title.isEmpty) {
      json['title'] = note.trim();
    } else {
      json['title'] = '$title\n${note.trim()}';
    }
  }
  json.remove('note');
  return json;
}
