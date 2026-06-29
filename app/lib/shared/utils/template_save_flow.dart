import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/repositories/template_repository.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/widgets/replace_template_confirm_dialog.dart';

typedef TemplateSaveResult = ({bool saved, bool replaced});

Future<TemplateSaveResult> confirmAndSaveTemplate({
  required BuildContext context,
  required WidgetRef ref,
  required String name,
  required Future<void> Function({String? replaceTemplateId}) save,
}) async {
  final repo = await ref.read(templateRepositoryProvider.future);
  final existing = await repo.findByTitle(name);

  if (existing != null) {
    final confirmed = await showReplaceTemplateConfirmDialog(context, name);
    if (!confirmed || !context.mounted) {
      return (saved: false, replaced: false);
    }
    await save(replaceTemplateId: existing.id);
    if (!context.mounted) return (saved: false, replaced: false);
    await triggerSyncIfSignedIn(ref);
    return (saved: true, replaced: true);
  }

  await save();
  if (!context.mounted) return (saved: false, replaced: false);
  await triggerSyncIfSignedIn(ref);
  return (saved: true, replaced: false);
}
