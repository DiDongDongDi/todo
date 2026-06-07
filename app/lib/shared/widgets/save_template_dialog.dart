import 'package:flutter/material.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

Future<String?> showSaveTemplateDialog(
  BuildContext context, {
  required String defaultTitle,
}) async {
  final controller = TextEditingController(text: defaultTitle.trim());
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('保存为模板'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '模板名称',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final title = controller.text.trim();
            if (title.isEmpty) {
              showAppSnackBar(
                context,
                message: '请输入模板名称',
                icon: Icons.error_outline,
                type: AppSnackType.error,
              );
              return;
            }
            Navigator.pop(context, title);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
