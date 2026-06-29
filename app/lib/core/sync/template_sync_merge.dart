import 'package:todo_app/core/models/task_template.dart';
import 'package:todo_app/core/repositories/template_repository.dart';

Future<void> mergeRemoteTaskTemplates(
  TemplateRepository templateRepo,
  List<TaskTemplate> remote,
) async {
  final localAll = await templateRepo.getAllForSync();
  final localMap = {for (final t in localAll) t.id: t};

  for (final r in remote) {
    final l = localMap[r.id];

    if (r.deletedAt != null) {
      if (l == null || l.deletedAt == null || r.updatedAt.isAfter(l.updatedAt)) {
        await templateRepo.upsertRemote(r);
      }
      continue;
    }

    if (l == null) {
      await templateRepo.upsertRemote(r);
    } else if (l.deletedAt != null) {
      if (r.updatedAt.isAfter(l.updatedAt)) {
        await templateRepo.upsertRemote(r);
      }
    } else if (r.updatedAt.isAfter(l.updatedAt)) {
      await templateRepo.upsertRemote(r);
    }
  }
}
