import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/settings/process_queue_source_settings.dart';

final shellTabIndexProvider = StateProvider<int>((ref) => 0);

class ProcessNavigationIntent {
  const ProcessNavigationIntent({
    required this.queueSource,
    required this.taskId,
  });

  final ProcessQueueSource queueSource;
  final String taskId;
}

final processNavigationIntentProvider =
    StateProvider<ProcessNavigationIntent?>((ref) => null);
