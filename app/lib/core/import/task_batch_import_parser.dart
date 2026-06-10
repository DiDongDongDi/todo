/// Strips Dida365 / 滴答清单 export footer from pasted text.
String stripDidaFooter(String text) {
  final pattern = RegExp(
    r'(\n|^)\s*来自滴答清单\s*:?\s*\n?.*$',
    caseSensitive: false,
    dotAll: true,
  );
  return text.replaceFirst(pattern, '').trimRight();
}

/// Parses batch-import text into task titles.
///
/// Tasks start with a line matching `^-\s+` and continue until the next such
/// line or end of text. Non-task lines (e.g. list headers) are ignored.
List<String> parseBatchImportTasks(String text) {
  final cleaned = stripDidaFooter(text);
  if (cleaned.trim().isEmpty) return const [];

  final taskStart = RegExp(r'^-\s+', multiLine: true);
  final matches = taskStart.allMatches(cleaned).toList();
  if (matches.isEmpty) return const [];

  final titles = <String>[];
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].start;
    final end = i + 1 < matches.length ? matches[i + 1].start : cleaned.length;
    var block = cleaned.substring(start, end);
    block = block.replaceFirst(RegExp(r'^-\s+'), '');
    block = _trimBlock(block);
    if (block.isNotEmpty) {
      titles.add(block);
    }
  }
  return titles;
}

String _trimBlock(String block) {
  final lines = block.split('\n');
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n').trim();
}
