import 'package:todo_app/core/import/task_batch_import_parser.dart';

/// Parses pasted multi-line text into subtask titles (one non-empty line each).
List<String> parseSubtaskBatchImport(String text) {
  final cleaned = stripDidaFooter(text);
  if (cleaned.trim().isEmpty) return const [];

  return cleaned
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}
