import 'package:flutter/material.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

Future<String?> showSaveTemplateDialog(
  BuildContext context, {
  required String defaultTitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SaveTemplateDialog(defaultTitle: defaultTitle),
  );
}

class _SaveTemplateDialog extends StatefulWidget {
  const _SaveTemplateDialog({required this.defaultTitle});

  final String defaultTitle;

  @override
  State<_SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<_SaveTemplateDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultTitle.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('保存为模板'),
      content: TextField(
        controller: _controller,
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
            final title = _controller.text.trim();
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
    );
  }
}
