import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/models/task_template.dart';
import 'package:todo_app/core/repositories/template_repository.dart';

Future<TaskTemplate?> showTemplatePickerSheet(BuildContext context) {
  return showModalBottomSheet<TaskTemplate>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _TemplatePickerSheet(),
  );
}

class _TemplatePickerSheet extends ConsumerWidget {
  const _TemplatePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (templates) {
            if (templates.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    '暂无模板\n可在更多菜单中保存当前内容为模板',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              );
            }

            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final subCount = template.subtaskTitles.length;
                return ListTile(
                  title: Text(template.title),
                  subtitle: Text(
                    subCount > 0 ? '$subCount 个子任务' : '无子任务',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, template),
                );
              },
            );
          },
        );
      },
    );
  }
}
